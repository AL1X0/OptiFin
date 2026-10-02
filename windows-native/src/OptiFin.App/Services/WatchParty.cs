using Microsoft.UI.Dispatching;
using OptiFin.App.Player;
using OptiFin.Core.Api;
using OptiFin.Core.Logging;
using OptiFin.Core.Media;
using OptiFin.Core.SyncPlay;

namespace OptiFin.App.Services;

/// <summary>
/// Soirées (SyncPlay de Jellyfin) à l'échelle de l'appli : connexion ouverte dès qu'un compte est
/// actif, état du groupe pour l'interface, et ouverture du lecteur chez tout le monde quand un
/// participant lance un titre. Les événements arrivent sur le fil d'interface.
/// </summary>
public static class WatchParty
{
    private static SyncPlayClient? _client;
    private static DispatcherQueue? _ui;
    private static string? _openedPlaylistItem;
    private static bool _creating, _created, _launching, _launched, _stopping;

    public static SyncPlayClient? Client => _client;
    public static GroupInfo? Group => _client?.Group;
    public static bool InParty => Group != null;

    /// <summary>
    /// Hôte de la soirée : celui qui l'a créée ou qui a lancé le titre en cours. Quand il quitte le
    /// lecteur, la lecture s'arrête pour tout le monde.
    /// </summary>
    public static bool IsHost => InParty && (_created || _launched);

    /// <summary>Groupe, participants ou connexion modifiés.</summary>
    public static event Action? Changed;
    /// <summary>Annonce courte à afficher (arrivée d'un participant, erreur…).</summary>
    public static event Action<string>? Notice;
    public static event Action<SyncCommand>? CommandReceived;
    public static event Action<GroupState>? StateReceived;
    /// <summary>Nouvelle file : le lecteur ouvert change d'élément s'il le faut.</summary>
    public static event Action<PlayQueue>? QueueReceived;

    public static void Attach(JellyfinClient? api)
    {
        _ui ??= DispatcherQueue.GetForCurrentThread();
        var old = _client;
        _client = null;
        _openedPlaylistItem = null;
        _created = _launching = _launched = false;
        if (old != null) _ = old.DisposeAsync().AsTask();
        if (api is null)
        {
            Changed?.Invoke();
            return;
        }
        var client = new SyncPlayClient(api);
        client.MessageReceived += m => Ui(() => OnMessage(client, m));
        client.ConnectionChanged += _ => Ui(() => Changed?.Invoke());
        _client = client;
        client.Start();
        Changed?.Invoke();
    }

    private static void Ui(Action action) => _ui?.TryEnqueue(() => action());

    private static void OnMessage(SyncPlayClient client, SyncPlayMessage message)
    {
        if (client != _client) return;
        switch (message)
        {
            case GroupJoinedMessage g:
                _created = _creating;
                _creating = false;
                Notice?.Invoke($"Vous avez rejoint « {g.Group.Name} »");
                break;
            case GroupLeftMessage:
                _openedPlaylistItem = null;
                _created = _launching = _launched = false;
                Notice?.Invoke("Vous avez quitté la soirée");
                break;
            case UserJoinedMessage u:
                Notice?.Invoke($"{u.UserName} a rejoint la soirée");
                break;
            case UserLeftMessage u:
                Notice?.Invoke($"{u.UserName} a quitté la soirée");
                break;
            case ErrorMessage e:
                Notice?.Invoke(e.UserMessage);
                break;
            case StateMessage s:
                StateReceived?.Invoke(s.State);
                break;
            case CommandMessage c:
                if (c.Command.Kind == SyncCommandKind.Stop)
                {
                    _openedPlaylistItem = null;
                    if (!_stopping && !string.IsNullOrEmpty(c.Command.PlaylistItemId) && PlayerLauncher.Current != null)
                        Notice?.Invoke("L’hôte a arrêté la lecture");
                    _stopping = false;
                }
                CommandReceived?.Invoke(c.Command);
                break;
            case QueueMessage q:
                OnQueue(q.Queue);
                break;
        }
        Changed?.Invoke();
    }

    private static void OnQueue(PlayQueue queue)
    {
        // Nouveau titre : lancé par nous (hôte de ce titre) ou par un autre participant.
        if (queue.Reason == "NewPlaylist")
        {
            _launched = _launching;
            _launching = false;
        }
        QueueReceived?.Invoke(queue);
        if (queue.Current is not { } current || current.PlaylistItemId == _openedPlaylistItem) return;
        if (queue.Reason is not ("NewPlaylist" or "SetCurrentItem" or "NextItem" or "PreviousItem")) return;
        _openedPlaylistItem = current.PlaylistItemId;
        _ = OpenAsync(current, queue);
    }

    private static async Task OpenAsync(QueueItem current, PlayQueue queue)
    {
        if (AppServices.Media is not { } media) return;
        try
        {
            var item = await media.ItemAsync(current.ItemId);
            PlayerLauncher.PlayInParty(item, new PartyStart(current.PlaylistItemId, queue.Start, queue.IsPlaying));
        }
        catch (ApiException e)
        {
            Notice?.Invoke($"Le titre de la soirée est introuvable : {e.UserMessage}");
        }
    }

    // ------------------------------------------------------------ Actions

    public static async Task<IReadOnlyList<GroupInfo>> ListAsync() => _client is { } c ? await c.ListAsync() : [];

    public static async Task CreateAsync(string name)
    {
        if (_client is not { } c) return;
        _creating = true;
        await Safe(() => c.CreateAsync(name));
    }

    public static async Task JoinAsync(string groupId)
    {
        if (_client is not { } c) return;
        await Safe(() => c.JoinAsync(groupId));
    }

    public static async Task LeaveAsync()
    {
        if (_client is not { } c) return;
        await Safe(() => c.LeaveAsync());
        _openedPlaylistItem = null;
        _created = _launching = _launched = false;
        Changed?.Invoke();
    }

    /// <summary>Lance un titre pour toute la soirée (chacun l'ouvre à cette position).</summary>
    public static async Task PlayAsync(MediaItem item, TimeSpan start)
    {
        if (_client is not { } c) return;
        AppLog.Info("syncplay", $"Lancement pour la soirée : « {item.Name} »");
        _launching = true;
        await Safe(() => c.SetQueueAsync([item.Id], 0, start));
    }

    /// <summary>L'hôte quitte le lecteur : arrêt de la lecture pour toute la soirée.</summary>
    public static async Task StopForAllAsync()
    {
        if (_client is not { } c || !IsHost) return;
        AppLog.Info("syncplay", "L’hôte quitte la lecture : arrêt pour la soirée");
        _stopping = true;
        await Safe(() => c.StopAsync());
    }

    private static async Task Safe(Func<Task> action)
    {
        try
        {
            await action();
        }
        catch (ApiException e)
        {
            Notice?.Invoke(e.UserMessage);
        }
        catch (Exception e)
        {
            AppLog.Warn("syncplay", e.Message);
            Notice?.Invoke("La soirée n’a pas pu être mise à jour.");
        }
    }

    /// <summary>Demandes du lecteur au groupe (adaptateur pour <see cref="SyncPlayPlayback"/>).</summary>
    public sealed class Requests(SyncPlayClient client) : ISyncRequests
    {
        public Task ReadyAsync(TimeSpan position, bool isPlaying, string playlistItemId) =>
            Safe(() => client.ReadyAsync(position, isPlaying, playlistItemId));
        public Task BufferingAsync(TimeSpan position, bool isPlaying, string playlistItemId) =>
            Safe(() => client.BufferingAsync(position, isPlaying, playlistItemId));
        public Task PauseAsync() => Safe(() => client.PauseAsync());
        public Task UnpauseAsync() => Safe(() => client.UnpauseAsync());
        public Task SeekAsync(TimeSpan position) => Safe(() => client.SeekAsync(position));
    }
}

/// <summary>Ouverture du lecteur pour une soirée : élément de la file, position et état de départ.</summary>
public sealed record PartyStart(string PlaylistItemId, TimeSpan Start, bool IsPlaying);
