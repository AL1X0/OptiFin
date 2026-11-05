package app.optifin.tv

import app.optifin.tv.core.media.MediaItem
import app.optifin.tv.core.media.MediaKind
import app.optifin.tv.core.media.pickSurprise
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SurpriseTest {
    private fun movie(id: String, minutes: Int) =
        MediaItem(id = id, name = id, kind = MediaKind.Movie, runTimeTicks = minutes * 600_000_000L)

    @Test
    fun `durée maximale et titre précédent`() {
        val drawn = listOf(movie("long", 180), movie("a", 100), movie("b", 90))
        assertEquals("a", pickSurprise(drawn, 120, null)?.id)
        assertEquals("b", pickSurprise(drawn, 120, "a")?.id)
        assertEquals("long", pickSurprise(drawn, null, null)?.id)
        assertEquals("b", pickSurprise(listOf(movie("b", 90)), 120, "b")?.id)
        assertNull(pickSurprise(listOf(movie("long", 180)), 120, null))
    }
}
