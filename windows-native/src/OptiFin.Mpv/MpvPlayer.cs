using System.Runtime.InteropServices;
using System.Text;

namespace OptiFin.Mpv;

public enum EndReason { Eof, Stop, Error }

/// <summary>Piste du fichier vue par mpv.</summary>
public sealed record MpvTrack(int Id, string Type, bool External, string? Language, string? Title, string? Codec);

/// <summary>
/// Un lecteur libmpv affichant dans une fenêtre Windows (<c>wid</c>).
///
/// Rendu gpu-next (libplacebo) sur Direct3D 11, décodage matériel D3D11VA (copie zéro), HDR10,
/// HLG et Dolby Vision envoyés tels quels à un écran HDR (sinon convertis proprement en SDR).
/// Les événements arrivent sur un thread dédié : l'appli les renvoie vers son thread d'interface.
/// </summary>
public sealed unsafe class MpvPlayer : IDisposable
{
    private nint _ctx;
    private readonly Thread _events;
    private volatile bool _disposed;

    // Propriétés suivies (identifiant = rang dans ce tableau).
    private static readonly (string Name, int Format)[] Observed =
    [
        ("time-pos", MpvNative.FormatDouble), ("duration", MpvNative.FormatDouble), ("pause", MpvNative.FormatFlag),
        ("paused-for-cache", MpvNative.FormatFlag), ("seeking", MpvNative.FormatFlag), ("demuxer-cache-time", MpvNative.FormatDouble),
        ("speed", MpvNative.FormatDouble), ("dwidth", MpvNative.FormatDouble), ("dheight", MpvNative.FormatDouble),
        ("volume", MpvNative.FormatDouble), ("mute", MpvNative.FormatFlag), ("core-idle", MpvNative.FormatFlag),
    ];

    public event Action<TimeSpan>? PositionChanged;
    public event Action<TimeSpan>? DurationChanged;
    public event Action<bool>? PauseChanged;
    public event Action<bool>? BufferingChanged;
    /// <summary>Lecture arrêtée faute de données (mémoire tampon vide), hors sauts.</summary>
    public event Action<bool>? CacheStallChanged;
    public event Action<TimeSpan>? BufferedChanged;
    public event Action<int, int>? VideoSizeChanged;
    public event Action? FileLoaded;
    public event Action? FirstFrame;
    public event Action? PlaybackRestarted;
    public event Action<EndReason, string?>? Ended;
    public event Action<string, string, string>? Log;

    private bool _cache;
    private bool _seeking;
    private double _width;
    private double _height;

    private MpvPlayer(nint ctx)
    {
        _ctx = ctx;
        // Démarré à la première ouverture : les abonnés reçoivent aussi l'état initial de mpv.
        _events = new Thread(EventLoop) { IsBackground = true, Name = "mpv-événements" };
    }

    /// <summary>Crée le lecteur dans la fenêtre <paramref name="wid"/> (HWND).</summary>
    public static MpvPlayer Create(nint wid, bool verbose = false)
    {
        var ctx = MpvNative.Create();
        if (ctx == 0) throw new InvalidOperationException("mpv_create a échoué");
        void Set(string name, string value) => MpvNative.SetOptionString(ctx, name, value);
        Set("wid", wid.ToString());
        Set("vo", "gpu-next");
        Set("gpu-api", "d3d11");
        Set("gpu-context", "d3d11");
        Set("hwdec", "auto-safe");
        Set("target-colorspace-hint", "yes");
        Set("video-sync", "display-resample");
        // Piloté par OptiFin : ni raccourcis, ni affichage à l'écran, ni scripts, ni fichiers annexes.
        Set("input-default-bindings", "no");
        Set("input-vo-keyboard", "no");
        Set("input-cursor", "no");
        // Curseur masqué sur la vidéo : il reparaît sur les commandes dès que la souris bouge.
        Set("cursor-autohide", "always");
        Set("osc", "no");
        Set("osd-level", "0");
        Set("idle", "yes");
        Set("keep-open", "no");
        Set("force-window", "yes");
        Set("background-color", "#000000");
        Set("sub-auto", "no");
        Set("audio-file-auto", "no");
        Set("ytdl", "no");
        Set("load-scripts", "no");
        Set("config", "no");
        Set("terminal", "no");
        // Réseau domestique, fichiers 4K à haut débit : tampon généreux.
        Set("cache", "yes");
        Set("demuxer-max-bytes", "256MiB");
        Set("demuxer-max-back-bytes", "64MiB");
        Set("demuxer-readahead-secs", "30");
        Set("network-timeout", "30");
        // Sous-titres : styles ASS conservés (taille réglable), police de Windows.
        Set("sub-ass-override", "scale");
        Set("sub-font", "Segoe UI");
        Set("sub-use-margins", "no");
        var rc = MpvNative.Initialize(ctx);
        if (rc < 0)
        {
            MpvNative.TerminateDestroy(ctx);
            throw new InvalidOperationException($"mpv_initialize : {MpvNative.Error(rc)}");
        }
        MpvNative.RequestLogMessages(ctx, verbose ? "info" : "warn");
        for (var i = 0; i < Observed.Length; i++) MpvNative.ObserveProperty(ctx, (ulong)i, Observed[i].Name, Observed[i].Format);
        return new MpvPlayer(ctx);
    }

    // ------------------------------------------------------------ Commandes

    public void Command(params string[] args)
    {
        if (_disposed) return;
        var pointers = new nint[args.Length + 1];
        try
        {
            for (var i = 0; i < args.Length; i++) pointers[i] = Marshal.StringToCoTaskMemUTF8(args[i]);
            fixed (nint* p = pointers)
            {
                var rc = MpvNative.Command(_ctx, p);
                if (rc < 0) throw new InvalidOperationException($"{args[0]} : {MpvNative.Error(rc)}");
            }
        }
        finally
        {
            foreach (var p in pointers)
                if (p != 0) Marshal.FreeCoTaskMem(p);
        }
    }

    public bool TrySet(string name, string value) => !_disposed && MpvNative.SetPropertyString(_ctx, name, value) >= 0;

    public string? Get(string name)
    {
        if (_disposed) return null;
        var p = MpvNative.GetPropertyString(_ctx, name);
        if (p == 0) return null;
        try
        {
            return Marshal.PtrToStringUTF8(p);
        }
        finally
        {
            MpvNative.Free(p);
        }
    }

    public double? GetDouble(string name)
    {
        if (_disposed) return null;
        double value;
        return MpvNative.GetProperty(_ctx, name, MpvNative.FormatDouble, &value) >= 0 ? value : null;
    }

    /// <summary>
    /// Ouvre un flux. Les en-têtes (Authorization) sont ajoutés un par un : aucune découpe sur les
    /// virgules, jamais de jeton dans l'URL.
    /// </summary>
    public void Load(Uri url, IReadOnlyDictionary<string, string> headers, TimeSpan start, string? title = null) =>
        Load(url.ToString(), headers, start, title);

    public void Load(string url, IReadOnlyDictionary<string, string> headers, TimeSpan start, string? title = null)
    {
        if (!_events.IsAlive && !_disposed) _events.Start();
        Command("change-list", "http-header-fields", "clr", "");
        foreach (var (key, value) in headers) Command("change-list", "http-header-fields", "append", $"{key}: {value}");
        TrySet("user-agent", "OptiFin");
        TrySet("pause", "no");
        if (title != null) TrySet("force-media-title", title);
        var startSeconds = start.TotalSeconds.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture);
        Command("loadfile", url, "replace", "-1", $"start={startSeconds}");
    }

    public void Play() => TrySet("pause", "no");
    public void Pause() => TrySet("pause", "yes");
    public void Stop() => Command("stop");

    public void Seek(TimeSpan position) =>
        Command("seek", position.TotalSeconds.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture), "absolute");

    public void SetSpeed(double speed) => TrySet("speed", speed.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture));

    /// <summary>Volume 0..1.</summary>
    public void SetVolume(double volume) => TrySet("volume", Math.Round(Math.Clamp(volume, 0, 1) * 100).ToString());

    public void SetMute(bool mute) => TrySet("mute", mute ? "yes" : "no");

    /// <summary>Pistes du fichier (type « audio », « sub » ou « video »).</summary>
    public IReadOnlyList<MpvTrack> Tracks()
    {
        var count = (int)(GetDouble("track-list/count") ?? 0);
        var list = new List<MpvTrack>(count);
        for (var i = 0; i < count; i++)
        {
            if (!int.TryParse(Get($"track-list/{i}/id"), out var id)) continue;
            list.Add(new MpvTrack(id, Get($"track-list/{i}/type") ?? "", Get($"track-list/{i}/external") == "yes",
                Get($"track-list/{i}/lang"), Get($"track-list/{i}/title"), Get($"track-list/{i}/codec")));
        }
        return list;
    }

    public void SelectAudio(int? mpvId) => TrySet("aid", mpvId?.ToString() ?? "auto");
    public void SelectSubtitle(int? mpvId) => TrySet("sid", mpvId?.ToString() ?? "no");

    public void AddSubtitle(Uri url, string? title, string? language) =>
        Command("sub-add", url.ToString(), "select", title ?? "", language ?? "");

    public int DroppedFrames => (int)((GetDouble("frame-drop-count") ?? 0) + (GetDouble("decoder-frame-drop-count") ?? 0));

    // ------------------------------------------------------------ Événements

    private void EventLoop()
    {
        while (!_disposed)
        {
            var e = MpvNative.WaitEvent(_ctx, -1);
            if (e == null) continue;
            switch (e->EventId)
            {
                case MpvNative.EventNone:
                    continue;
                case MpvNative.EventShutdown:
                    return;
                case MpvNative.EventPropertyChange:
                    OnProperty((MpvNative.PropertyData*)e->Data);
                    break;
                case MpvNative.EventFileLoaded:
                    FileLoaded?.Invoke();
                    break;
                case MpvNative.EventVideoReconfig:
                    FirstFrame?.Invoke();
                    break;
                case MpvNative.EventPlaybackRestart:
                    PlaybackRestarted?.Invoke();
                    break;
                case MpvNative.EventEndFile:
                {
                    var end = (MpvNative.EndFileData*)e->Data;
                    var reason = end->Reason switch
                    {
                        MpvNative.EndFileEof => EndReason.Eof,
                        MpvNative.EndFileError => EndReason.Error,
                        _ => EndReason.Stop,
                    };
                    Ended?.Invoke(reason, reason == EndReason.Error ? MpvNative.Error(end->Error) : null);
                    break;
                }
                case MpvNative.EventLogMessage:
                {
                    var log = (MpvNative.LogMessageData*)e->Data;
                    Log?.Invoke(Marshal.PtrToStringUTF8(log->Level) ?? "", Marshal.PtrToStringUTF8(log->Prefix) ?? "",
                        (Marshal.PtrToStringUTF8(log->Text) ?? "").TrimEnd());
                    break;
                }
            }
        }
    }

    private void OnProperty(MpvNative.PropertyData* p)
    {
        var name = Marshal.PtrToStringUTF8(p->Name);
        if (p->Data == 0 || name is null) return;
        double D() => *(double*)p->Data;
        bool F() => *(int*)p->Data != 0;
        static TimeSpan S(double s) => double.IsFinite(s) ? TimeSpan.FromSeconds(Math.Max(0, s)) : TimeSpan.Zero;
        switch (name)
        {
            case "time-pos": PositionChanged?.Invoke(S(D())); break;
            case "duration": DurationChanged?.Invoke(S(D())); break;
            case "pause": PauseChanged?.Invoke(F()); break;
            case "paused-for-cache":
                _cache = F();
                CacheStallChanged?.Invoke(_cache);
                BufferingChanged?.Invoke(_cache || _seeking);
                break;
            case "seeking":
                _seeking = F();
                BufferingChanged?.Invoke(_cache || _seeking);
                break;
            case "demuxer-cache-time": BufferedChanged?.Invoke(S(D())); break;
            case "dwidth":
                _width = D();
                if (_width > 0 && _height > 0) VideoSizeChanged?.Invoke((int)_width, (int)_height);
                break;
            case "dheight":
                _height = D();
                if (_width > 0 && _height > 0) VideoSizeChanged?.Invoke((int)_width, (int)_height);
                break;
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        var ctx = _ctx;
        _ctx = 0;
        // Débloque le fil des événements, puis libère mpv (attend la fin de ses threads).
        MpvNative.Wakeup(ctx);
        if (_events.IsAlive) _events.Join(TimeSpan.FromSeconds(2));
        MpvNative.TerminateDestroy(ctx);
    }
}

/// <summary>Version de libmpv (journaux, diagnostic).</summary>
public static class MpvInfo
{
    public static string Describe(MpvPlayer p) =>
        new StringBuilder()
            .Append("sortie ").Append(p.Get("current-vo") ?? "?")
            .Append(", décodage ").Append(p.Get("hwdec-current") ?? "?")
            .Append(", source ").Append(p.Get("video-params/gamma") ?? "?")
            .Append(" → sortie ").Append(p.Get("video-target-params/gamma") ?? "?")
            .ToString();
}
