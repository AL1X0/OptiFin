using System.Collections.Concurrent;
using System.Diagnostics;
using System.Net;
using System.Runtime.InteropServices;
using OptiFin.Mpv;

namespace OptiFin.Core.Tests;

/// <summary>
/// Fiabilité de la lecture sur un vrai libmpv : ce que fait le lecteur de l'appli (rechargement pour
/// l'épisode suivant, repli en transcodage, changement de piste côté serveur), flux HTTP authentifié
/// avec sauts, et fermeture en pleine lecture.
/// </summary>
public partial class PlaybackReliabilityTests
{
    [LibraryImport("user32.dll", EntryPoint = "CreateWindowExW", StringMarshalling = StringMarshalling.Utf16)]
    private static partial nint CreateWindowEx(int exStyle, string className, string title, uint style, int x, int y, int w, int h,
        nint parent, nint menu, nint instance, nint param);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool DestroyWindow(nint hwnd);

    private static nint Window() => CreateWindowEx(0, "STATIC", "mpv", 0x80000000 /* WS_POPUP */, 0, 0, 640, 360, 0, 0, 0, 0);

    private static string Clip(double seconds) =>
        $"av://lavfi:testsrc2=size=320x180:rate=30:duration={seconds.ToString(System.Globalization.CultureInfo.InvariantCulture)}";

    private static readonly Dictionary<string, string> NoHeaders = [];

    private static async Task Until(Func<bool> ok, string what, int seconds = 15)
    {
        var deadline = DateTime.UtcNow.AddSeconds(seconds);
        while (!ok())
        {
            if (DateTime.UtcNow > deadline) Assert.Fail($"Délai dépassé : {what}");
            await Task.Delay(50);
        }
    }

    /// <summary>Journal des événements du lecteur, dans l'ordre où ils arrivent.</summary>
    private sealed class Recorder
    {
        public readonly ConcurrentQueue<string> Events = new();
        public volatile int FirstFrames;
        public TimeSpan Position;

        public Recorder(MpvPlayer p)
        {
            p.FileLoaded += () => Events.Enqueue("loaded");
            p.FirstFrame += () =>
            {
                FirstFrames++;
                Events.Enqueue("first-frame");
            };
            p.Ended += (r, _) => Events.Enqueue($"ended:{r}");
            p.PositionChanged += pos => Position = pos;
        }

        public void Clear()
        {
            Events.Clear();
            FirstFrames = 0;
        }

        public bool Has(string e) => Events.Contains(e);
        public override string ToString() => string.Join(", ", Events);
    }

    [Fact]
    public async Task Rechargement_en_pleine_lecture_sans_evenement_perime()
    {
        var hwnd = Window();
        using var player = MpvPlayer.Create(hwnd);
        var rec = new Recorder(player);
        player.Load(Clip(30), NoHeaders, TimeSpan.Zero);
        await Until(() => rec.FirstFrames == 1 && rec.Position > TimeSpan.FromSeconds(0.5), "premier titre");

        // Épisode suivant / repli : nouveau flux dans le même lecteur.
        rec.Clear();
        player.Load(Clip(6), NoHeaders, TimeSpan.FromSeconds(2));
        await Until(() => rec.FirstFrames >= 1, "image du second titre");
        // La « première image » du second titre suit son chargement (pas un reste du premier).
        var events = rec.Events.ToList();
        Assert.True(events.IndexOf("loaded") >= 0 && events.IndexOf("loaded") < events.IndexOf("first-frame"), rec.ToString());
        // L'arrêt du premier titre n'est ni une fin normale, ni une erreur.
        Assert.DoesNotContain("ended:Eof", events);
        Assert.DoesNotContain("ended:Error", events);
        await Until(() => rec.Position >= TimeSpan.FromSeconds(2.2), "lecture depuis 2 s");
        Assert.Equal(1, rec.FirstFrames);
        await Until(() => rec.Has("ended:Eof"), "fin du second titre");
        DestroyWindow(hwnd);
    }

    [Fact]
    public async Task Fin_de_l_ancien_titre_pendant_le_chargement_du_suivant_ignoree()
    {
        var hwnd = Window();
        using var player = MpvPlayer.Create(hwnd);
        var rec = new Recorder(player);
        for (var i = 0; i < 6; i++)
        {
            rec.Clear();
            // Titre presque fini : sa fin tombe pendant (ou juste avant) le chargement du suivant.
            player.Load(Clip(1.2), NoHeaders, TimeSpan.FromSeconds(0.6 + i * 0.1));
            Assert.NotNull(player.Get("playlist/0/id"));
            await Until(() => rec.FirstFrames == 1, $"titre {i} : {rec}");
            while (rec.Position < TimeSpan.FromSeconds(1.15) && !rec.Has("ended:Eof")) await Task.Delay(5);
            player.Load(Clip(8), NoHeaders, TimeSpan.Zero);
            var reloadedAt = rec.Events.Count;
            await Until(() => rec.FirstFrames == 2, $"suivant {i}");
            await Task.Delay(300);
            // Après le rechargement, aucune « fin » ne doit arriver (elle fermerait le lecteur
            // ou sauterait un épisode).
            var after = rec.Events.Skip(reloadedAt).ToList();
            Assert.DoesNotContain("ended:Eof", after);
        }
        DestroyWindow(hwnd);
    }

    [Fact]
    public async Task Flux_invalide_signale_une_erreur()
    {
        var hwnd = Window();
        using var player = MpvPlayer.Create(hwnd);
        var rec = new Recorder(player);
        // Graphe lavfi invalide : mpv échoue à l'ouverture ; l'appli doit le savoir (sinon « Préparation » à vie).
        player.Load("av://lavfi:testsrc2=duration=1,2", NoHeaders, TimeSpan.Zero);
        await Until(() => rec.Events.Any(e => e.StartsWith("ended:")), $"fin signalée : {rec}");
        Assert.Contains("ended:Error", rec.Events);
        DestroyWindow(hwnd);
    }

    [Fact]
    public async Task Echec_puis_repli_dans_le_meme_lecteur()
    {
        var hwnd = Window();
        using var player = MpvPlayer.Create(hwnd);
        var rec = new Recorder(player);
        player.Load(new Uri("http://127.0.0.1:9/introuvable.mkv"), NoHeaders, TimeSpan.Zero);
        await Until(() => rec.Has("ended:Error"), "échec de la lecture directe");
        Assert.Equal(0, rec.FirstFrames);
        rec.Clear();
        player.Load(Clip(4), NoHeaders, TimeSpan.FromSeconds(1));
        await Until(() => rec.FirstFrames == 1, "repli");
        await Until(() => rec.Position > TimeSpan.FromSeconds(1.2), "lecture du repli");
        Assert.DoesNotContain("ended:Error", rec.Events);
        DestroyWindow(hwnd);
    }

    [Fact]
    public async Task Rechargements_rapides_le_dernier_gagne()
    {
        var hwnd = Window();
        using var player = MpvPlayer.Create(hwnd);
        var rec = new Recorder(player);
        // Clics répétés (« épisode suivant » plusieurs fois) : seul le dernier titre doit jouer.
        for (var i = 0; i < 5; i++) player.Load(Clip(20 + i), NoHeaders, TimeSpan.Zero);
        await Until(() => rec.FirstFrames >= 1 && rec.Position > TimeSpan.FromSeconds(0.5), "dernier titre");
        await Task.Delay(500);
        Assert.Equal(1, rec.FirstFrames);
        Assert.DoesNotContain("ended:Error", rec.Events);
        Assert.Equal(24, player.GetDouble("duration") is { } d ? (int)Math.Round(d) : -1);
        DestroyWindow(hwnd);
    }

    [Fact]
    public async Task Debut_ou_saut_au_dela_de_la_fin()
    {
        var hwnd = Window();
        using var player = MpvPlayer.Create(hwnd);
        var rec = new Recorder(player);
        // Reprise enregistrée plus loin que la durée réelle : la lecture se termine, sans blocage.
        player.Load(Clip(3), NoHeaders, TimeSpan.FromSeconds(60));
        await Until(() => rec.Events.Any(e => e.StartsWith("ended:")), "fin immédiate");
        rec.Clear();
        player.Load(Clip(5), NoHeaders, TimeSpan.Zero);
        await Until(() => rec.FirstFrames == 1, "lecture");
        player.Seek(TimeSpan.FromSeconds(500));
        await Until(() => rec.Has("ended:Eof"), "fin après saut");
        DestroyWindow(hwnd);
    }

    [Fact]
    public async Task Fermeture_en_pleine_lecture_repetee()
    {
        for (var i = 0; i < 8; i++)
        {
            var hwnd = Window();
            var player = MpvPlayer.Create(hwnd);
            var rec = new Recorder(player);
            player.Load(Clip(30), NoHeaders, TimeSpan.Zero);
            await Until(() => rec.FirstFrames == 1, $"lecture {i}");
            // Commandes de l'interface pendant la libération (minuteries, rapports) : sans effet, sans plantage.
            var ui = Task.Run(() =>
            {
                for (var k = 0; k < 2000; k++)
                {
                    player.TrySet("pause", k % 2 == 0 ? "yes" : "no");
                    _ = player.GetDouble("time-pos");
                    _ = player.Get("hwdec-current");
                }
            });
            var watch = Stopwatch.StartNew();
            await Task.Run(player.Dispose);
            Assert.True(watch.Elapsed < TimeSpan.FromSeconds(5), $"libération : {watch.Elapsed}");
            await ui;
            Assert.Null(player.GetDouble("time-pos"));
            DestroyWindow(hwnd);
        }
    }

    // ------------------------------------------------------------ Flux HTTP (comme Jellyfin)

    /// <summary>Petit serveur de fichier : requêtes partielles (Range) et en-tête Authorization exigé.</summary>
    private sealed class FileServer : IDisposable
    {
        private readonly HttpListener _listener = new();
        private readonly byte[] _file;
        public readonly ConcurrentQueue<string> Requests = new();
        public string Url { get; }

        public FileServer(byte[] file)
        {
            _file = file;
            var port = 18_000 + Random.Shared.Next(2000);
            Url = $"http://127.0.0.1:{port}/";
            _listener.Prefixes.Add(Url);
            _listener.Start();
            _ = Task.Run(LoopAsync);
        }

        private async Task LoopAsync()
        {
            while (_listener.IsListening)
            {
                HttpListenerContext c;
                try { c = await _listener.GetContextAsync(); }
                catch { return; }
                _ = Task.Run(() => Serve(c));
            }
        }

        private void Serve(HttpListenerContext c)
        {
            try
            {
                var range = c.Request.Headers["Range"];
                Requests.Enqueue($"{c.Request.Headers["Authorization"]}|{range}");
                if (c.Request.Headers["Authorization"] != "MediaBrowser Token=\"secret\"")
                {
                    c.Response.StatusCode = 401;
                    c.Response.Close();
                    return;
                }
                long from = 0, to = _file.Length - 1;
                if (range != null && range.StartsWith("bytes="))
                {
                    var parts = range[6..].Split('-');
                    from = long.Parse(parts[0]);
                    if (parts[1].Length > 0) to = Math.Min(to, long.Parse(parts[1]));
                    c.Response.StatusCode = 206;
                    c.Response.AddHeader("Content-Range", $"bytes {from}-{to}/{_file.Length}");
                }
                c.Response.AddHeader("Accept-Ranges", "bytes");
                c.Response.ContentType = "video/x-matroska";
                c.Response.ContentLength64 = to - from + 1;
                c.Response.OutputStream.Write(_file, (int)from, (int)(to - from + 1));
                c.Response.Close();
            }
            catch
            {
                // Lecteur qui coupe la connexion (saut) : normal.
            }
        }

        public void Dispose() => _listener.Close();
    }

    /// <summary>MKV de test : H.264, deux pistes audio (fre, eng), un sous-titre SRT (ffmpeg requis).</summary>
    private static byte[]? TestFilm()
    {
        var dir = Path.Combine(Path.GetTempPath(), "optifin-tests");
        var file = Path.Combine(dir, "film.mkv");
        if (File.Exists(file)) return File.ReadAllBytes(file);
        Directory.CreateDirectory(dir);
        var srt = Path.Combine(dir, "fr.srt");
        File.WriteAllText(srt, "1\n00:00:00,500 --> 00:00:03,000\nBonjour\n\n2\n00:00:04,000 --> 00:00:08,000\nSecond\n");
        try
        {
            var p = Process.Start(new ProcessStartInfo("ffmpeg",
                $"-v error -y -f lavfi -i testsrc2=size=640x360:rate=24:duration=12 -f lavfi -i sine=frequency=440:duration=12 " +
                $"-f lavfi -i sine=frequency=880:duration=12 -i \"{srt}\" -map 0 -map 1 -map 2 -map 3 -c:v libx264 -preset ultrafast -g 24 " +
                $"-c:a aac -c:s srt -metadata:s:a:0 language=fre -metadata:s:a:1 language=eng -metadata:s:s:0 language=fre \"{file}\"")
            { UseShellExecute = false, CreateNoWindow = true });
            if (p is null || !p.WaitForExit(60_000) || p.ExitCode != 0) return null;
        }
        catch (System.ComponentModel.Win32Exception)
        {
            return null;
        }
        return File.ReadAllBytes(file);
    }

    [Fact]
    public async Task Flux_http_authentifie_pistes_et_sauts()
    {
        var film = TestFilm();
        if (film is null) Assert.Skip("ffmpeg introuvable : pas de fichier de test.");
        using var server = new FileServer(film);
        var hwnd = Window();
        using var player = MpvPlayer.Create(hwnd);
        var rec = new Recorder(player);
        var headers = new Dictionary<string, string> { ["Authorization"] = "MediaBrowser Token=\"secret\"" };
        player.Load(new Uri(server.Url + "Videos/abc/stream?static=true"), headers, TimeSpan.FromSeconds(3));
        await Until(() => rec.FirstFrames == 1, "ouverture du flux");
        Assert.All(server.Requests, r => Assert.StartsWith("MediaBrowser Token=\"secret\"|", r));
        await Until(() => rec.Position >= TimeSpan.FromSeconds(3), "reprise à 3 s");

        var tracks = player.Tracks();
        Assert.Equal(2, tracks.Count(t => t.Type == "audio"));
        Assert.Equal(1, tracks.Count(t => t.Type == "sub"));
        player.SelectAudio(2);
        player.SelectSubtitle(1);
        await Until(() => player.Get("aid") == "2" && player.Get("sid") == "1", "pistes choisies");
        player.SelectSubtitle(null);
        await Until(() => player.Get("sid") == "no", "sous-titres coupés");

        // Sauts en avant et en arrière, dont plusieurs à la suite (clics répétés sur la barre).
        foreach (var s in new[] { 9.0, 1.0, 6.0, 7.0, 8.0, 2.0 }) player.Seek(TimeSpan.FromSeconds(s));
        await Until(() => Math.Abs(rec.Position.TotalSeconds - 2) < 0.6, "dernier saut appliqué");
        player.Seek(TimeSpan.FromSeconds(10));
        await Until(() => rec.Has("ended:Eof"), "fin du flux");
        Assert.DoesNotContain("ended:Error", rec.Events);

        // Même flux sans jeton : erreur signalée (et non une fin normale).
        rec.Clear();
        player.Load(new Uri(server.Url + "Videos/abc/stream"), NoHeaders, TimeSpan.Zero);
        await Until(() => rec.Events.Any(e => e.StartsWith("ended:")), "refus du serveur");
        Assert.Contains("ended:Error", rec.Events);
        DestroyWindow(hwnd);
    }
}
