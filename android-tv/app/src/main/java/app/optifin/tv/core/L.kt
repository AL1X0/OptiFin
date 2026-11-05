package app.optifin.tv.core

import java.util.Locale

/**
 * Langue de l'appli : français si le téléviseur est en français, anglais sinon. La phrase française
 * reste dans le code et sert de clé au dictionnaire [EnglishTexts] (un test vérifie qu'elle y figure).
 */
object L {
    var isEnglish: Boolean = (System.getProperty("optifin.language") ?: Locale.getDefault().language) != "fr"

    fun t(french: String): String = if (isEnglish) EnglishTexts[french] ?: french else french

    /** Phrase avec variables : « Aucun résultat pour « {0} ». ». */
    fun f(french: String, vararg values: Any?): String =
        values.foldIndexed(t(french)) { i, text, value -> text.replace("{$i}", value.toString()) }

    /** Singulier ou pluriel ({0} : le nombre). Zéro est au singulier en français, au pluriel en anglais. */
    fun count(n: Long, one: String, many: String): String = f(if (n > 1 || (n == 0L && isEnglish)) many else one, n)

    fun count(n: Int, one: String, many: String): String = count(n.toLong(), one, many)
}
