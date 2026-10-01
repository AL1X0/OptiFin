namespace OptiFin.Core.SyncPlay;

/// <summary>Lecteur piloté par une soirée (adaptateur vers mpv ou un autre moteur).</summary>
public interface ISyncTarget
{
    TimeSpan Position { get; }
    bool Paused { get; }
    void Play();
    void Pause();
    void Seek(TimeSpan position);
    void SetSpeed(double speed);
}

/// <summary>Ce que le lecteur doit envoyer au serveur.</summary>
public interface ISyncRequests
{
    Task ReadyAsync(TimeSpan position, bool isPlaying, string playlistItemId);
    Task BufferingAsync(TimeSpan position, bool isPlaying, string playlistItemId);
    Task PauseAsync();
    Task UnpauseAsync();
    Task SeekAsync(TimeSpan position);
}

/// <summary>
/// Synchronise un lecteur avec la soirée : applique les ordres du serveur à l'heure prévue (heure du
/// serveur convertie en heure locale), signale « prêt » et la mise en mémoire tampon, rattrape la
/// dérive pendant la lecture (léger changement de vitesse, ou saut si l'écart est grand). Les
/// actions de l'utilisateur deviennent des demandes au groupe.
/// </summary>
public sealed class SyncPlayPlayback(ISyncTarget target, ISyncRequests requests, TimeSync time, string playlistItemId)
{
    /// <summary>Au-delà : saut direct à la bonne position.</summary>
    public static readonly TimeSpan SkipThreshold = TimeSpan.FromMilliseconds(800);
    /// <summary>Au-delà : rattrapage en douceur par la vitesse de lecture.</summary>
    public static readonly TimeSpan SpeedThreshold = TimeSpan.FromMilliseconds(120);

    private (DateTime When, TimeSpan Position)? _playingFrom;
    private DateTime? _pendingUnpause;
    private bool _speedAdjusted;
    private bool _buffering;
    private bool _waitingForSeek;
    private bool _readyAfterSeekPlaying;

    public string PlaylistItemId { get; private set; } = playlistItemId;

    /// <summary>Écart mesuré au dernier contrôle (positif : en avance sur le groupe).</summary>
    public TimeSpan Drift { get; private set; }

    /// <summary>Le groupe attend (préparation, mise en tampon d'un participant…).</summary>
    public bool Waiting { get; private set; } = true;

    /// <summary>Titre chargé et position de départ atteinte : prêt pour le groupe.</summary>
    public Task LoadedAsync(bool isPlaying) => requests.ReadyAsync(target.Position, isPlaying, PlaylistItemId);

    public void Apply(SyncCommand command)
    {
        if (command.Kind != SyncCommandKind.Stop && command.PlaylistItemId != PlaylistItemId) return;
        switch (command.Kind)
        {
            case SyncCommandKind.Unpause:
                Waiting = false;
                _playingFrom = (command.When, command.Position);
                var start = time.ToLocal(command.When);
                var now = time.LocalNow;
                if (start > now)
                {
                    // Départ dans le futur : en pause à la bonne position jusqu'à l'heure prévue.
                    target.Pause();
                    SeekIfFar(command.Position, TimeSpan.FromMilliseconds(250));
                    _pendingUnpause = start;
                }
                else
                {
                    // En retard : on part directement là où en est le groupe.
                    SeekIfFar(command.Position + (now - start), TimeSpan.FromMilliseconds(250));
                    target.Play();
                    _pendingUnpause = null;
                }
                break;
            case SyncCommandKind.Pause:
                _playingFrom = null;
                _pendingUnpause = null;
                ResetSpeed();
                target.Pause();
                SeekIfFar(command.Position, TimeSpan.FromMilliseconds(200));
                break;
            case SyncCommandKind.Seek:
                _readyAfterSeekPlaying = _playingFrom != null || !target.Paused;
                _playingFrom = null;
                _pendingUnpause = null;
                ResetSpeed();
                Waiting = true;
                target.Pause();
                target.Seek(command.Position);
                _waitingForSeek = true;
                break;
            case SyncCommandKind.Stop:
                _playingFrom = null;
                _pendingUnpause = null;
                ResetSpeed();
                target.Pause();
                break;
        }
    }

    /// <summary>Le lecteur a fini de se positionner (après un saut demandé par le groupe).</summary>
    public void OnSeekCompleted()
    {
        if (!_waitingForSeek) return;
        _waitingForSeek = false;
        _ = requests.ReadyAsync(target.Position, _readyAfterSeekPlaying, PlaylistItemId);
    }

    /// <summary>Mémoire tampon : le groupe attend ce participant, puis repart ensemble.</summary>
    public void OnBuffering(bool buffering)
    {
        if (buffering == _buffering) return;
        _buffering = buffering;
        var playing = _playingFrom != null;
        if (buffering) _ = requests.BufferingAsync(target.Position, playing, PlaylistItemId);
        else _ = requests.ReadyAsync(target.Position, playing, PlaylistItemId);
    }

    /// <summary>À appeler régulièrement (≈ 4 fois par seconde) : départ programmé et rattrapage de dérive.</summary>
    public void Tick()
    {
        if (_pendingUnpause is { } at && time.LocalNow >= at)
        {
            _pendingUnpause = null;
            target.Play();
            return;
        }
        if (_playingFrom is not { } from || _buffering || target.Paused || _pendingUnpause != null) return;
        var expected = from.Position + (time.ServerNow - from.When);
        Drift = target.Position - expected;
        var gap = Drift.Duration();
        if (gap > SkipThreshold)
        {
            ResetSpeed();
            target.Seek(expected);
        }
        else if (gap > SpeedThreshold)
        {
            // En avance : on ralentit un peu ; en retard : on accélère un peu (imperceptible).
            target.SetSpeed(Drift > TimeSpan.Zero ? 0.95 : 1.05);
            _speedAdjusted = true;
        }
        else if (_speedAdjusted && gap < TimeSpan.FromMilliseconds(40))
        {
            ResetSpeed();
        }
    }

    private void ResetSpeed()
    {
        if (!_speedAdjusted) return;
        _speedAdjusted = false;
        target.SetSpeed(1);
    }

    private void SeekIfFar(TimeSpan position, TimeSpan tolerance)
    {
        if ((target.Position - position).Duration() > tolerance) target.Seek(position);
    }

    // ------------------------------------------------------------ Actions de l'utilisateur

    public Task RequestTogglePlayAsync() => _playingFrom != null || _pendingUnpause != null ? requests.PauseAsync() : requests.UnpauseAsync();
    public Task RequestPauseAsync() => requests.PauseAsync();
    public Task RequestUnpauseAsync() => requests.UnpauseAsync();
    public Task RequestSeekAsync(TimeSpan position) => requests.SeekAsync(position);

    public void OnGroupState(GroupState state) => Waiting = state == GroupState.Waiting;

    /// <summary>Le groupe passe à un autre élément de la file.</summary>
    public void ChangeItem(string playlistItemId)
    {
        PlaylistItemId = playlistItemId;
        _playingFrom = null;
        _pendingUnpause = null;
        Waiting = true;
        ResetSpeed();
    }
}
