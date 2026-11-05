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
