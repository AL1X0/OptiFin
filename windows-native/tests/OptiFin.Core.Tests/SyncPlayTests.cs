using System.Text.Json;
using OptiFin.Core.Api;
using OptiFin.Core.Auth;
using OptiFin.Core.SyncPlay;

namespace OptiFin.Core.Tests;

public class SyncPlayParserTests
{
    // Messages relevés sur un serveur Jellyfin 12.1.
    private const string Joined = """{"MessageType":"SyncPlayGroupUpdate","Data":{"GroupId":"8bfb2a82f2a14827b741aad7ae67f225","Data":{"GroupId":"8bfb2a82f2a14827b741aad7ae67f225","GroupName":"Soirée test","State":"Idle","Participants":["alice","bob"],"LastUpdatedAt":"2026-10-01T13:48:59.7626513Z"},"Type":"GroupJoined"}}""";
    private const string Queue = """{"MessageType":"SyncPlayGroupUpdate","Data":{"GroupId":"8bfb","Data":{"Reason":"NewPlaylist","LastUpdate":"2026-10-01T13:49:00.3458894Z","Playlist":[{"ItemId":"63fc28e75a8a987bd11b9f9a9d8f6fdc","PlaylistItemId":"14530b401ba04b639c6b43c22cbdc25f"}],"PlayingItemIndex":0,"StartPositionTicks":600000000,"IsPlaying":false,"ShuffleMode":"Sorted","RepeatMode":"RepeatNone"},"Type":"PlayQueue"}}""";
    private const string Unpause = """{"MessageType":"SyncPlayCommand","Data":{"GroupId":"8bfb","PlaylistItemId":"14530b401ba04b639c6b43c22cbdc25f","When":"2026-10-01T13:49:03.4843524Z","PositionTicks":5478753,"Command":"Unpause","EmittedAt":"2026-10-01T13:49:02.4844414Z"}}""";

    [Fact]
    public void GroupeRejoint()
    {
        var m = Assert.IsType<GroupJoinedMessage>(SyncPlayParser.Parse(Joined));
        Assert.Equal("Soirée test", m.Group.Name);
        Assert.Equal(["alice", "bob"], m.Group.Participants);
        Assert.Equal(GroupState.Idle, m.Group.State);
    }

    [Fact]
    public void FileDeLecture()
    {
        var q = Assert.IsType<QueueMessage>(SyncPlayParser.Parse(Queue)).Queue;
        Assert.Equal("NewPlaylist", q.Reason);
        Assert.Equal("63fc28e75a8a987bd11b9f9a9d8f6fdc", q.Current!.ItemId);
        Assert.Equal(TimeSpan.FromMinutes(1), q.Start);
        Assert.False(q.IsPlaying);
    }

    [Fact]
    public void OrdreHorodate()
    {
        var c = Assert.IsType<CommandMessage>(SyncPlayParser.Parse(Unpause)).Command;
        Assert.Equal(SyncCommandKind.Unpause, c.Kind);
        Assert.Equal(DateTimeKind.Utc, c.When.Kind);
        Assert.Equal(new DateTime(2026, 10, 1, 13, 49, 3, DateTimeKind.Utc), c.When.AddTicks(-c.When.Ticks % TimeSpan.TicksPerSecond));
        Assert.Equal(TimeSpan.FromTicks(5478753), c.Position);
    }

    [Fact]
    public void AutresMessages()
    {
        Assert.IsType<KeepAliveRequest>(SyncPlayParser.Parse("""{"MessageType":"ForceKeepAlive","Data":60}"""));
        Assert.Equal("bob", Assert.IsType<UserLeftMessage>(SyncPlayParser.Parse("""{"MessageType":"SyncPlayGroupUpdate","Data":{"GroupId":"g","Data":"bob","Type":"UserLeft"}}""")).UserName);
        var s = Assert.IsType<StateMessage>(SyncPlayParser.Parse("""{"MessageType":"SyncPlayGroupUpdate","Data":{"GroupId":"g","Data":{"State":"Waiting","Reason":"Seek"},"Type":"StateUpdate"}}"""));
        Assert.Equal(GroupState.Waiting, s.State);
        Assert.IsType<ErrorMessage>(SyncPlayParser.Parse("""{"MessageType":"SyncPlayGroupUpdate","Data":{"GroupId":"g","Data":"","Type":"LibraryAccessDenied"}}"""));
        Assert.Null(SyncPlayParser.Parse("""{"MessageType":"Sessions","Data":[]}"""));
        Assert.Null(SyncPlayParser.Parse("pas du json"));
    }
}

public class TimeSyncTests
{
    [Fact]
    public void DecalageEtAllerRetour()
    {
        var local = new DateTime(2026, 1, 1, 12, 0, 0, DateTimeKind.Utc);
        var sync = new TimeSync(() => local);
        // Serveur en avance de 5 s, 40 ms de trajet aller et retour.
        sync.AddSample(local, local.AddSeconds(5).AddMilliseconds(20), local.AddSeconds(5).AddMilliseconds(21), local.AddMilliseconds(41));
        Assert.Equal(5000, sync.Offset.TotalMilliseconds, 1);
        Assert.Equal(40, sync.RoundTrip.TotalMilliseconds, 1);
        Assert.Equal(local.AddSeconds(5), sync.ServerNow);
        Assert.Equal(local, sync.ToLocal(local.AddSeconds(5)));
        // Un échantillon plus lent (et faussé) ne remplace pas le meilleur.
        sync.AddSample(local, local.AddSeconds(5).AddMilliseconds(400), local.AddSeconds(5).AddMilliseconds(401), local.AddMilliseconds(500));
        Assert.Equal(5000, sync.Offset.TotalMilliseconds, 1);
    }
}

public class SyncPlayPlaybackTests
{
    private sealed class FakePlayer : ISyncTarget
    {
        public TimeSpan Position { get; set; }
        public bool Paused { get; set; } = true;
        public double Speed { get; set; } = 1;
        public int Seeks;
        public void Play() => Paused = false;
        public void Pause() => Paused = true;
        public void Seek(TimeSpan position)
        {
            Position = position;
            Seeks++;
        }
        public void SetSpeed(double speed) => Speed = speed;
    }

    private sealed class FakeRequests : ISyncRequests
    {
        public readonly List<string> Sent = [];
        public Task ReadyAsync(TimeSpan position, bool isPlaying, string id) { Sent.Add(FormattableString.Invariant($"ready {position.TotalSeconds:0.0} {isPlaying}")); return Task.CompletedTask; }
        public Task BufferingAsync(TimeSpan position, bool isPlaying, string id) { Sent.Add($"buffering {isPlaying}"); return Task.CompletedTask; }
        public Task PauseAsync() { Sent.Add("pause"); return Task.CompletedTask; }
        public Task UnpauseAsync() { Sent.Add("unpause"); return Task.CompletedTask; }
        public Task SeekAsync(TimeSpan position) { Sent.Add($"seek {position.TotalSeconds:0}"); return Task.CompletedTask; }
    }

    private static readonly DateTime T0 = new(2026, 1, 1, 20, 0, 0, DateTimeKind.Utc);

    private static (SyncPlayPlayback Sync, FakePlayer Player, FakeRequests Requests, Func<DateTime, DateTime> SetNow) Make()
    {
        var now = T0;
        var time = new TimeSync(() => now);
        // Serveur en avance de 2 s sur l'horloge locale.
        time.AddSample(T0, T0.AddSeconds(2), T0.AddSeconds(2), T0);
        var player = new FakePlayer();
        var requests = new FakeRequests();
        return (new SyncPlayPlayback(player, requests, time, "pl1"), player, requests, t => now = t);
    }

    private static SyncCommand Cmd(SyncCommandKind kind, DateTime serverWhen, double seconds, string id = "pl1") =>
        new(kind, id, serverWhen, TimeSpan.FromSeconds(seconds), serverWhen);

    [Fact]
    public void ReprendALHeureDuServeur()
    {
        var (sync, player, _, setNow) = Make();
        // Départ prévu à T0+3 s (serveur) = T0+1 s (local).
        sync.Apply(Cmd(SyncCommandKind.Unpause, T0.AddSeconds(3), 10));
        Assert.True(player.Paused);
        Assert.Equal(10, player.Position.TotalSeconds);
        setNow(T0.AddMilliseconds(900));
        sync.Tick();
        Assert.True(player.Paused);
        setNow(T0.AddSeconds(1));
        sync.Tick();
        Assert.False(player.Paused);
    }

    [Fact]
    public void EnRetardRejointLeGroupe()
    {
        var (sync, player, _, setNow) = Make();
        setNow(T0.AddSeconds(5));
        // Départ à T0+3 s serveur = T0+1 s local : 4 s de retard.
        sync.Apply(Cmd(SyncCommandKind.Unpause, T0.AddSeconds(3), 10));
        Assert.False(player.Paused);
        Assert.Equal(14, player.Position.TotalSeconds, 2);
    }

    [Fact]
    public void RattrapeLaDerive()
    {
        var (sync, player, _, setNow) = Make();
        sync.Apply(Cmd(SyncCommandKind.Unpause, T0.AddSeconds(2), 0)); // départ immédiat
        setNow(T0.AddSeconds(10));
        player.Position = TimeSpan.FromSeconds(10.3); // 300 ms d'avance : on ralentit
        sync.Tick();
        Assert.Equal(0.95, player.Speed);
        player.Position = TimeSpan.FromSeconds(10.01);
        sync.Tick();
        Assert.Equal(1, player.Speed);
        player.Position = TimeSpan.FromSeconds(8); // 2 s de retard : saut direct
        var seeks = player.Seeks;
        sync.Tick();
        Assert.Equal(seeks + 1, player.Seeks);
        Assert.Equal(10, player.Position.TotalSeconds, 2);
    }

    [Fact]
    public void PauseEtSautPuisPret()
    {
        var (sync, player, requests, _) = Make();
        sync.Apply(Cmd(SyncCommandKind.Unpause, T0.AddSeconds(2), 0));
        sync.Apply(Cmd(SyncCommandKind.Pause, T0.AddSeconds(2), 42));
        Assert.True(player.Paused);
        Assert.Equal(42, player.Position.TotalSeconds);
        sync.Apply(Cmd(SyncCommandKind.Seek, T0.AddSeconds(2), 600));
        Assert.Equal(600, player.Position.TotalSeconds);
        Assert.True(sync.Waiting);
        sync.OnSeekCompleted();
        Assert.Equal("ready 600.0 False", requests.Sent[^1]);
    }

    [Fact]
    public void IgnoreUnAutreElementEtTransmetLesActions()
    {
        var (sync, player, requests, _) = Make();
        sync.Apply(Cmd(SyncCommandKind.Unpause, T0.AddSeconds(2), 0, id: "autre"));
        Assert.True(player.Paused);
        _ = sync.RequestTogglePlayAsync();
        _ = sync.RequestSeekAsync(TimeSpan.FromSeconds(90));
        Assert.Equal(["unpause", "seek 90"], requests.Sent);
        sync.OnBuffering(true);
        sync.OnBuffering(false);
        Assert.Equal("buffering False", requests.Sent[^2]);
    }
}

/// <summary>
/// Bout en bout contre un vrai serveur Jellyfin (facultatif) : variable d'environnement
/// OPTIFIN_TEST_SERVER = fichier JSON {"url", "users":[{"name","password"},…]} (deux comptes).
/// </summary>
public class SyncPlayServerTests
{
    private sealed record Account(string Name, string Password);

    private static async Task<(JellyfinClient Api, string UserId)> SignInAsync(string url, Account account, string device)
    {
        var identity = new ClientIdentity("OptiFinTests", device, $"tests-{device}", "1.0");
        var auth = new AuthService(identity);
        var server = await auth.ProbeAsync(url);
        var session = await auth.LoginAsync(server, account.Name, account.Password);
        return (new JellyfinClient(server.BaseUrl, identity, () => session.Token), session.Account.UserId);
    }

    [Fact]
    public async Task SoireeADeux()
    {
        var file = Environment.GetEnvironmentVariable("OPTIFIN_TEST_SERVER");
        Assert.SkipUnless(file != null && File.Exists(file), "Pas de serveur Jellyfin de test (OPTIFIN_TEST_SERVER).");
        using var doc = JsonDocument.Parse(await File.ReadAllTextAsync(file!, TestContext.Current.CancellationToken));
        var url = doc.RootElement.GetProperty("url").GetString()!;
        var accounts = doc.RootElement.GetProperty("users").EnumerateArray()
            .Select(u => new Account(u.GetProperty("name").GetString()!, u.GetProperty("password").GetString()!)).ToList();

        var (aliceApi, aliceId) = await SignInAsync(url, accounts[0], "alice");
        var (bobApi, _) = await SignInAsync(url, accounts[1], "bob");
        await using var alice = new SyncPlayClient(aliceApi);
        await using var bob = new SyncPlayClient(bobApi);
        var aliceMessages = new List<SyncPlayMessage>();
        var bobMessages = new List<SyncPlayMessage>();
        alice.MessageReceived += m => { lock (aliceMessages) aliceMessages.Add(m); };
        bob.MessageReceived += m => { lock (bobMessages) bobMessages.Add(m); };
        alice.Start();
        bob.Start();
        await WaitAsync(() => alice.Connected && bob.Connected);
        await alice.SyncTimeAsync();
        Assert.True(alice.Time.HasSamples);

        await alice.CreateAsync("Soirée des tests");
        await WaitAsync(() => alice.Group != null);
        var group = (await bob.ListAsync()).First(g => g.Id == alice.Group!.Id);
        await bob.JoinAsync(group.Id);
        await WaitAsync(() => bob.Group != null && alice.Group!.Participants.Count == 2);

        var media = new Media.MediaRepository(aliceApi, aliceId);
        var movie = (await media.SearchAsync("Test")).Movies.FirstOrDefault()
            ?? throw new InvalidOperationException("Le serveur de test doit contenir un film « Test… ».");
        await alice.SetQueueAsync([movie.Id], 0, TimeSpan.FromSeconds(30));
        await WaitAsync(() => Has<QueueMessage>(bobMessages));
        var queue = Last<QueueMessage>(bobMessages).Queue;
        Assert.Equal(movie.Id, queue.Current!.ItemId);
        Assert.Equal(TimeSpan.FromSeconds(30), queue.Start);

        await bob.UnpauseAsync();
        await WaitAsync(() => Has<CommandMessage>(aliceMessages, c => c.Command.Kind == SyncCommandKind.Unpause));
        await alice.SeekAsync(TimeSpan.FromMinutes(1));
        await WaitAsync(() => Has<CommandMessage>(bobMessages, c => c.Command.Kind == SyncCommandKind.Seek));
        Assert.Equal(TimeSpan.FromMinutes(1), Last<CommandMessage>(bobMessages).Command.Position);

        await bob.LeaveAsync();
        await WaitAsync(() => alice.Group!.Participants.Count == 1);
        await alice.LeaveAsync();
    }

    private static bool Has<T>(List<SyncPlayMessage> list, Func<T, bool>? where = null) where T : SyncPlayMessage
    {
        lock (list) return list.OfType<T>().Any(m => where?.Invoke(m) ?? true);
    }

    private static T Last<T>(List<SyncPlayMessage> list) where T : SyncPlayMessage
    {
        lock (list) return list.OfType<T>().Last();
    }

    private static async Task WaitAsync(Func<bool> condition)
    {
        for (var i = 0; i < 100 && !condition(); i++) await Task.Delay(100);
        Assert.True(condition(), "Délai dépassé");
    }
}
