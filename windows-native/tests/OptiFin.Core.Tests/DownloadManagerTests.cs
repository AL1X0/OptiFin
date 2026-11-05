using System.Net;
using OptiFin.Core.Api;
using OptiFin.Core.Downloads;
using OptiFin.Core.Media;
using OptiFin.Core.Playback;

namespace OptiFin.Core.Tests;

/// <summary>Téléchargements hors ligne sur un petit serveur local : reprise, persistance, erreurs, suppression.</summary>
public sealed class DownloadManagerTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "optifin-dl-" + Guid.NewGuid().ToString("N"));
    private static readonly byte[] File8Mb = [.. Enumerable.Range(0, 8 << 20).Select(i => (byte)(i * 31))];

    public void Dispose()
    {
        if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true);
    }

    private static BaseItemDto Dto(string id = "movie") => new() { Id = id, Name = "Horizon", Type = "Movie" };

    private static JellyfinClient Client(Server server) =>
        new(new Uri(server.Url), new ClientIdentity("OptiFin", "Tests", "t", "1.0"), () => "secret");

    private sealed class Server : IDisposable
    {
        private readonly HttpListener _listener = new();
        private readonly byte[] _file;
        public string Url { get; }
        public List<string?> Ranges { get; } = [];
        public int Status { get; set; } = 200;
        /// <summary>Attente entre deux blocs, pour avoir le temps de mettre en pause.</summary>
        public int Delay { get; set; }

        public Server(byte[] file)
        {
            _file = file;
            var port = 21_000 + Random.Shared.Next(2000);
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
                try
                {
                    c = await _listener.GetContextAsync();
                }
                catch
                {
                    return;
                }
                _ = Task.Run(() => ServeAsync(c));
            }
        }

        private async Task ServeAsync(HttpListenerContext c)
        {
            try
            {
                var range = c.Request.Headers["Range"];
                lock (Ranges) Ranges.Add(range);
                c.Response.StatusCode = Status;
                if (Status != 200)
                {
                    c.Response.Close();
                    return;
                }
                long from = 0;
                if (range != null)
                {
                    from = long.Parse(range[6..].TrimEnd('-'));
                    c.Response.StatusCode = 206;
                    c.Response.AddHeader("Content-Range", $"bytes {from}-{_file.Length - 1}/{_file.Length}");
                }
                c.Response.ContentLength64 = _file.Length - from;
                for (var at = from; at < _file.Length; at += 1 << 20)
                {
                    await c.Response.OutputStream.WriteAsync(_file.AsMemory((int)at, (int)Math.Min(1 << 20, _file.Length - at)));
                    if (Delay > 0) await Task.Delay(Delay);
                }
                c.Response.Close();
            }
            catch
            {
                // Client parti (pause).
            }
        }

        public void Dispose() => _listener.Abort();
    }

    private static async Task Until(Func<bool> ok, string what)
    {
        var deadline = DateTime.UtcNow.AddSeconds(30);
        while (!ok())
        {
            if (DateTime.UtcNow > deadline) Assert.Fail($"Délai dépassé : {what}");
            await Task.Delay(20);
        }
    }

    [Fact]
    public async Task Telecharge_le_fichier_complet()
    {
        using var server = new Server(File8Mb);
        var manager = new DownloadManager(_dir);
        manager.Attach(Client(server), "compte");
        manager.Enqueue(Dto());
        await Until(() => manager.Find("movie")?.Status == DownloadStatus.Complete, "fin du téléchargement");
        var path = manager.CompletedFile("movie");
        Assert.NotNull(path);
        Assert.Equal(File8Mb, await File.ReadAllBytesAsync(path));
        Assert.False(File.Exists(path + ".part"));
        Assert.Equal("Horizon", DownloadManager.ItemOf(manager.Find("movie")!).Name);
    }

    [Fact]
    public async Task Pause_puis_reprise_sans_tout_retelecharger()
    {
        using var server = new Server(File8Mb) { Delay = 150 };
        var manager = new DownloadManager(_dir);
        manager.Attach(Client(server), "compte");
        manager.Enqueue(Dto());
        await Until(() => manager.Find("movie")?.DoneBytes >= 2 << 20, "début du téléchargement");
        manager.Pause("movie");
        await manager.IdleAsync();
        Assert.Equal(DownloadStatus.Paused, manager.Find("movie")!.Status);
        var offset = new FileInfo(manager.PathOf(manager.Find("movie")!) + ".part").Length;
        Assert.True(offset > 0);
        server.Delay = 0;
        manager.Resume("movie");
        await Until(() => manager.Find("movie")?.Status == DownloadStatus.Complete, "reprise");
        Assert.Contains($"bytes={offset}-", server.Ranges);
        Assert.Equal(File8Mb, await File.ReadAllBytesAsync(manager.CompletedFile("movie")!));
    }

    [Fact]
    public async Task Fermeture_de_l_appli_puis_reprise_au_lancement_suivant()
    {
        using var server = new Server(File8Mb) { Delay = 150 };
        var first = new DownloadManager(_dir);
        first.Attach(Client(server), "compte");
        first.Enqueue(Dto());
        await Until(() => first.Find("movie")?.DoneBytes >= 1 << 20, "début");
        first.Attach(null, null);
        await first.IdleAsync();
        server.Delay = 0;
        var second = new DownloadManager(_dir);
        second.Attach(Client(server), "compte");
        await Until(() => second.Find("movie")?.Status == DownloadStatus.Complete, "reprise au lancement");
        Assert.Equal(File8Mb, await File.ReadAllBytesAsync(second.CompletedFile("movie")!));
    }

    [Fact]
    public async Task Refus_du_serveur_signale_et_reessayable()
    {
        using var server = new Server(File8Mb) { Status = 403 };
        var manager = new DownloadManager(_dir);
        manager.Attach(Client(server), "compte");
        manager.Enqueue(Dto());
        await Until(() => manager.Find("movie")?.Status == DownloadStatus.Failed, "échec");
        Assert.False(string.IsNullOrEmpty(manager.Find("movie")!.Error));
        Assert.Null(manager.CompletedFile("movie"));
        server.Status = 200;
        manager.Resume("movie");
        await Until(() => manager.Find("movie")?.Status == DownloadStatus.Complete, "nouvel essai");
    }

    [Fact]
    public async Task Suppression_efface_les_fichiers_meme_en_cours()
    {
        using var server = new Server(File8Mb) { Delay = 150 };
        var manager = new DownloadManager(_dir);
        manager.Attach(Client(server), "compte");
        manager.Enqueue(Dto());
        await Until(() => manager.Find("movie")?.DoneBytes >= 1 << 20, "début");
        await manager.DeleteAsync("movie");
        Assert.Null(manager.Find("movie"));
        Assert.Empty(Directory.GetFiles(_dir, "movie*"));
    }

    [Fact]
    public async Task Un_compte_ne_voit_pas_les_telechargements_d_un_autre()
    {
        using var server = new Server(File8Mb);
        var manager = new DownloadManager(_dir);
        manager.Attach(Client(server), "alice");
        manager.Enqueue(Dto());
        await Until(() => manager.Find("movie")?.Status == DownloadStatus.Complete, "fin");
        manager.Attach(Client(server), "bob");
        Assert.Empty(manager.Records());
        Assert.Null(manager.CompletedFile("movie"));
    }

    /// <summary>Serveur minimal de synchronisation : fiche avec date de dernière lecture, rapports reçus.</summary>
    private sealed class SyncServer : IDisposable
    {
        private readonly HttpListener _listener = new();
        public string Url { get; }
        public string? LastPlayed { get; set; }
        public bool Offline { get; set; }
        public List<string> Reports { get; } = [];

        public SyncServer()
        {
            var port = 23_000 + Random.Shared.Next(2000);
            Url = $"http://127.0.0.1:{port}/";
            _listener.Prefixes.Add(Url);
            _listener.Start();
            _ = Task.Run(async () =>
            {
                while (_listener.IsListening)
                {
                    try
                    {
                        var c = await _listener.GetContextAsync();
                        if (Offline)
                        {
                            c.Response.Abort();
                            continue;
                        }
                        if (c.Request.HttpMethod == "POST")
                        {
                            using var reader = new StreamReader(c.Request.InputStream);
                            var text = await reader.ReadToEndAsync();
                            lock (Reports) Reports.Add(c.Request.Url!.AbsolutePath + " " + text);
                            c.Response.StatusCode = 204;
                        }
                        else
                        {
                            var data = LastPlayed is null ? "{}" : $$"""{"LastPlayedDate":"{{LastPlayed}}","PlaybackPositionTicks":777}""";
                            var body = System.Text.Encoding.UTF8.GetBytes($$"""{"Items":[{"Id":"movie","Name":"Horizon","Type":"Movie","UserData":{{data}}}]}""");
                            c.Response.ContentType = "application/json";
                            await c.Response.OutputStream.WriteAsync(body);
                        }
                        c.Response.Close();
                    }
                    catch
                    {
                        return;
                    }
                }
            });
        }

        public void Dispose() => _listener.Abort();
    }

    private static async Task<DownloadManager> WithFinishedDownload(string dir)
    {
        using var files = new Server(File8Mb);
        var manager = new DownloadManager(dir);
        manager.Attach(Client(files), "compte");
        manager.Enqueue(Dto());
        await Until(() => manager.Find("movie")?.Status == DownloadStatus.Complete, "fin");
        await manager.IdleAsync();
        return manager;
    }

    private static JellyfinClient Client(SyncServer server) =>
        new(new Uri(server.Url), new ClientIdentity("OptiFin", "Tests", "t", "1.0"), () => "secret");

    [Fact]
    public async Task Position_hors_ligne_gardee_puis_envoyee_au_retour_du_serveur()
    {
        var manager = await WithFinishedDownload(_dir);
        using var server = new SyncServer { Offline = true };
        manager.Attach(Client(server), "compte", "user");
        manager.SavePosition("movie", TimeSpan.FromMinutes(12));
        await manager.SyncPositionsAsync();
        Assert.True(manager.Find("movie")!.PositionUnsent);
        // La reprise fonctionne sans serveur, même après un redémarrage de l'appli.
        var reopened = new DownloadManager(_dir);
        reopened.Attach(null, "compte");
        Assert.Equal(TimeSpan.FromMinutes(12), DownloadManager.ItemOf(reopened.Find("movie")!).ResumePosition);

        server.Offline = false;
        await manager.SyncPositionsAsync();
        Assert.False(manager.Find("movie")!.PositionUnsent);
        var report = Assert.Single(server.Reports);
        Assert.Contains("/Sessions/Playing/Stopped", report);
        Assert.Contains(TimeSpan.FromMinutes(12).Ticks.ToString(), report);
    }

    [Fact]
    public async Task Lecture_plus_recente_sur_un_autre_appareil_non_ecrasee()
    {
        var manager = await WithFinishedDownload(_dir);
        using var server = new SyncServer { LastPlayed = DateTimeOffset.UtcNow.AddHours(1).ToString("O") };
        manager.Attach(Client(server), "compte", "user");
        manager.SavePosition("movie", TimeSpan.FromMinutes(12));
        await manager.SyncPositionsAsync();
        Assert.Empty(server.Reports);
        Assert.False(manager.Find("movie")!.PositionUnsent);
        Assert.Equal(777, manager.Find("movie")!.LocalPositionTicks);
    }

    [Fact]
    public async Task Pres_de_la_fin_le_titre_repart_du_debut()
    {
        using var files = new Server(File8Mb);
        var manager = new DownloadManager(_dir);
        manager.Attach(Client(files), "compte");
        manager.Enqueue(new BaseItemDto { Id = "movie", Name = "Horizon", Type = "Movie", RunTimeTicks = TimeSpan.FromMinutes(100).Ticks });
        await Until(() => manager.Find("movie")?.Status == DownloadStatus.Complete, "fin");
        manager.SavePosition("movie", TimeSpan.FromMinutes(95));
        var item = DownloadManager.ItemOf(manager.Find("movie")!);
        Assert.Equal(TimeSpan.Zero, item.ResumePosition);
        Assert.True(item.User.Played);
    }

    [Fact]
    public async Task Episode_suivant_trouve_parmi_les_telechargements()
    {
        using var server = new Server(File8Mb);
        var manager = new DownloadManager(_dir);
        manager.Attach(Client(server), "compte");
        BaseItemDto Episode(string id, int season, int number) => new() { Id = id, Name = id, Type = "Episode", SeriesId = "s", ParentIndexNumber = season, IndexNumber = number };
        manager.Enqueue(Episode("e3", 1, 3));
        manager.Enqueue(Episode("e1", 1, 1));
        manager.Enqueue(Episode("s2e1", 2, 1));
        await Until(() => manager.Records().All(r => r.Status == DownloadStatus.Complete), "fin");
        var first = DownloadManager.ItemOf(manager.Find("e1")!);
        Assert.Equal("e3", manager.NextDownloaded(first)?.Id);
        Assert.Equal("s2e1", manager.NextDownloaded(DownloadManager.ItemOf(manager.Find("e3")!))?.Id);
        Assert.Null(manager.NextDownloaded(DownloadManager.ItemOf(manager.Find("s2e1")!)));
    }

    [Fact]
    public void Plan_de_lecture_local()
    {
        var item = MediaMapper.FromDto(Dto());
        var plan = PlaybackService.LocalPlan(item, Path.Combine(_dir, "movie.mkv"), TimeSpan.FromSeconds(30));
        Assert.Equal(PlayMethod.DirectPlay, plan.Method);
        Assert.True(plan.StreamUrl.IsFile);
        Assert.Equal(TimeSpan.FromSeconds(30), plan.Start);
    }
}
