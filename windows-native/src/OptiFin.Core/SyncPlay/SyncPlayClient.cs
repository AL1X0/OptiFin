using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using OptiFin.Core.Api;
using OptiFin.Core.Logging;

namespace OptiFin.Core.SyncPlay;

/// <summary>
/// Soirées (SyncPlay de Jellyfin) : connexion temps réel au serveur (/socket, jeton dans l'en-tête
/// Authorization, jamais dans l'URL), maintien et reconnexion automatique, horloge du serveur, et
/// requêtes du groupe (créer, rejoindre, quitter, file, lecture/pause/position, prêt, mise en
/// mémoire tampon). Les messages reçus sont relayés par <see cref="MessageReceived"/>.
/// </summary>
public sealed class SyncPlayClient : IAsyncDisposable
{
    private readonly JellyfinClient _api;
    private readonly CancellationTokenSource _cts = new();
    private ClientWebSocket? _socket;
    private Task? _loop;
    private int _keepAliveSeconds = 30;

    public SyncPlayClient(JellyfinClient api, TimeSync? time = null)
    {
        _api = api;
        Time = time ?? new TimeSync();
    }

    public TimeSync Time { get; }

    /// <summary>Soirée rejointe (null hors soirée).</summary>
    public GroupInfo? Group { get; private set; }

    public bool Connected { get; private set; }

    public event Action<SyncPlayMessage>? MessageReceived;
    public event Action<bool>? ConnectionChanged;

    /// <summary>Lance la connexion temps réel (en arrière-plan, avec reconnexion).</summary>
    public void Start() => _loop ??= Task.Run(() => RunAsync(_cts.Token));

    // ------------------------------------------------------------ Requêtes

    public async Task<IReadOnlyList<GroupInfo>> ListAsync(CancellationToken ct = default) =>
        SyncPlayParser.Groups(await _api.GetAsync("SyncPlay/List", JellyfinJson.Default.JsonElement, ct: ct));

    public Task CreateAsync(string name, CancellationToken ct = default) =>
        PostAsync("SyncPlay/New", new JsonObject { ["GroupName"] = name }, ct);

    public Task JoinAsync(string groupId, CancellationToken ct = default) =>
        PostAsync("SyncPlay/Join", new JsonObject { ["GroupId"] = groupId }, ct);

    public async Task LeaveAsync(CancellationToken ct = default)
    {
        await PostAsync("SyncPlay/Leave", null, ct);
        Group = null;
    }

    /// <summary>Nouvelle file partagée : tous les participants ouvrent le titre à cette position.</summary>
    public Task SetQueueAsync(IReadOnlyList<string> itemIds, int index, TimeSpan start, CancellationToken ct = default) =>
        PostAsync("SyncPlay/SetNewQueue", new JsonObject
        {
            ["PlayingQueue"] = new JsonArray([.. itemIds.Select(id => (JsonNode)JsonValue.Create(id))]),
            ["PlayingItemPosition"] = index,
            ["StartPositionTicks"] = start.Ticks,
        }, ct);

    public Task PauseAsync(CancellationToken ct = default) => PostAsync("SyncPlay/Pause", null, ct);
    public Task UnpauseAsync(CancellationToken ct = default) => PostAsync("SyncPlay/Unpause", null, ct);
    public Task StopAsync(CancellationToken ct = default) => PostAsync("SyncPlay/Stop", null, ct);

    public Task SeekAsync(TimeSpan position, CancellationToken ct = default) =>
        PostAsync("SyncPlay/Seek", new JsonObject { ["PositionTicks"] = position.Ticks }, ct);

    public Task NextItemAsync(string playlistItemId, CancellationToken ct = default) =>
        PostAsync("SyncPlay/NextItem", new JsonObject { ["PlaylistItemId"] = playlistItemId }, ct);

    /// <summary>Prêt à lire (titre chargé, position atteinte) : le serveur relance quand tous le sont.</summary>
    public Task ReadyAsync(TimeSpan position, bool isPlaying, string playlistItemId, CancellationToken ct = default) =>
        PostAsync("SyncPlay/Ready", State(position, isPlaying, playlistItemId), ct);

    /// <summary>Lecture interrompue pour remplir la mémoire tampon : le groupe attend.</summary>
    public Task BufferingAsync(TimeSpan position, bool isPlaying, string playlistItemId, CancellationToken ct = default) =>
        PostAsync("SyncPlay/Buffering", State(position, isPlaying, playlistItemId), ct);

    public Task PingAsync(TimeSpan ping, CancellationToken ct = default) =>
        PostAsync("SyncPlay/Ping", new JsonObject { ["Ping"] = (long)ping.TotalMilliseconds }, ct);

    private JsonObject State(TimeSpan position, bool isPlaying, string playlistItemId) => new()
    {
        ["When"] = Time.ServerNow.ToString("o"),
        ["PositionTicks"] = position.Ticks,
        ["IsPlaying"] = isPlaying,
        ["PlaylistItemId"] = playlistItemId,
    };

    private Task PostAsync(string path, JsonObject? body, CancellationToken ct) =>
        _api.PostAsync(path, body is null ? null : JellyfinClient.Json(body), ct: ct);

    /// <summary>Mesure l'horloge du serveur (plusieurs allers-retours, le plus court gagne).</summary>
    public async Task SyncTimeAsync(int samples = 4, CancellationToken ct = default)
    {
        for (var i = 0; i < samples; i++)
        {
            var t0 = Time.LocalNow;
            var r = await _api.GetAsync("GetUtcTime", JellyfinJson.Default.JsonElement, ct: ct);
            var t3 = Time.LocalNow;
            var t1 = r.GetProperty("RequestReceptionTime").GetDateTime().ToUniversalTime();
            var t2 = r.GetProperty("ResponseTransmissionTime").GetDateTime().ToUniversalTime();
            Time.AddSample(t0, t1, t2, t3);
            if (i + 1 < samples) await Task.Delay(150, ct);
        }
    }

    // ------------------------------------------------------------ Connexion temps réel

    private async Task RunAsync(CancellationToken ct)
    {
        var backoff = TimeSpan.FromSeconds(2);
        while (!ct.IsCancellationRequested)
        {
            try
            {
                using var socket = new ClientWebSocket();
                socket.Options.SetRequestHeader("Authorization", _api.AuthorizationHeader);
                socket.Options.KeepAliveInterval = TimeSpan.FromSeconds(20);
                var http = _api.Resolve("socket");
                var url = new UriBuilder(http) { Scheme = http.Scheme == Uri.UriSchemeHttps ? "wss" : "ws" }.Uri;
                await socket.ConnectAsync(url, ct);
                _socket = socket;
                SetConnected(true);
                backoff = TimeSpan.FromSeconds(2);
                AppLog.Info("syncplay", "Connexion temps réel établie");
                _ = SyncTimeAsync(4, ct).ContinueWith(t => AppLog.Debug("syncplay", $"Horloge : décalage {Time.Offset.TotalMilliseconds:0} ms, aller-retour {Time.RoundTrip.TotalMilliseconds:0} ms"),
                    ct, TaskContinuationOptions.OnlyOnRanToCompletion, TaskScheduler.Default);
                using var keepAlive = new CancellationTokenSource();
                _ = KeepAliveAsync(socket, CancellationTokenSource.CreateLinkedTokenSource(ct, keepAlive.Token).Token);
                await ReceiveAsync(socket, ct);
                keepAlive.Cancel();
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested)
            {
                break;
            }
            catch (Exception e)
            {
                AppLog.Debug("syncplay", $"Connexion temps réel interrompue : {e.Message}");
            }
            _socket = null;
            SetConnected(false);
            try
            {
                await Task.Delay(backoff, ct);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            backoff = TimeSpan.FromSeconds(Math.Min(30, backoff.TotalSeconds * 2));
        }
    }

    private void SetConnected(bool connected)
    {
        if (Connected == connected) return;
        Connected = connected;
        ConnectionChanged?.Invoke(connected);
    }

    private async Task ReceiveAsync(ClientWebSocket socket, CancellationToken ct)
    {
        var buffer = new byte[16 * 1024];
        using var message = new MemoryStream();
        while (socket.State == WebSocketState.Open && !ct.IsCancellationRequested)
        {
            var result = await socket.ReceiveAsync(buffer, ct);
            if (result.MessageType == WebSocketMessageType.Close) return;
            message.Write(buffer, 0, result.Count);
            if (!result.EndOfMessage) continue;
            var json = Encoding.UTF8.GetString(message.GetBuffer(), 0, (int)message.Length);
            message.SetLength(0);
            Handle(json);
        }
    }

    private void Handle(string json)
    {
        var msg = SyncPlayParser.Parse(json);
        switch (msg)
        {
            case null:
                return;
            case KeepAliveRequest k:
                _keepAliveSeconds = Math.Clamp(k.Seconds / 2, 5, 60);
                return;
            case GroupJoinedMessage g:
                Group = g.Group;
                break;
            case GroupLeftMessage:
                Group = null;
                break;
            case UserJoinedMessage u when Group is { } group && !group.Participants.Contains(u.UserName):
                Group = group with { Participants = [.. group.Participants, u.UserName] };
                break;
            case UserLeftMessage u when Group is { } group:
                Group = group with { Participants = [.. group.Participants.Where(p => p != u.UserName)] };
                break;
            case StateMessage s when Group is { } group:
                Group = group with { State = s.State };
                break;
            case ErrorMessage { Kind: "NotInGroup" or "GroupDoesNotExist" }:
                Group = null;
                break;
        }
        AppLog.Debug("syncplay", msg.ToString());
        try
        {
            MessageReceived?.Invoke(msg);
        }
        catch (Exception e)
        {
            AppLog.Error("syncplay", "Traitement d’un message de soirée impossible", e);
        }
    }

    private async Task KeepAliveAsync(ClientWebSocket socket, CancellationToken ct)
    {
        var payload = Encoding.UTF8.GetBytes("{\"MessageType\":\"KeepAlive\"}");
        try
        {
            while (!ct.IsCancellationRequested && socket.State == WebSocketState.Open)
            {
                await Task.Delay(TimeSpan.FromSeconds(_keepAliveSeconds), ct);
                await socket.SendAsync(payload, WebSocketMessageType.Text, true, ct);
            }
        }
        catch (Exception)
        {
            // Fin de connexion : la boucle principale reconnecte.
        }
    }

    public async ValueTask DisposeAsync()
    {
        _cts.Cancel();
        try
        {
            if (_socket is { State: WebSocketState.Open } s)
                await s.CloseAsync(WebSocketCloseStatus.NormalClosure, "", CancellationToken.None).WaitAsync(TimeSpan.FromSeconds(2));
        }
        catch (Exception)
        {
        }
        if (_loop != null)
        {
            try
            {
                await _loop.WaitAsync(TimeSpan.FromSeconds(3));
            }
            catch (Exception)
            {
            }
        }
        _cts.Dispose();
    }
}
