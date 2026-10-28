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

    /// <summary>
    /// Position, ~5 fois par seconde (mpv la signale à chaque image : 24 à 60 mises à jour d'interface
    /// par seconde pour rien). Sauts et mises en pause : signalés tout de suite.
    /// </summary>
    public event Action<TimeSpan>? PositionChanged;

    /// <summary>Position exacte (dernière image), pour les calculs fins (Watch Party).</summary>
    public TimeSpan Position { get; private set; }
    public event Action<TimeSpan>? DurationChanged;
    public event Action<bool>? PauseChanged;
    public event Action<bool>? BufferingChanged;
    /// <summary>Lecture arrêtée faute de données (mémoire tampon vide), hors sauts.</summary>
    public event Action<bool>? CacheStallChanged;
    public event Action<TimeSpan>? BufferedChanged;
    public event Action<int, int>? VideoSizeChanged;
    public event Action? FileLoaded;
    /// <summary>
    /// Lecture réellement partie après une ouverture (premier « playback-restart » du fichier chargé).
    /// Pas « video-reconfig » : avec force-window, mpv le signale aussi quand le fichier n'a pas pu
    /// s'ouvrir, et l'appli croyait la lecture démarrée (plus de repli en transcodage).
    /// </summary>
    public event Action? FirstFrame;
    public event Action? PlaybackRestarted;
    public event Action<EndReason, string?>? Ended;
    public event Action<string, string, string>? Log;

    private bool _cache;
    private bool _seeking;
    private double _emittedPosition = double.NaN;
    private double _width;
    private double _height;

    // Entrée de liste de mpv du dernier Load, et celle que mpv joue réellement. Entre les deux
    // (rechargement : épisode suivant, repli, changement de piste), les événements de l'ancien
    // fichier sont ignorés : sa fin n'est ni une fin de lecture ni une erreur du nouveau.
    private long _requestedEntry = -1;
    private long _playingEntry = -1;
    private bool _loaded;
    private bool _awaitingStart;
    /// <summary>Entrée demandée / entrée jouée : lues et écrites ensemble.</summary>
    private readonly Lock _gate = new();
    /// <summary>Appels natifs et libération : jamais en même temps (mpv libéré = pointeur invalide).</summary>
    private readonly ReaderWriterLockSlim _life = new(LockRecursionPolicy.SupportsRecursion);

    private bool IsCurrent
    {
        get
        {
            var requested = Interlocked.Read(ref _requestedEntry);
            return requested < 0 || requested == _playingEntry;
        }
    }

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

    // Appels natifs : en parallèle entre eux (verrou partagé), jamais pendant la libération (exclusif).
    private bool Enter()
    {
        _life.EnterReadLock();
        if (_ctx != 0) return true;
        _life.ExitReadLock();
        return false;
    }

    private void Exit() => _life.ExitReadLock();

    public void Command(params string[] args)
    {
        var pointers = new nint[args.Length + 1];
        try
        {
            for (var i = 0; i < args.Length; i++) pointers[i] = Marshal.StringToCoTaskMemUTF8(args[i]);
            if (!Enter()) return;
            int rc;
            try
            {
                fixed (nint* p = pointers) rc = MpvNative.Command(_ctx, p);
            }
            finally
            {
                Exit();
            }
            if (rc < 0) throw new InvalidOperationException($"{args[0]} : {MpvNative.Error(rc)}");
        }
        finally
        {
            foreach (var p in pointers)
                if (p != 0) Marshal.FreeCoTaskMem(p);
        }
    }

    public bool TrySet(string name, string value)
    {
        if (!Enter()) return false;
        try
        {
            return MpvNative.SetPropertyString(_ctx, name, value) >= 0;
        }
        finally
        {
            Exit();
        }
    }

    public string? Get(string name)
    {
        if (!Enter()) return null;
        nint p;
        try
        {
            p = MpvNative.GetPropertyString(_ctx, name);
        }
        finally
        {
            Exit();
        }
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
        if (!Enter()) return null;
        try
        {
            double value;
            return MpvNative.GetProperty(_ctx, name, MpvNative.FormatDouble, &value) >= 0 ? value : null;
        }
        finally
        {
            Exit();
        }
    }

    private long? GetLong(string name)
    {
        if (!Enter()) return null;
        try
        {
            long value;
            return MpvNative.GetProperty(_ctx, name, MpvNative.FormatInt64, &value) >= 0 ? value : null;
        }
        finally
        {
            Exit();
        }
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
        Position = start;
        _emittedPosition = double.NaN;
        Command("change-list", "http-header-fields", "clr", "");
        foreach (var (key, value) in headers) Command("change-list", "http-header-fields", "append", $"{key}: {value}");
        TrySet("user-agent", "OptiFin");
        TrySet("pause", "no");
        if (title != null) TrySet("force-media-title", title);
        var startSeconds = start.TotalSeconds.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture);
        // Sous le verrou : le fil des événements ne juge aucun événement tant que la nouvelle entrée
        // (seule de la liste après « replace ») n'est pas connue.
        lock (_gate)
        {
            Command("loadfile", url, "replace", "-1", $"start={startSeconds}");
            Interlocked.Exchange(ref _requestedEntry, GetLong("playlist/0/id") ?? -1);
        }
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

    private bool Current()
    {
        lock (_gate) return IsCurrent;
    }

    private void EventLoop()
    {
        // Contexte copié : Dispose remet _ctx à zéro pendant que ce fil peut encore attendre.
        var ctx = _ctx;
        while (!_disposed)
        {
            var e = MpvNative.WaitEvent(ctx, -1);
            if (e == null || _disposed) continue;
            switch (e->EventId)
            {
                case MpvNative.EventNone:
                    continue;
                case MpvNative.EventShutdown:
                    return;
                case MpvNative.EventPropertyChange:
                    OnProperty((MpvNative.PropertyData*)e->Data);
                    break;
                case MpvNative.EventStartFile:
                    lock (_gate)
                    {
                        _playingEntry = e->Data != 0 ? ((MpvNative.StartFileData*)e->Data)->PlaylistEntryId : -1;
                        _loaded = false;
                        _awaitingStart = false;
                    }
                    break;
                case MpvNative.EventFileLoaded:
                    if (!Current()) break;
                    _loaded = true;
                    _awaitingStart = true;
                    FileLoaded?.Invoke();
                    break;
                case MpvNative.EventPlaybackRestart:
                    if (!Current()) break;
                    if (_loaded && _awaitingStart)
                    {
                        _awaitingStart = false;
                        FirstFrame?.Invoke();
                    }
                    PlaybackRestarted?.Invoke();
                    break;
                case MpvNative.EventEndFile:
                {
                    var end = (MpvNative.EndFileData*)e->Data;
                    long requested;
                    lock (_gate) requested = _requestedEntry;
                    // Fin d'un fichier remplacé depuis : rien à signaler.
                    if (requested >= 0 && end->PlaylistEntryId != requested) break;
                    _loaded = false;
                    _awaitingStart = false;
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

    private void EmitPosition()
    {
        _emittedPosition = Position.TotalSeconds;
        PositionChanged?.Invoke(Position);
    }

    private void OnProperty(MpvNative.PropertyData* p)
    {
        var name = Marshal.PtrToStringUTF8(p->Name);
        if (p->Data == 0 || name is null) return;
        double D() => *(double*)p->Data;
        bool F() => *(int*)p->Data != 0;
        static TimeSpan S(double s) => double.IsFinite(s) ? TimeSpan.FromSeconds(Math.Max(0, s)) : TimeSpan.Zero;
        // Position, durée et tampon d'un fichier en cours de remplacement : périmés.
        if (name is "time-pos" or "duration" or "demuxer-cache-time" && !Current()) return;
        switch (name)
        {
            case "time-pos":
                var position = D();
                Position = S(position);
                if (double.IsNaN(_emittedPosition) || Math.Abs(position - _emittedPosition) >= 0.2) EmitPosition();
                break;
            case "duration": DurationChanged?.Invoke(S(D())); break;
            case "pause":
                var paused = F();
                if (paused) EmitPosition();
                PauseChanged?.Invoke(paused);
                break;
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
        nint ctx;
        _life.EnterWriteLock();
        try
        {
            if (_disposed) return;
            _disposed = true;
            // Plus aucun appel natif après ceci (ceux en cours sont finis : verrou exclusif).
            ctx = _ctx;
            _ctx = 0;
        }
        finally
        {
            _life.ExitWriteLock();
        }
        // Débloque le fil des événements, puis libère mpv (attend la fin de ses threads).
        MpvNative.Wakeup(ctx);
        if (_events.IsAlive && Thread.CurrentThread != _events) _events.Join(TimeSpan.FromSeconds(2));
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
