package app.optifin.tv.core

import android.util.Log
import java.io.File
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.util.concurrent.Executors
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class LogLevel(val letter: Char) { Debug('D'), Info('I'), Warning('W'), Error('E') }

data class LogEntry(val time: LocalTime, val level: LogLevel, val tag: String, val message: String) {
    override fun toString(): String = "${time.format(FORMAT)} ${level.letter}/$tag: $message"

    companion object {
        private val FORMAT: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm:ss.SSS")
    }
}

/**
 * Journal de l'appli : mémoire (écran « Journaux ») et fichier persistant (session courante +
 * précédente) ; les secrets (jetons, clés d'API, mots de passe) sont masqués à l'écriture.
 */
object AppLog {
    private const val MAX_ENTRIES = 2000
    private val writer = Executors.newSingleThreadExecutor { Thread(it, "optifin-log").apply { isDaemon = true } }
    private val buffer = ArrayDeque<LogEntry>()
    private val _entries = MutableStateFlow<List<LogEntry>>(emptyList())
    val entries: StateFlow<List<LogEntry>> = _entries

    /** Journal détaillé (mode debug) : messages Debug conservés. */
    @Volatile var verbose = false

    private var file: File? = null

    /** Fichier courant ; l'ancien devient « previous ». */
    fun init(directory: File) {
        directory.mkdirs()
        val current = File(directory, "optifin.log")
        val previous = File(directory, "optifin.previous.log")
        if (current.exists()) {
            previous.delete()
            current.renameTo(previous)
        }
        file = current
    }

    val logFile: File? get() = file

    fun d(tag: String, message: String) = add(LogLevel.Debug, tag, message)
    fun i(tag: String, message: String) = add(LogLevel.Info, tag, message)
    fun w(tag: String, message: String) = add(LogLevel.Warning, tag, message)
    fun e(tag: String, message: String, error: Throwable? = null) =
        add(LogLevel.Error, tag, if (error == null) message else "$message\n${error.javaClass.simpleName}: ${error.message}")

    fun add(level: LogLevel, tag: String, message: String) {
        if (level == LogLevel.Debug && !verbose) return
        val safe = redact(message)
        val entry = LogEntry(LocalTime.now(), level, tag, safe)
        when (level) {
            LogLevel.Debug -> Log.d("OptiFin/$tag", safe)
            LogLevel.Info -> Log.i("OptiFin/$tag", safe)
            LogLevel.Warning -> Log.w("OptiFin/$tag", safe)
            LogLevel.Error -> Log.e("OptiFin/$tag", safe)
        }
        synchronized(buffer) {
            buffer.addLast(entry)
            while (buffer.size > MAX_ENTRIES) buffer.removeFirst()
            _entries.value = buffer.toList()
        }
        val target = file ?: return
        writer.execute {
            try {
                target.appendText(entry.toString() + "\n")
            } catch (_: Exception) {
            }
        }
    }

    private val patterns: List<Pair<Regex, String>> = listOf(
        Regex("Token=\"[^\"]*\"") to "Token=\"***\"",
        Regex("(api_key|ApiKey|apikey|api-key)=([^&\\s\"]+)", RegexOption.IGNORE_CASE) to "\$1=***",
        Regex("(X-Emby-Token|X-MediaBrowser-Token)[\"\\s:=]+[^\\s\",}]+", RegexOption.IGNORE_CASE) to "\$1: ***",
        Regex("\"(AccessToken|Pw|Password|Secret)\"\\s*:\\s*\"[^\"]*\"", RegexOption.IGNORE_CASE) to "\"\$1\":\"***\"",
    )

    /** Masque les secrets connus dans un texte. */
    fun redact(input: String): String =
        patterns.fold(input) { acc, (pattern, replacement) -> pattern.replace(acc, replacement) }

    fun clear() {
        synchronized(buffer) {
            buffer.clear()
            _entries.value = emptyList()
        }
    }

    fun text(): String = synchronized(buffer) { buffer.joinToString("\n") }
}
