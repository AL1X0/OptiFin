package app.optifin.tv

import app.optifin.tv.core.syncplay.RemoteCommand
import app.optifin.tv.core.syncplay.RemotePlay
import app.optifin.tv.core.syncplay.SyncPlayParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Messages « Lire sur… » tels que Jellyfin les envoie. */
class RemoteTest {
    @Test
    fun `demande de lecture`() {
        assertEquals(
            RemotePlay("abc", 180_000),
            SyncPlayParser.parse("""{"MessageType":"Play","Data":{"ItemIds":["abc"],"StartPositionTicks":1800000000,"PlayCommand":"PlayNow"}}"""),
        )
    }

    @Test
    fun `seule la lecture immédiate est acceptée`() {
        assertNull(SyncPlayParser.parse("""{"MessageType":"Play","Data":{"ItemIds":["abc"],"PlayCommand":"PlayLast"}}"""))
    }

    @Test
    fun `commandes de lecture`() {
        assertEquals(RemoteCommand("Seek", 300_000), SyncPlayParser.parse("""{"MessageType":"Playstate","Data":{"Command":"Seek","SeekPositionTicks":3000000000}}"""))
        assertEquals(RemoteCommand("Pause", null), SyncPlayParser.parse("""{"MessageType":"Playstate","Data":{"Command":"Pause"}}"""))
    }
}
