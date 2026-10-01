using System.Text;
using System.Text.RegularExpressions;

namespace OptiFin.Core.Logging;

public enum LogLevel { Debug, Info, Warning, Error }

public sealed record LogEntry(DateTime Time, LogLevel Level, string Tag, string Message)
{
    public string Format() =>
        $"{Time:HH:mm:ss.fff} {"DIWE"[(int)Level]}/{Tag}: {Message}";
}

/// <summary>
/// Journal de l'application : en mémoire (écran Journaux) et dans un fichier écrit ligne à
/// ligne (%LOCALAPPDATA%\OptiFin\optifin.log), lisible même après un plantage. Les secrets
/// (jetons, clés d'API, mots de passe) sont masqués à l'écriture.
/// </summary>
public static partial class AppLog
{
    private const int Capacity = 3000;
    private static readonly List<LogEntry> Entries = [];
    private static readonly Lock Gate = new();
    private static StreamWriter? _file;

    /// <summary>Mode debug : niveaux « debug » aussi (requêtes réussies, journaux mpv).</summary>
    public static bool Verbose { get; set; }

    public static event Action<LogEntry>? Added;

    public static string Directory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OptiFin");

    public static string FilePath => Path.Combine(Directory, "optifin.log");

    /// <summary>Relit la session précédente (400 dernières lignes) puis repart d'un fichier vide.</summary>
    public static void Open()
    {
        try
        {
            System.IO.Directory.CreateDirectory(Directory);
            if (File.Exists(FilePath))
            {
                var lines = File.ReadAllLines(FilePath);
                var tail = lines.Skip(Math.Max(0, lines.Length - 400)).ToList();
                if (tail.Count > 0)
                {
                    lock (Gate)
                    {
                        Entries.Add(new LogEntry(DateTime.Now, LogLevel.Info, "log", "──── Session précédente ────"));
                        foreach (var l in tail)
                            Entries.Add(new LogEntry(DateTime.Now, l.Length > 13 && l[13] == 'E' ? LogLevel.Error : LogLevel.Info, "avant", l));
                        Entries.Add(new LogEntry(DateTime.Now, LogLevel.Info, "log", "──── Session actuelle ────"));
                    }
                }
            }
            _file = new StreamWriter(new FileStream(FilePath, FileMode.Create, FileAccess.Write, FileShare.ReadWrite), Encoding.UTF8)
            {
                AutoFlush = true,
            };
        }
        catch
        {
            _file = null; // journal en mémoire seulement
        }
    }

    public static IReadOnlyList<LogEntry> Snapshot()
    {
        lock (Gate) return [.. Entries];
    }

    public static void Debug(string tag, string message) => Add(LogLevel.Debug, tag, message);
    public static void Info(string tag, string message) => Add(LogLevel.Info, tag, message);
    public static void Warn(string tag, string message) => Add(LogLevel.Warning, tag, message);
    public static void Error(string tag, string message, Exception? e = null) =>
        Add(LogLevel.Error, tag, e == null ? message : $"{message}\n{e.GetType().Name}: {e.Message}\n{e.StackTrace}");

    public static void Add(LogLevel level, string tag, string message)
    {
        if (level == LogLevel.Debug && !Verbose) return;
        var entry = new LogEntry(DateTime.Now, level, tag, Redact(message));
        lock (Gate)
        {
            Entries.Add(entry);
            if (Entries.Count > Capacity) Entries.RemoveRange(0, Entries.Count - Capacity);
            try
            {
                _file?.WriteLine(entry.Format());
            }
            catch
            {
                _file = null;
            }
        }
        System.Diagnostics.Debug.WriteLine($"[{tag}] {entry.Message}");
        Added?.Invoke(entry);
    }

    public static string Export(LogLevel min = LogLevel.Debug)
    {
        lock (Gate) return string.Join('\n', Entries.Where(e => e.Level >= min).Select(e => e.Format()));
    }

    [GeneratedRegex("Token=\"[^\"]*\"")]
    private static partial Regex TokenPattern();

    [GeneratedRegex("(api_key|ApiKey|apikey|api-key)=([^&\\s\"]+)", RegexOptions.IgnoreCase)]
    private static partial Regex ApiKeyPattern();

    [GeneratedRegex("(X-Emby-Token|X-MediaBrowser-Token)[\"\\s:=]+[^\\s\",}]+", RegexOptions.IgnoreCase)]
    private static partial Regex HeaderPattern();

    [GeneratedRegex("\"(AccessToken|Pw|Password|Secret)\"\\s*:\\s*\"[^\"]*\"", RegexOptions.IgnoreCase)]
    private static partial Regex JsonSecretPattern();

    /// <summary>Masque les secrets connus dans un texte.</summary>
    public static string Redact(string input)
    {
        var s = TokenPattern().Replace(input, "Token=\"***\"");
        s = ApiKeyPattern().Replace(s, "$1=***");
        s = HeaderPattern().Replace(s, "$1: ***");
        return JsonSecretPattern().Replace(s, "\"$1\":\"***\"");
    }
}
