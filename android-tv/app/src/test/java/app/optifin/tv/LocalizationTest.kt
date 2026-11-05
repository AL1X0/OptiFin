package app.optifin.tv

import app.optifin.tv.core.EnglishTexts
import app.optifin.tv.core.L
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Traduction anglaise : aucune phrase du code oubliée, variables identiques des deux côtés. */
class LocalizationTest {
    private val quoted = Regex(""""((?:[^"\\]|\\.)*)"""")

    @Test
    fun `toute phrase du code est traduite`() {
        val root = generateSequence(File("").absoluteFile) { it.parentFile }.map { File(it, "app/src/main/java") }
            .firstOrNull { it.isDirectory } ?: File("src/main/java")
        val call = Regex("""L\.(?:t|f)\(("(?:[^"\\]|\\.)*")|L\.count\([^,"]+,\s*("(?:[^"\\]|\\.)*"),\s*("(?:[^"\\]|\\.)*")\)""")
        val missing = root.walkTopDown().filter { it.extension == "kt" && it.name != "L.kt" }.flatMap { file ->
            call.findAll(file.readText()).flatMap { m -> m.groupValues.drop(1).filter { it.isNotEmpty() }.map { it.trim('"') } }
                .filter { it !in EnglishTexts }.map { "${file.name} : $it" }
        }.toSortedSet()
        assertTrue("Sans traduction :\n" + missing.joinToString("\n"), missing.isEmpty())
    }

    @Test
    fun `mêmes variables dans les deux langues`() {
        val placeholder = Regex("""\{\d+}""")
        for ((french, english) in EnglishTexts) {
            assertEquals("« $french »", placeholder.findAll(french).map { it.value }.sorted().toList(), placeholder.findAll(english).map { it.value }.sorted().toList())
        }
    }

    @Test
    fun `phrases en anglais et pluriels`() {
        assertEquals("Lecture", L.t("Lecture"))
        L.isEnglish = true
        try {
            assertEquals("Play", L.t("Lecture"))
            assertEquals("1 title", L.count(1, "{0} titre", "{0} titres"))
            assertEquals("0 titles", L.count(0, "{0} titre", "{0} titres"))
            assertEquals("No results for “x”.", L.f("Aucun résultat pour « {0} ».", "x"))
        } finally {
            L.isEnglish = false
        }
    }
}
