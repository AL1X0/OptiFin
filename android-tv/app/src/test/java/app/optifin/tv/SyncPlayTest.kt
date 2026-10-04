package app.optifin.tv

import app.optifin.tv.core.api.ClientIdentity
import app.optifin.tv.core.api.JellyfinClient
import app.optifin.tv.core.auth.AuthService
import app.optifin.tv.core.syncplay.CommandReceived
import app.optifin.tv.core.syncplay.QueueChanged
import app.optifin.tv.core.syncplay.SyncCommand
import app.optifin.tv.core.syncplay.SyncCommandKind
import app.optifin.tv.core.syncplay.SyncPlayClient
import app.optifin.tv.core.syncplay.SyncPlayParser
import app.optifin.tv.core.syncplay.SyncPlayPlayback
import app.optifin.tv.core.syncplay.SyncRequests
import app.optifin.tv.core.syncplay.SyncTarget
import app.optifin.tv.core.syncplay.TimeSync
import java.io.File
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.async
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test

class SyncPlayTest {
    @Test
    fun `messages du serveur`() {
        val cmd = SyncPlayParser.parse("""{"MessageType":"SyncPlayCommand","Data":{"GroupId":"g","PlaylistItemId":"p1","When":"2026-10-02T12:48:13.6916504Z","PositionTicks":312458000,"Command":"Unpause","EmittedAt":"2026-10-02T12:48:12.6917189Z"}}""")
        val c = (cmd as CommandReceived).command
        assertEquals(SyncCommandKind.Unpause, c.kind)
        assertEquals(31245, c.positionMs)
        val queue = SyncPlayParser.parse("""{"MessageType":"SyncPlayGroupUpdate","Data":{"GroupId":"g","Type":"PlayQueue","Data":{"Reason":"NewPlaylist","Playlist":[{"ItemId":"i","PlaylistItemId":"p"}],"PlayingItemIndex":0,"StartPositionTicks":10000000,"IsPlaying":true}}}""")
        assertEquals("i", (queue as QueueChanged).queue.current?.itemId)
        assertEquals(1000, queue.queue.startMs)
    }

    private class FakeTarget : SyncTarget {
        override var positionMs = 0L
        override var paused = true
        var rate = 1f
        override fun play() { paused = false }
        override fun pause() { paused = true }
        override fun seek(positionMs: Long) { this.positionMs = positionMs }
        override fun setSpeed(speed: Float) { rate = speed }
    }

    private class NoRequests : SyncRequests {
        val calls = mutableListOf<String>()
        override suspend fun ready(positionMs: Long, isPlaying: Boolean, playlistItemId: String) { calls += "ready" }
        override suspend fun buffering(positionMs: Long, isPlaying: Boolean, playlistItemId: String) { calls += "buffering" }
        override suspend fun pause() { calls += "pause" }
        override suspend fun unpause() { calls += "unpause" }
        override suspend fun seek(positionMs: Long) { calls += "seek" }
    }

    @Test
    fun `départ programmé puis rattrapage de la dérive`() {
        var now = Instant.parse("2026-10-02T12:00:00Z")
        val time = TimeSync { now }
        val target = FakeTarget()
        val sync = SyncPlayPlayback(target, NoRequests(), time, "p", CoroutineScope(Dispatchers.Unconfined))
        // Départ dans 1 s à 10 s : en pause à la bonne position, puis lecture à l'heure prévue.
        sync.apply(SyncCommand(SyncCommandKind.Unpause, "p", now.plusSeconds(1), 10_000, now))
        assertTrue(target.paused)
        assertEquals(10_000, target.positionMs)
        now = now.plusMillis(1000)
        sync.tick()
        assertFalse(target.paused)
        // 3 s plus tard (après stabilisation), le lecteur a 2 s de retard : saut direct.
        now = now.plusMillis(3000)
        target.positionMs = 11_000
        sync.tick()
        assertEquals(13_000, target.positionMs)
        // Petit retard (300 ms) après stabilisation : accélération légère.
        now = now.plusMillis(2500)
        target.positionMs = 15_200
        sync.tick()
        assertEquals(1.05f, target.rate)
        // Ordre d'un autre élément : ignoré.
        sync.apply(SyncCommand(SyncCommandKind.Pause, "autre", now, 0, now))
        assertFalse(target.paused)
    }

    @Test
    fun `soirée réelle sur le serveur Jellyfin local`() = runBlocking {
        val path = System.getenv("OPTIFIN_TEST_JELLYFIN")
        assumeTrue("Serveur Jellyfin de test absent", path != null && File(path).exists())
        val cfg = Json.parseToJsonElement(File(path!!).readText()).jsonObject
        val users = cfg["users"]!!.jsonArray.map { it.jsonObject }
        suspend fun clientFor(i: Int, device: String): SyncPlayClient {
            val identity = ClientIdentity("OptiFin TV test", device, "tv-test-$device", "1.0")
            val auth = AuthService(identity)
            val server = auth.probe(cfg["url"]!!.jsonPrimitive.content)
            val session = auth.login(server, users[i]["name"]!!.jsonPrimitive.content, users[i]["password"]!!.jsonPrimitive.content)
            return SyncPlayClient(JellyfinClient(server.baseUrl, identity) { session.token })
        }
        val alice = clientFor(0, "alice")
        val bob = clientFor(1, "bob")
        alice.start()
        bob.start()
        withTimeout(10_000) { alice.connected.first { it } }
        withTimeout(10_000) { bob.connected.first { it } }
        alice.syncTime()
        assertTrue("aller-retour mesuré", alice.time.roundTrip.toMillis() < 2000)
        alice.create("Soirée de test TV")
        val group = withTimeout(10_000) { alice.group.first { it != null } }!!
        bob.join(group.id)
        withTimeout(10_000) { alice.group.first { (it?.participants?.size ?: 0) >= 2 } }
        // Titre lancé par alice : bob reçoit la file.
        val queue = async { withTimeout(10_000) { bob.messages.first { it is QueueChanged } as QueueChanged } }
        alice.setQueue(listOf(itemId(cfg)), 0, 5_000)
        val q = queue.await().queue
        assertEquals(5_000, q.startMs)
        // Arrêt par l'hôte : bob reçoit l'ordre Stop de l'élément en cours.
        val stop = async { withTimeout(10_000) { bob.messages.first { it is CommandReceived && it.command.kind == SyncCommandKind.Stop && it.command.playlistItemId.isNotEmpty() } } }
        alice.stop()
        stop.await()
        bob.leave()
        alice.leave()
        alice.close()
        bob.close()
    }

    /** Premier film du serveur de test (Long Test, 12 min). */
    private fun itemId(cfg: kotlinx.serialization.json.JsonObject): String =
        cfg["testItem"]?.jsonPrimitive?.content ?: "fde8185a4a9b78e748dc26306f596e6a"
}
