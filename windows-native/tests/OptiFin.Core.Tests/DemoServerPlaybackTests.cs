using System.Collections.Concurrent;
using System.Runtime.InteropServices;
using OptiFin.Core.Api;
using OptiFin.Core.Auth;
using OptiFin.Core.Media;
using OptiFin.Core.Playback;
using OptiFin.Mpv;

namespace OptiFin.Core.Tests;

/// <summary>
/// Lecture de bout en bout contre un vrai Jellyfin (facultatif) : variable d'environnement
/// OPTIFIN_DEMO_SERVER = adresse du serveur, par exemple le serveur de démonstration public
/// https://demo.jellyfin.org/stable (compte « demo » sans mot de passe, par défaut) ; pour un autre
/// serveur, OPTIFIN_DEMO_USER et OPTIFIN_DEMO_PASSWORD. Même chemin que l'appli :
/// PlaybackInfo → plan → mpv avec l'en-tête Authorization.
/// </summary>
public partial class DemoServerPlaybackTests
{
    [LibraryImport("user32.dll", EntryPoint = "CreateWindowExW", StringMarshalling = StringMarshalling.Utf16)]
    private static partial nint CreateWindowEx(int exStyle, string className, string title, uint style, int x, int y, int w, int h,
        nint parent, nint menu, nint instance, nint param);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool DestroyWindow(nint hwnd);

    private sealed record Server(JellyfinClient Api, string UserId, PlaybackService Playback, MediaRepository Media);

    private static Server? _server;

    /// <summary>
    /// Réglages du serveur : variables d'environnement, sinon windows-native/tests/server.env (local,
    /// ignoré par git ; modèle : server.env.example).
    /// </summary>
    private static string? Setting(string name)
    {
        // Adresse, compte et mot de passe d'une seule et même source : jamais le mot de passe du
        // fichier envoyé à un autre serveur donné par l'environnement.
        if (Environment.GetEnvironmentVariable("OPTIFIN_DEMO_SERVER") is { Length: > 0 })
            return Environment.GetEnvironmentVariable(name);
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir != null; dir = dir.Parent)
        {
            var file = Path.Combine(dir.FullName, "tests", "server.env");
            if (!File.Exists(file)) continue;
            foreach (var line in File.ReadLines(file))
            {
                var eq = line.IndexOf('=');
                if (line.TrimStart().StartsWith('#') || eq < 0 || line[..eq].Trim() != name) continue;
                return line[(eq + 1)..].Trim();
            }
            return null;
        }
        return null;
    }

    private static async Task<Server> ConnectAsync()
    {
        var url = Setting("OPTIFIN_DEMO_SERVER");
        Assert.SkipWhen(string.IsNullOrEmpty(url), "Pas de serveur de test (OPTIFIN_DEMO_SERVER ou tests/server.env).");
        if (_server != null) return _server;
        var identity = new ClientIdentity("OptiFin", "Tests", "optifin-tests-demo", "1.0");
        var auth = new AuthService(identity);
        JellyfinServer server;
        try
        {
            server = await auth.ProbeAsync(url!);
        }
        catch (ApiException e) when (e.Kind is ApiErrorKind.Unreachable or ApiErrorKind.Timeout)
        {
            // Hors du réseau du serveur (push depuis ailleurs) : ces tests ne peuvent pas avoir lieu.
            Assert.Skip($"Serveur de test injoignable ({url}) : {e.UserMessage}");
            throw;
        }
        var session = await auth.LoginAsync(server, Setting("OPTIFIN_DEMO_USER") ?? "demo", Setting("OPTIFIN_DEMO_PASSWORD") ?? "");
        var api = new JellyfinClient(server.BaseUrl, identity, () => session.Token);
        var userId = session.Account.UserId;
        return _server = new Server(api, userId, new PlaybackService(api, userId), new MediaRepository(api, userId));
    }

    private static async Task<List<BaseItemDto>> VideosAsync(Server s) =>
        (await s.Api.GetAsync($"Users/{s.UserId}/Items", JellyfinJson.Default.BaseItemDtoQueryResult,
            [new("Recursive", "true"), new("IncludeItemTypes", "Movie,Episode"), new("Fields", "MediaStreams,MediaSources"), new("Limit", "200")]))
        .Items?.ToList() ?? [];

    private static async Task<BaseItemDto> VideoAsync(Server s, Func<BaseItemDto, bool> match) =>
        (await VideosAsync(s)).FirstOrDefault(match) ?? throw new InvalidOperationException("Vidéo de test absente du serveur.");

    private static MediaStream? VideoOf(BaseItemDto i) => i.MediaStreams?.FirstOrDefault(m => m.Type == "Video");

    private static MediaStream? AudioOf(BaseItemDto i) => i.MediaStreams?.FirstOrDefault(m => m.Type == "Audio" && m.IsDefault == true)
                                                          ?? i.MediaStreams?.FirstOrDefault(m => m.Type == "Audio");

    /// <summary>
    /// Formats d'un titre : conteneur, codec et définition de l'image, plage dynamique (SDR, HDR10,
    /// Dolby Vision…), codec, variante (DTS-HD MA…), son spatial (Atmos) et canaux de la piste audio.
    /// </summary>
    private static string FormatOf(BaseItemDto i)
    {
        var v = VideoOf(i);
        var a = AudioOf(i);
        var definition = v?.Width switch { >= 3200 => "4K", >= 1800 => "1080p", >= 1200 => "720p", null => "?", _ => "SD" };
        return string.Join(" · ", new[] { i.MediaSources?.FirstOrDefault()?.Container?.Split(',')[0], v?.Codec, definition, v?.BitDepth is > 8 ? $"{v.BitDepth} bits" : null,
            v?.VideoRangeType, a?.Codec, a?.Profile, a?.AudioSpatialFormat is { } sp and not "None" ? sp : null, a?.Channels is { } ch ? $"{ch} can." : null }
            .Where(x => !string.IsNullOrEmpty(x)));
    }

    /// <summary>Un seul titre par combinaison de formats.</summary>
    private static List<BaseItemDto> OnePerFormat(IEnumerable<BaseItemDto> items)
    {
        var picked = items.GroupBy(FormatOf).Select(g => g.First()).ToList();
        foreach (var i in picked) Progress($"format retenu : {FormatOf(i)} ({i.Name})");
        return picked;
    }

    /// <summary>Suivi en direct (ces tests durent plusieurs minutes sur une grosse bibliothèque).</summary>
    private static void Progress(string text) => Console.WriteLine($"  [serveur {DateTime.Now:HH:mm:ss}] {text}");

    private static async Task Until(Func<bool> ok, string what, int seconds = 45)
    {
        var deadline = DateTime.UtcNow.AddSeconds(seconds);
        while (!ok())
        {
            if (DateTime.UtcNow > deadline) Assert.Fail($"Délai dépassé : {what}");
            await Task.Delay(50);
        }
    }

    /// <summary>Lecteur mpv dans une fenêtre, avec le journal de ses événements.</summary>
    private sealed class Player : IDisposable
    {
        private readonly nint _hwnd = CreateWindowEx(0, "STATIC", "mpv", 0x80000000, 0, 0, 640, 360, 0, 0, 0, 0);
        public readonly MpvPlayer Mpv;
        public readonly ConcurrentQueue<string> Events = new();
        public readonly ConcurrentQueue<string> Errors = new();
        public volatile int FirstFrames;
        public TimeSpan Position;
        public TimeSpan Duration;
        public readonly ConcurrentQueue<string> Trace = new();

        public Player()
        {
            Mpv = MpvPlayer.Create(_hwnd);
            Mpv.FirstFrame += () =>
            {
                FirstFrames++;
                Events.Enqueue("first-frame");
            };
            Mpv.Ended += (r, e) => Events.Enqueue($"ended:{r}{(e != null ? $" ({e})" : "")}");
            Mpv.PositionChanged += p =>
            {
                Position = p;
                if (Trace.Count < 12) Trace.Enqueue($"{p.TotalSeconds:0.0}@{Environment.TickCount64 % 100000}");
            };
            Mpv.PlaybackRestarted += () => Trace.Enqueue($"restart@{Environment.TickCount64 % 100000}");
            Mpv.FileLoaded += () => Trace.Enqueue($"loaded@{Environment.TickCount64 % 100000}");
            Mpv.DurationChanged += d => Duration = d;
            Mpv.Log += (level, prefix, text) =>
            {
                if (level is "error" or "fatal") Errors.Enqueue($"[{prefix}] {text}");
            };
        }

        public void Load(Server s, PlaybackPlan plan, TimeSpan start) =>
            Mpv.Load(plan.StreamUrl, new Dictionary<string, string> { ["Authorization"] = s.Api.AuthorizationHeader }, start);

        public async Task PlaysFromAsync(TimeSpan start, string what, int seconds = 45)
        {
            await Until(() => FirstFrames >= 1 || Events.Any(e => e.StartsWith("ended:")), $"{what} : première image", seconds);
            Assert.True(FirstFrames >= 1, $"{what} : {string.Join(", ", Events)} / {string.Join(" | ", Errors)}");
            // Position de départ respectée, puis la lecture avance.
            await Until(() => Position >= start + TimeSpan.FromSeconds(1), $"{what} : lecture depuis {start}", seconds);
            Assert.True(Position < start + TimeSpan.FromSeconds(20), $"{what} : position {Position} pour un départ à {start} — {string.Join(" ", Trace)}");
        }

        public void Dispose()
        {
            Mpv.Dispose();
            DestroyWindow(_hwnd);
        }
    }

    [Fact]
    public async Task Lecture_directe_reprise_et_sauts()
    {
        var s = await ConnectAsync();
        var movie = await VideoAsync(s, i => i.Type == "Movie" && i.RunTimeTicks > TimeSpan.FromMinutes(20).Ticks);
        var start = TimeSpan.FromMinutes(5);
        var plan = await s.Playback.PrepareAsync(movie.Id!, start);
        Assert.Equal(PlayMethod.DirectPlay, plan.Method);
        Assert.DoesNotContain("api_key", plan.StreamUrl.Query, StringComparison.OrdinalIgnoreCase);
        using var p = new Player();
        p.Load(s, plan, start);
        await p.PlaysFromAsync(start, "lecture directe");
        await Until(() => p.Duration > TimeSpan.FromMinutes(20), "durée");
        Assert.Equal(plan.AudioTracks.Count, p.Mpv.Tracks().Count(t => t.Type == "audio"));

        // Sauts lointains en avant et en arrière (requêtes partielles au serveur).
        foreach (var target in new[] { TimeSpan.FromMinutes(15), TimeSpan.FromMinutes(1), TimeSpan.FromMinutes(18) })
        {
            p.Mpv.Seek(target);
            await Until(() => Math.Abs((p.Position - target).TotalSeconds) < 3, $"saut à {target}");
        }
        Assert.DoesNotContain(p.Events, e => e.StartsWith("ended:"));
    }

    [Fact]
    public async Task Transcodage_force_hls_reprise_et_sauts()
    {
        var s = await ConnectAsync();
        var movie = await VideoAsync(s, i => i.Type == "Movie" && i.RunTimeTicks > TimeSpan.FromMinutes(20).Ticks);
        // 6:40 : une image clé proche (vers 3:00, ce film n'en a pas avant 3:36 : en copie vidéo, le serveur
        // ne peut commencer qu'à une image clé).
        var start = TimeSpan.FromSeconds(400);
        var plan = await s.Playback.PrepareAsync(movie.Id!, start, forceTranscode: true);
        Assert.NotEqual(PlayMethod.DirectPlay, plan.Method);
        Assert.DoesNotContain("api_key", plan.StreamUrl.Query, StringComparison.OrdinalIgnoreCase);
        using var p = new Player();
        p.Load(s, plan, start);
        await p.PlaysFromAsync(start, $"{plan.Method} ({plan.StreamUrl.AbsolutePath})", 90);
        var target = TimeSpan.FromMinutes(12);
        p.Mpv.Seek(target);
        await Until(() => Math.Abs((p.Position - target).TotalSeconds) < 5, "saut en transcodage", 90);
        // Après un saut, le serveur relance son transcodage à la nouvelle position : quelques secondes
        // sur un petit serveur (pas une panne, tant que la lecture repart).
        var deadline = DateTime.UtcNow.AddSeconds(30);
        while (p.Position < target + TimeSpan.FromSeconds(1) && DateTime.UtcNow < deadline) await Task.Delay(100);
        Assert.True(p.Position >= target + TimeSpan.FromSeconds(1),
            $"la lecture ne repart pas après le saut ({p.Position}, attente de données : {p.Mpv.Get("paused-for-cache")}, " +
            $"tampon {p.Mpv.Get("demuxer-cache-duration")} s, {string.Join(" | ", p.Errors.TakeLast(5))})");
        Assert.DoesNotContain(p.Events, e => e.StartsWith("ended:"));
        await s.Playback.ReportStoppedAsync(plan, p.Position);
    }

    [Fact]
    public async Task Debit_limite_bascule_en_transcodage()
    {
        var s = await ConnectAsync();
        var movie = await VideoAsync(s, i => i.Type is "Movie" or "Episode" && i.MediaStreams?.Any(m => m.Type == "Video" && m.Width >= 1280) == true);
        var plan = await s.Playback.PrepareAsync(movie.Id!, TimeSpan.Zero, maxBitrate: 1_000_000);
        Assert.Equal(PlayMethod.Transcode, plan.Method);
        using var p = new Player();
        p.Load(s, plan, TimeSpan.Zero);
        await p.PlaysFromAsync(TimeSpan.Zero, "transcodage à 1 Mb/s", 90);
        await s.Playback.ReportStoppedAsync(plan, p.Position);
    }

    [Fact]
    public async Task Tous_les_titres_demarrent_en_lecture_directe()
    {
        var s = await ConnectAsync();
        var failures = new List<string>();
        // Un titre par combinaison de formats : lire 200 films semblables n'apprend rien de plus.
        var all = OnePerFormat((await VideosAsync(s)).Where(i => i.Type is "Movie" or "Episode"));
        foreach (var (item, n) in all.Select((i, n) => (i, n + 1)))
        {
            Progress($"titres {n}/{all.Count} : {item.Name}");
            try
            {
                var plan = await s.Playback.PrepareAsync(item.Id!, TimeSpan.Zero);
                using var p = new Player();
                p.Load(s, plan, TimeSpan.Zero);
                await Until(() => p.FirstFrames >= 1 || p.Events.Any(e => e.StartsWith("ended:")), item.Name!, 45);
                if (p.FirstFrames == 0) failures.Add($"{item.Name} ({plan.Method}) : {string.Join(", ", p.Events)} / {string.Join(" | ", p.Errors)}");
            }
            catch (Exception e)
            {
                failures.Add($"{item.Name} : {e.GetType().Name} {e.Message}");
            }
        }
        Assert.True(failures.Count == 0, string.Join("\n", failures));
    }

    /// <summary>
    /// Contenus HDR (HDR10, HLG, Dolby Vision) et son multicanal (DTS, TrueHD, E-AC3, Atmos) du serveur :
    /// lecture directe, courbe de l'image et nombre de canaux vus par mpv conformes au fichier.
    /// </summary>
    [Fact]
    public async Task Contenus_hdr_et_son_multicanal()
    {
        var s = await ConnectAsync();
        var items = OnePerFormat((await VideosAsync(s)).Where(i =>
            VideoOf(i)?.VideoRangeType is { } r && r != "SDR" ||
            AudioOf(i) is { Channels: > 2 } || AudioOf(i)?.Codec is "truehd" or "dts" or "eac3"));
        Assert.SkipWhen(items.Count == 0, "Aucun contenu HDR ni multicanal sur ce serveur.");
        var failures = new List<string>();
        var report = new List<string>();
        foreach (var (item, n) in items.Select((i, n) => (i, n + 1)))
        {
            Progress($"HDR / multicanal {n}/{items.Count} : {item.Name}");
            try
            {
                var plan = await s.Playback.PrepareAsync(item.Id!, TimeSpan.FromSeconds(60));
                using var p = new Player();
                p.Load(s, plan, TimeSpan.FromSeconds(60));
                await Until(() => p.FirstFrames >= 1 || p.Events.Any(e => e.StartsWith("ended:")), item.Name!, 60);
                if (p.FirstFrames == 0)
                {
                    failures.Add($"{item.Name} : ne démarre pas ({plan.Method}) {string.Join(", ", p.Events)} / {string.Join(" | ", p.Errors)}");
                    continue;
                }
                await Task.Delay(2500);
                var range = VideoOf(item)?.VideoRangeType ?? "SDR";
                var gamma = p.Mpv.Get("video-params/gamma");
                int.TryParse(p.Mpv.Get("audio-params/channel-count"), out var channels);
                var expectedChannels = AudioOf(item)?.Channels;
                report.Add($"{item.Name} : {plan.Method}, {range} → {gamma} → sortie {p.Mpv.Get("video-target-params/gamma")}, " +
                           $"son {p.Mpv.Get("audio-codec-name")} {channels} can. (fichier {expectedChannels}), décodage {p.Mpv.Get("hwdec-current")}, " +
                           $"{p.Mpv.DroppedFrames} images perdues");
                // Dolby Vision profil 5 : pas de couche HDR10, mpv le reconstruit (gamma pq attendue aussi).
                var expectedGamma = range switch
                {
                    "HLG" or "DOVIWithHLG" => "hlg",
                    "SDR" => null,
                    _ => "pq",
                };
                if (plan.Method == PlayMethod.DirectPlay && expectedGamma != null && gamma != expectedGamma)
                    failures.Add($"{item.Name} : {range} vu comme « {gamma} » (attendu {expectedGamma})");
                if (plan.Method == PlayMethod.DirectPlay && expectedChannels is { } ch && channels != ch)
                    failures.Add($"{item.Name} : {channels} canaux décodés pour {ch} dans le fichier");
                await s.Playback.ReportStoppedAsync(plan, p.Position);
            }
            catch (Exception e)
            {
                failures.Add($"{item.Name} : {e.GetType().Name} {e.Message}");
            }
        }
        TestContext.Current.SendDiagnosticMessage(string.Join("\n", report));
        Assert.True(failures.Count == 0, string.Join("\n", failures.Concat(["— Détail :"]).Concat(report)));
    }

    [Fact]
    public async Task Sources_multiples_choisies()
    {
        var s = await ConnectAsync();
        var movie = (await VideosAsync(s)).FirstOrDefault(i => i.MediaSources?.Count > 1);
        Assert.SkipWhen(movie is null, "Aucun titre à plusieurs versions sur le serveur en ce moment.");
        foreach (var source in movie!.MediaSources!)
        {
            var plan = await s.Playback.PrepareAsync(movie.Id!, TimeSpan.Zero, mediaSourceId: source.Id);
            Assert.Equal(source.Id, plan.MediaSourceId);
            using var p = new Player();
            p.Load(s, plan, TimeSpan.Zero);
            await p.PlaysFromAsync(TimeSpan.Zero, $"source {source.Id}");
        }
    }

    [Fact]
    public async Task Episode_suivant_et_complements()
    {
        var s = await ConnectAsync();
        var episodes = (await VideosAsync(s)).Where(i => i.Type == "Episode").ToList();
        var episode = await s.Media.ItemAsync(episodes[0].Id!);
        var extras = await s.Playback.ExtrasAsync(episode, s.Media);
        Assert.NotNull(extras.NextEpisode);
        Assert.NotEqual(episode.Id, extras.NextEpisode!.Id);

        // Comme l'appli : premier épisode, puis le suivant dans le même lecteur.
        using var p = new Player();
        var first = await s.Playback.PrepareAsync(episode.Id, TimeSpan.FromMinutes(2));
        p.Load(s, first, TimeSpan.FromMinutes(2));
        await p.PlaysFromAsync(TimeSpan.FromMinutes(2), "épisode");
        var next = await s.Playback.PrepareAsync(extras.NextEpisode.Id, TimeSpan.Zero);
        p.FirstFrames = 0;
        p.Events.Clear();
        p.Load(s, next, TimeSpan.Zero);
        await p.PlaysFromAsync(TimeSpan.Zero, "épisode suivant");
        Assert.DoesNotContain(p.Events, e => e.StartsWith("ended:"));
    }

    [Fact]
    public async Task Repli_en_transcodage_apres_echec_de_la_lecture_directe()
    {
        var s = await ConnectAsync();
        var movie = await VideoAsync(s, i => i.Type == "Movie");
        var direct = await s.Playback.PrepareAsync(movie.Id!, TimeSpan.Zero);
        using var p = new Player();
        // Lecture directe impossible (flux introuvable sur le serveur) : erreur, sans « première image ».
        p.Mpv.Load(new Uri(direct.StreamUrl.ToString().Replace(movie.Id!, "0123456789abcdef0123456789abcdef")),
            new Dictionary<string, string> { ["Authorization"] = s.Api.AuthorizationHeader }, TimeSpan.Zero);
        await Until(() => p.Events.Any(e => e.StartsWith("ended:")), "échec");
        Assert.Equal(0, p.FirstFrames);
        Assert.Contains(p.Events, e => e.StartsWith("ended:Error"));
        // Repli dans le même lecteur, comme l'appli.
        p.Events.Clear();
        var fallback = await s.Playback.PrepareAsync(movie.Id!, TimeSpan.FromSeconds(30), forceTranscode: true);
        p.Load(s, fallback, TimeSpan.FromSeconds(30));
        await p.PlaysFromAsync(TimeSpan.FromSeconds(30), "repli", 90);
        await s.Playback.ReportStoppedAsync(fallback, p.Position);
    }

    [Fact]
    public async Task Position_enregistree_par_le_serveur()
    {
        var s = await ConnectAsync();
        var movie = await VideoAsync(s, i => i.Type == "Movie" && i.RunTimeTicks > TimeSpan.FromMinutes(20).Ticks);
        var plan = await s.Playback.PrepareAsync(movie.Id!, TimeSpan.Zero);
        var at = TimeSpan.FromMinutes(7);
        await s.Playback.ReportStartAsync(plan, at);
        await s.Playback.ReportProgressAsync(plan, at, paused: true);
        await s.Playback.ReportStoppedAsync(plan, at);
        var item = await s.Media.ItemAsync(movie.Id!);
        Assert.InRange(item.ResumePosition.TotalSeconds, at.TotalSeconds - 2, at.TotalSeconds + 2);
    }
}
