using System.Globalization;
using Microsoft.UI;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Input;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using OptiFin.App.Controls;
using OptiFin.App.Services;
using OptiFin.Core.Api;
using OptiFin.Core.Logging;
using OptiFin.Core.Media;
using OptiFin.Core.Playback;
using OptiFin.Core.Settings;
using OptiFin.Core.SyncPlay;
using OptiFin.Mpv;
using Windows.System;
using WinRT.Interop;
using DispatcherQueue = Microsoft.UI.Dispatching.DispatcherQueue;
using DispatcherQueueTimer = Microsoft.UI.Dispatching.DispatcherQueueTimer;

namespace OptiFin.App.Player;

/// <summary>
/// Lecteur : fenêtre vidéo mpv (HDR possible) + cette fenêtre de commandes transparente, toujours
/// au-dessus. Démarrage : plan du serveur → pistes préférées → mpv ; si la lecture directe échoue
/// avant la première image, bascule automatique sur le transcodage du serveur.
/// </summary>
public sealed partial class PlayerWindow : Window
{
    private readonly VideoHost _video = new();
    private MpvPlayer? _mpv;
    private MediaItem _item;
    private PlaybackPlan? _plan;
    private PlaybackExtras _extras = PlaybackExtras.Empty;
    private readonly DispatcherQueueTimer _hideTimer;
    private readonly DispatcherQueueTimer _reportTimer;
    private readonly DispatcherQueueTimer _startupTimer;
    private readonly DispatcherQueueTimer _levelTimer;
    private readonly HashSet<MediaSegment> _autoSkipped = [];
    private TimeSpan _position;
    private TimeSpan _duration;
    private TimeSpan _buffered;
    private bool _paused;
    private bool _started;
    private bool _transcodeTried;
    private bool _closing;
    private bool _reported;
    private bool _upNextDismissed;
    private bool _scrubbing;
    private TimeSpan _startPosition;
    private readonly IntPtr _hwnd;

    public PlayerWindow(MediaItem item, bool fromStart, PartyStart? party = null)
    {
        InitializeComponent();
        _item = item;
        _hwnd = WindowNative.GetWindowHandle(this);
        SystemBackdrop = new TransparentBackdrop();
        ExtendsContentIntoTitleBar = true;
        if (AppWindow.Presenter is OverlappedPresenter p) p.SetBorderAndTitleBar(false, false);
        AppWindow.SetIcon(Path.Combine(AppContext.BaseDirectory, "Assets", "OptiFin.ico"));
        Title = item.Name;
        _video.Own(_hwnd);
        // Commandes posées sur la vidéo : la fenêtre doit être réellement transparente pour Windows
        // (sinon écran noir, son seul). Et par sécurité, commandes masquées, elle est « voilée » (DWM) :
        // la vidéo est alors visible quoi qu'il arrive ; elle garde le focus et reçoit le clavier.
        var hr = Win32.EnableTransparency(_hwnd);
        AppLog.Info("player", $"Commandes superposées : transparence DWM {(hr >= 0 ? "active" : $"refusée (0x{hr:X8})")}");
        AppWindow.Changed += (_, e) =>
        {
            if (e.DidPositionChange || e.DidSizeChange || e.DidVisibilityChange) SyncVideo();
        };

        var dispatcher = DispatcherQueue.GetForCurrentThread();
        _hideTimer = Timer(dispatcher, TimeSpan.FromSeconds(2.5), HideControls);
        _reportTimer = Timer(dispatcher, TimeSpan.FromSeconds(10), () =>
        {
            if (_plan != null && _started) _ = AppServices.Playback!.ReportProgressAsync(_plan, _position, _paused);
        }, repeating: true);
        _startupTimer = Timer(dispatcher, TimeSpan.FromSeconds(30), () => _ = OnStartupFailureAsync("aucune image après 30 s"));
        _overlayTimer = Timer(dispatcher, TimeSpan.FromMilliseconds(300), () =>
        {
            if (Controls.Opacity == 0 && !_stats && Preparing.Visibility == Visibility.Collapsed && ErrorPanel.Visibility == Visibility.Collapsed)
                SetOverlayVisible(false);
        });
        _cursorTimer = Timer(dispatcher, TimeSpan.FromMilliseconds(100), () =>
        {
            if (Win32.GetCursorPos(out var p) && (Math.Abs(p.X - _cursorWhenCloaked.X) > 2 || Math.Abs(p.Y - _cursorWhenCloaked.Y) > 2))
                ShowControls(autoHide: true);
        }, repeating: true);
        _levelTimer = Timer(dispatcher, TimeSpan.FromMilliseconds(900), () => Level.Opacity = 0);

        _statsTimer = Timer(dispatcher, TimeSpan.FromSeconds(1), UpdateStats, repeating: true);
        WireControls();
        if (AppServices.Settings.DebugMode) ToggleStats(true);
        MediaSession.Attach(_hwnd);
        MediaSession.ButtonPressed += OnMediaButton;
        Closed += (_, _) => Shutdown();
        _startPosition = party?.Start ?? (fromStart ? TimeSpan.Zero : item.ResumePosition);
        _syncTimer = Timer(dispatcher, TimeSpan.FromMilliseconds(250), () => _sync?.Tick(), repeating: true);
        WatchParty.CommandReceived += OnPartyCommand;
        WatchParty.StateReceived += OnPartyState;
        WatchParty.Changed += UpdatePartyBadge;
        if (party != null) SetupParty(party);
        PreparingTitle.Text = item.Kind == MediaKind.Episode ? $"{item.SeriesName} · {item.EpisodeLabel}" : item.Name;
        SetTitles(item);
        Win32.SetThreadExecutionState(Win32.ES_CONTINUOUS | Win32.ES_DISPLAY_REQUIRED | Win32.ES_SYSTEM_REQUIRED);
        _ = StartAsync(item, _startPosition);
    }

    private static DispatcherQueueTimer Timer(DispatcherQueue d, TimeSpan interval, Action tick, bool repeating = false)
    {
        var t = d.CreateTimer();
        t.Interval = interval;
        t.IsRepeating = repeating;
        t.Tick += (_, _) => tick();
        return t;
    }

    /// <summary>Ouvre le lecteur sur la zone de la fenêtre principale (ou en plein écran).</summary>
    public void ShowOver(AppWindow main)
    {
        var area = DisplayArea.GetFromWindowId(main.Id, DisplayAreaFallback.Primary);
        AppWindow.MoveAndResize(main.Presenter is OverlappedPresenter { State: OverlappedPresenterState.Maximized }
            ? area.WorkArea
            : new Windows.Graphics.RectInt32(main.Position.X, main.Position.Y, main.Size.Width, main.Size.Height));
        // Entrée en fondu (le rideau « Préparation » noir apparaît sur la fenêtre principale), puis
        // la fenêtre vidéo une fois le fondu fini.
        Root.Opacity = 0;
        Root.OpacityTransition = new ScalarTransition { Duration = TimeSpan.FromMilliseconds(260) };
        Activate();
        DispatcherQueue.TryEnqueue(Microsoft.UI.Dispatching.DispatcherQueuePriority.Low, () => Root.Opacity = 1);
        var reveal = Timer(DispatcherQueue.GetForCurrentThread(), TimeSpan.FromMilliseconds(280), () =>
        {
            if (_closing) return;
            _videoShown = true;
            SyncVideo();
        });
        reveal.Start();
    }

    private bool _videoShown;

    private void SyncVideo()
    {
        if (!AppWindow.IsVisible)
        {
            _video.Show(false);
            return;
        }
        var pos = AppWindow.Position;
        var size = AppWindow.Size;
        _video.Place(pos.X, pos.Y, size.Width, size.Height, visible: _videoShown);
    }

    // ------------------------------------------------------------ Démarrage

    private async Task StartAsync(MediaItem item, TimeSpan start, bool forceTranscode = false)
    {
        var playback = AppServices.Playback!;
        var media = AppServices.Media!;
        try
        {
            ShowPreparing(forceTranscode ? "Le serveur prépare une version compatible…" : null);
            var full = item.Kind.IsPlayableVideo() && item.Overview is null ? await media.ItemAsync(item.Id) : item;
            _item = full;
            SetTitles(full);
            var settings = AppServices.Settings;
            var plan = await playback.PrepareAsync(full.Id, start, forceTranscode: forceTranscode, maxBitrate: settings.EffectiveMaxBitrate);
            var (audio, subtitle) = TrackPreferences.Preferred(plan, settings);
            // Transcodage : les pistes sont choisies par le serveur ; si elles changent, nouvelle demande.
            if (plan.Method != PlayMethod.DirectPlay && (audio != plan.AudioIndex || subtitle != plan.SubtitleIndex))
                plan = await playback.PrepareAsync(full.Id, start, audio, subtitle, forceTranscode, settings.EffectiveMaxBitrate, plan.MediaSourceId);
            else
                plan = plan with { AudioIndex = audio, SubtitleIndex = subtitle };
            _plan = plan;
            AppLog.Info("player", $"« {full.Name} » → {plan.Method.Label()} : conteneur {plan.Container}, vidéo {plan.VideoCodec} " +
                                  $"{plan.VideoRangeType}, {plan.Bitrate / 1_000_000.0:0.#} Mb/s");
            _ = LoadExtrasAsync(full);

            _mpv ??= CreatePlayer();
            _started = false;
            _startupTimer.Start();
            var headers = new Dictionary<string, string> { ["Authorization"] = AppServices.Client!.AuthorizationHeader };
            _mpv.Load(plan.StreamUrl, headers, start, full.Name);
            // En soirée : chargé en pause, le groupe donne le départ.
            if (_sync != null) _mpv.Pause();
            ApplySubtitleStyle();
        }
        catch (ApiException e)
        {
            ShowError(e.UserMessage, e.Detail);
        }
        catch (Exception e)
        {
            AppLog.Error("player", "Démarrage impossible", e);
            ShowError("La lecture n’a pas pu démarrer.", e.Message);
        }
    }

    private MpvPlayer CreatePlayer()
    {
        var mpv = MpvPlayer.Create(_video.Hwnd, AppServices.Settings.DebugMode);
        mpv.SetVolume(AppServices.Settings.Volume);
        mpv.PositionChanged += p => Ui(() => OnPosition(p));
        mpv.DurationChanged += d => Ui(() =>
        {
            _duration = d;
            UpdateTimes();
        });
        mpv.PauseChanged += paused => Ui(() =>
        {
            _paused = paused;
            PlayIcon.Glyph = paused ? "" : "";
            if (paused) ShowControls(autoHide: false);
            else ScheduleHide();
            if (_plan != null && _started) _ = AppServices.Playback!.ReportProgressAsync(_plan, _position, paused);
            MediaSession.Update(_item, !paused, _position, _duration);
        });
        mpv.BufferingChanged += b => Ui(() =>
        {
            Buffering.IsActive = b && _started;
        });
        mpv.CacheStallChanged += stalled => Ui(() =>
        {
            if (_started) _sync?.OnBuffering(stalled);
        });
        mpv.PlaybackRestarted += () => Ui(() => _sync?.OnSeekCompleted());
        mpv.BufferedChanged += b => Ui(() =>
        {
            _buffered = b;
            UpdateTimes();
        });
        mpv.FileLoaded += () => Ui(SelectInitialTracks);
        mpv.FirstFrame += () => Ui(OnFirstFrame);
        mpv.Ended += (reason, error) => Ui(() => OnEnded(reason, error));
        mpv.Log += (level, prefix, text) =>
            AppLog.Add(level is "error" or "fatal" ? LogLevel.Error : level == "warn" ? LogLevel.Warning : LogLevel.Debug, "mpv", $"[{prefix}] {text}");
        return mpv;
    }

    private void Ui(Action action) => DispatcherQueue.TryEnqueue(() =>
    {
        if (!_closing) action();
    });

    private void OnFirstFrame()
    {
        if (_started) return;
        _started = true;
        _startupTimer.Stop();
        Preparing.Visibility = Visibility.Collapsed;
        ScheduleHide();
        _reportTimer.Start();
        if (_plan != null)
        {
            if (!_reported)
            {
                _reported = true;
                _ = AppServices.Playback!.ReportStartAsync(_plan, _position);
            }
            if (_mpv != null) AppLog.Info("player", $"Première image — {MpvInfo.Describe(_mpv)}");
        }
        MediaSession.Update(_item, true, _position, _duration);
        if (_sync != null && _party != null)
        {
            _mpv?.Pause();
            _ = _sync.LoadedAsync(_party.IsPlaying);
            _syncTimer.Start();
        }
    }

    private void SelectInitialTracks()
    {
        if (_mpv is null || _plan is not { } plan) return;
        if (plan.Method == PlayMethod.DirectPlay)
        {
            if (plan.CurrentAudio is { } audio && plan.MpvId(audio) is { } aid) _mpv.SelectAudio(aid);
            SelectSubtitle(plan.CurrentSubtitle);
        }
        else if (plan.CurrentSubtitle is { IsExternal: true } external)
        {
            SelectSubtitle(external);
        }
    }

    private void SelectSubtitle(MediaTrack? track)
    {
        if (_mpv is null || _plan is null) return;
        if (track is null)
        {
            _mpv.SelectSubtitle(null);
            return;
        }
        if (track.IsExternal && track.DeliveryUrl is { } url)
        {
            _mpv.AddSubtitle(AppServices.Client!.Resolve(url), track.Label, track.Language);
            return;
        }
        if (_plan.MpvId(track) is { } sid) _mpv.SelectSubtitle(sid);
    }

    private void OnEnded(EndReason reason, string? error)
    {
        if (reason == EndReason.Error)
        {
            AppLog.Warn("player", $"mpv : {error}");
            if (!_started)
            {
                _ = OnStartupFailureAsync(error ?? "erreur");
                return;
            }
            ShowError("La lecture s’est interrompue.", error);
            return;
        }
        if (reason != EndReason.Eof) return;
        if (_sync != null)
        {
            RequestClose();
            return;
        }
        if (_extras.NextEpisode is { } next && AppServices.Settings.AutoPlayNext && !_upNextDismissed)
        {
            _ = PlayNextAsync(next);
            return;
        }
        RequestClose();
    }

    private async Task OnStartupFailureAsync(string reason)
    {
        if (_started || _closing) return;
        _startupTimer.Stop();
        AppLog.Warn("player", $"Échec au démarrage ({_plan?.Method.Label()}) : {reason}");
        if (_transcodeTried || _plan?.Method == PlayMethod.Transcode)
        {
            ShowError("Le lecteur n’a pas pu lire ce fichier.", reason);
            return;
        }
        _transcodeTried = true;
        if (_plan != null) _ = AppServices.Playback!.ReportStoppedAsync(_plan, _startPosition, failed: true);
        _reported = false;
        await StartAsync(_item, _startPosition, forceTranscode: true);
    }

    private async Task LoadExtrasAsync(MediaItem item)
    {
        _extras = await AppServices.Playback!.ExtrasAsync(item, AppServices.Media!);
        AppLog.Info("extras", $"{_extras.Chapters.Count} chapitres, {_extras.Segments.Count} segments" +
                              (_extras.NextEpisode is { } n ? $", suivant : « {n.Name} »" : ""));
    }

    private async Task PlayNextAsync(MediaItem next)
    {
        if (_plan != null) await AppServices.Playback!.ReportStoppedAsync(_plan, _position);
        _plan = null;
        _extras = PlaybackExtras.Empty;
        _autoSkipped.Clear();
        _upNextDismissed = false;
        _reported = false;
        _transcodeTried = false;
        UpNext.Visibility = Visibility.Collapsed;
        _startPosition = next.ResumePosition;
        _item = next;
        await StartAsync(next, next.ResumePosition);
    }

    // ------------------------------------------------------------ Position, segments, épisode suivant

    private void OnPosition(TimeSpan position)
    {
        _position = position;
        if (!_scrubbing) UpdateTimes();
        var segment = _extras.SkippableAt(position);
        if (segment != null && _sync is null && AppServices.Settings.AutoSkipSegments && _autoSkipped.Add(segment))
        {
            AppLog.Info("player", $"Segment passé automatiquement : {segment.Type}");
            _mpv?.Seek(segment.End);
            segment = null;
        }
        if (segment != null)
        {
            SkipButton.Content = segment.SkipLabel;
            SkipButton.Tag = segment;
            SkipButton.Visibility = Visibility.Visible;
        }
        else
        {
            SkipButton.Visibility = Visibility.Collapsed;
        }
        var upNextAt = _extras.UpNextAt(_duration);
        var showUpNext = upNextAt != null && position >= upNextAt && !_upNextDismissed && _extras.NextEpisode != null;
        if (showUpNext && UpNext.Visibility != Visibility.Visible)
            UpNextTitle.Text = $"{_extras.NextEpisode!.EpisodeLabel} · {_extras.NextEpisode.Name}";
        UpNext.Visibility = showUpNext ? Visibility.Visible : Visibility.Collapsed;
        if (showUpNext) SkipButton.Visibility = Visibility.Collapsed;
        ChapterText.Text = _extras.ChapterAt(position)?.Name ?? "";
    }

    private void UpdateTimes()
    {
        var width = Scrubber.ActualWidth;
        var total = _duration.TotalSeconds;
        PlayedBar.Width = total > 0 ? Math.Clamp(_position.TotalSeconds / total, 0, 1) * width : 0;
        BufferedBar.Width = total > 0 ? Math.Clamp(_buffered.TotalSeconds / total, 0, 1) * width : 0;
        PositionText.Text = MediaFormat.Clock(_position);
        var remaining = _duration > _position ? _duration - _position : TimeSpan.Zero;
        RemainingText.Text = $"-{MediaFormat.Clock(remaining)}";
        EndsAtText.Text = _duration > TimeSpan.Zero ? $"Fin à {DateTime.Now.Add(remaining):HH:mm}" : "";
        if (_started && (int)_position.TotalSeconds % 5 == 0) MediaSession.Update(_item, !_paused, _position, _duration);
    }

    // ------------------------------------------------------------ Commandes

    private void WireControls()
    {
        CloseButton.Click += (_, _) => RequestClose();
        ErrorClose.Click += (_, _) => RequestClose();
        InfoButton.Click += (_, _) => ToggleStats(!_stats);
        PlayButton.Click += (_, _) => TogglePlay();
        BackButton.Click += (_, _) => SeekBy(-10);
        ForwardButton.Click += (_, _) => SeekBy(10);
        FullscreenButton.Click += (_, _) => ToggleFullscreen();
        SkipButton.Click += (_, _) =>
        {
            if (SkipButton.Tag is MediaSegment s) UserSeek(s.End);
        };
        UpNextPlay.Click += (_, _) =>
        {
            if (_extras.NextEpisode is { } next) _ = PlayNextAsync(next);
        };
        UpNextDismiss.Click += (_, _) =>
        {
            _upNextDismissed = true;
            UpNext.Visibility = Visibility.Collapsed;
        };
        AudioButton.Click += (_, _) => ShowTrackMenu(AudioButton, TrackType.Audio);
        SubtitlesButton.Click += (_, _) => ShowTrackMenu(SubtitlesButton, TrackType.Subtitle);
        SettingsButton.Click += (_, _) => ShowSettingsMenu();

        // Surface : clic = lecture/pause, double-clic = plein écran, molette = volume.
        Surface.Tapped += (_, _) => TogglePlay();
        Surface.DoubleTapped += (_, _) => ToggleFullscreen();
        // Seul un vrai déplacement compte : WinUI signale aussi des « mouvements » immobiles
        // (changement d'élément sous le curseur, fondu des commandes) qui retardaient leur masquage.
        Root.PointerMoved += (_, e) =>
        {
            var p = e.GetCurrentPoint(Root).Position;
            if (Math.Abs(p.X - _lastPointer.X) < 3 && Math.Abs(p.Y - _lastPointer.Y) < 3) return;
            _lastPointer = p;
            ShowControls(autoHide: true);
        };
        Root.PointerWheelChanged += (_, e) =>
        {
            ChangeVolume(e.GetCurrentPoint(Root).Properties.MouseWheelDelta > 0 ? 0.05 : -0.05);
            e.Handled = true;
        };
        Root.KeyDown += OnKey;
        Root.Loaded += (_, _) => Root.Focus(FocusState.Programmatic);
        Root.IsTabStop = true;

        // Barre de progression : clic ou glisser pour chercher, temps au survol.
        Scrubber.PointerPressed += (_, e) =>
        {
            _scrubbing = true;
            Scrubber.CapturePointer(e.Pointer);
            Scrub(e.GetCurrentPoint(Scrubber).Position.X);
        };
        Scrubber.PointerMoved += (_, e) =>
        {
            var x = e.GetCurrentPoint(Scrubber).Position.X;
            ShowHover(x);
            if (_scrubbing) Scrub(x);
        };
        Scrubber.PointerReleased += (_, e) =>
        {
            if (!_scrubbing) return;
            _scrubbing = false;
            Scrubber.ReleasePointerCapture(e.Pointer);
            UserSeek(At(e.GetCurrentPoint(Scrubber).Position.X));
        };
        Scrubber.PointerExited += (_, _) => HoverLabel.Visibility = Visibility.Collapsed;
        Scrubber.SizeChanged += (_, _) => UpdateTimes();
    }

    private TimeSpan At(double x) =>
        TimeSpan.FromSeconds(Math.Clamp(x / Math.Max(1, Scrubber.ActualWidth), 0, 1) * _duration.TotalSeconds);

    private void Scrub(double x)
    {
        var target = At(x);
        PlayedBar.Width = Math.Clamp(x, 0, Scrubber.ActualWidth);
        PositionText.Text = MediaFormat.Clock(target);
    }

    private void ShowHover(double x)
    {
        if (_duration <= TimeSpan.Zero) return;
        var at = At(x);
        var chapter = _extras.ChapterAt(at);
        HoverText.Text = chapter is null ? MediaFormat.Clock(at) : $"{MediaFormat.Clock(at)} · {chapter.Name}";
        HoverLabel.Visibility = Visibility.Visible;
        HoverLabel.Measure(new Windows.Foundation.Size(double.PositiveInfinity, double.PositiveInfinity));
        var w = HoverLabel.DesiredSize.Width;
        HoverLabel.Margin = new Thickness(Math.Clamp(x - w / 2, 0, Math.Max(0, Scrubber.ActualWidth - w)), -30, 0, 0);
    }

    private void OnKey(object sender, KeyRoutedEventArgs e)
    {
        var ctrl = InputKeyboardSource.GetKeyStateForCurrentThread(VirtualKey.Control).HasFlag(Windows.UI.Core.CoreVirtualKeyStates.Down);
        if (ctrl) return;
        switch (e.Key)
        {
            case VirtualKey.Space or VirtualKey.K:
                TogglePlay();
                break;
            case VirtualKey.Left or VirtualKey.J:
                SeekBy(-10);
                break;
            case VirtualKey.Right or VirtualKey.L:
                SeekBy(10);
                break;
            case VirtualKey.Up:
                ChangeVolume(0.05);
                break;
            case VirtualKey.Down:
                ChangeVolume(-0.05);
                break;
            case VirtualKey.M:
                ToggleMute();
                break;
            case VirtualKey.F or VirtualKey.F11:
                ToggleFullscreen();
                break;
            case VirtualKey.Escape:
                if (AppWindow.Presenter.Kind == AppWindowPresenterKind.FullScreen) ToggleFullscreen();
                else RequestClose();
                break;
            case VirtualKey.I:
                ToggleStats(!_stats);
                break;
            case VirtualKey.S when SkipButton.Visibility == Visibility.Visible && SkipButton.Tag is MediaSegment s:
                UserSeek(s.End);
                break;
            default:
                return;
        }
        e.Handled = true;
        ShowControls(autoHide: true);
    }

    private void TogglePlay()
    {
        if (_mpv is null) return;
        if (_sync != null)
        {
            _ = _paused ? _sync.RequestUnpauseAsync() : _sync.RequestPauseAsync();
            return;
        }
        if (_paused) _mpv.Play();
        else _mpv.Pause();
    }

    private void SeekBy(int seconds)
    {
        if (_mpv is null) return;
        var target = _position + TimeSpan.FromSeconds(seconds);
        UserSeek(target < TimeSpan.Zero ? TimeSpan.Zero : target);
        ShowControls(autoHide: true);
    }

    /// <summary>Saut demandé par l'utilisateur : direct, ou demandé au groupe en soirée.</summary>
    private void UserSeek(TimeSpan target)
    {
        if (_sync != null) _ = _sync.RequestSeekAsync(target);
        else _mpv?.Seek(target);
    }

    // ------------------------------------------------------------ Soirée

    private SyncPlayPlayback? _sync;
    private PartyStart? _party;
    private readonly DispatcherQueueTimer _syncTimer;

    private void SetupParty(PartyStart party)
    {
        _party = party;
        if (WatchParty.Client is not { } client) return;
        if (_sync is null) _sync = new SyncPlayPlayback(new MpvTarget(this), new WatchParty.Requests(client), client.Time, party.PlaylistItemId);
        else _sync.ChangeItem(party.PlaylistItemId);
        UpdatePartyBadge();
    }

    /// <summary>La soirée lance un autre titre alors que le lecteur est ouvert.</summary>
    public void JoinParty(MediaItem item, PartyStart party)
    {
        _syncTimer.Stop();
        SetupParty(party);
        _startPosition = party.Start;
        _transcodeTried = false;
        _reported = false;
        _upNextDismissed = false;
        _autoSkipped.Clear();
        UpNext.Visibility = Visibility.Collapsed;
        SkipButton.Visibility = Visibility.Collapsed;
        PreparingTitle.Text = item.Kind == MediaKind.Episode ? $"{item.SeriesName} · {item.EpisodeLabel}" : item.Name;
        _ = StartAsync(item, party.Start);
    }

    private void OnPartyCommand(SyncCommand command)
    {
        if (_sync is null || _closing) return;
        if (command.Kind == SyncCommandKind.Stop && command.PlaylistItemId is "" or "00000000000000000000000000000000") return;
        if (command.Kind == SyncCommandKind.Stop)
        {
            RequestClose();
            return;
        }
        _sync.Apply(command);
        UpdatePartyBadge();
        if (command.Kind is SyncCommandKind.Pause or SyncCommandKind.Seek) ShowControls(autoHide: false);
    }

    private void OnPartyState(GroupState state)
    {
        _sync?.OnGroupState(state);
        UpdatePartyBadge();
    }

    private void UpdatePartyBadge()
    {
        if (_closing) return;
        var group = WatchParty.Group;
        if (_sync is null || group is null)
        {
            PartyBadge.Visibility = Visibility.Collapsed;
            return;
        }
        PartyBadge.Visibility = Visibility.Visible;
        PartyText.Text = _sync.Waiting && group.State == GroupState.Waiting
            ? $"{group.Name} · en attente des autres…"
            : $"{group.Name} · {group.Participants.Count} participant{(group.Participants.Count > 1 ? "s" : "")}";
        ToolTipService.SetToolTip(PartyBadge, string.Join(", ", group.Participants));
    }

    /// <summary>mpv vu par la synchronisation de soirée.</summary>
    private sealed class MpvTarget(PlayerWindow w) : ISyncTarget
    {
        public TimeSpan Position => w._position;
        public bool Paused => w._paused;
        public void Play() => w._mpv?.Play();
        public void Pause() => w._mpv?.Pause();
        public void Seek(TimeSpan position) => w._mpv?.Seek(position);
        public void SetSpeed(double speed) => w._mpv?.SetSpeed(speed);
    }

    private bool _muted;

    private void ChangeVolume(double delta)
    {
        var s = AppServices.Settings;
        s.Volume = Math.Clamp(s.Volume + delta, 0, 1);
        _mpv?.SetVolume(s.Volume);
        if (_muted && delta > 0) ToggleMute();
        FlashLevel(s.Volume);
        AppServices.SaveSettings();
    }

    private void ToggleMute()
    {
        _muted = !_muted;
        _mpv?.SetMute(_muted);
        FlashLevel(_muted ? 0 : AppServices.Settings.Volume);
    }

    private void FlashLevel(double value)
    {
        LevelIcon.Glyph = value <= 0 ? "" : "";
        LevelBar.Value = value * 100;
        Level.Opacity = 1;
        _levelTimer.Stop();
        _levelTimer.Start();
    }

    private void ToggleFullscreen()
    {
        var full = AppWindow.Presenter.Kind == AppWindowPresenterKind.FullScreen;
        AppWindow.SetPresenter(full ? AppWindowPresenterKind.Overlapped : AppWindowPresenterKind.FullScreen);
        if (full && AppWindow.Presenter is OverlappedPresenter p) p.SetBorderAndTitleBar(false, false);
        FullscreenIcon.Glyph = full ? "" : "";
        SyncVideo();
    }

    private bool _overlayVisible = true;
    private readonly DispatcherQueueTimer _overlayTimer;
    private readonly DispatcherQueueTimer _cursorTimer;
    private readonly DispatcherQueueTimer _statsTimer;
    private bool _stats;
    private bool _leaving;
    private Windows.Foundation.Point _lastPointer = new(-100, -100);

    private Win32.Point _cursorWhenCloaked;

    private void SetOverlayVisible(bool visible)
    {
        if (_overlayVisible == visible) return;
        _overlayVisible = visible;
        Win32.Cloak(_hwnd, !visible);
        if (visible)
        {
            _cursorTimer.Stop();
        }
        else
        {
            // Voilée, la fenêtre ne voit plus la souris (elle passe sur la vidéo) : on surveille le curseur.
            Win32.GetCursorPos(out _cursorWhenCloaked);
            _cursorTimer.Start();
        }
    }

    private void ShowControls(bool autoHide)
    {
        if (!_overlayVisible) SetOverlayVisible(true);
        Controls.Opacity = 1;
        Controls.IsHitTestVisible = true;
        Root.ProtectedCursorReset();
        if (autoHide) ScheduleHide();
        else _hideTimer.Stop();
    }

    private void ScheduleHide()
    {
        _hideTimer.Stop();
        if (!_paused && _started) _hideTimer.Start();
    }

    private void HideControls()
    {
        if (_paused || !_started || _scrubbing) return;
        Controls.Opacity = 0;
        Controls.IsHitTestVisible = false;
        Root.HideCursor();
        // Après le fondu des commandes.
        _overlayTimer.Stop();
        _overlayTimer.Start();
    }

    // ------------------------------------------------------------ Menus

    private void ShowTrackMenu(FrameworkElement anchor, TrackType type)
    {
        if (_plan is not { } plan) return;
        var menu = new MenuFlyout();
        var tracks = type == TrackType.Audio ? plan.AudioTracks : plan.SubtitleTracks;
        var current = type == TrackType.Audio ? plan.AudioIndex : plan.SubtitleIndex;
        if (type == TrackType.Subtitle)
        {
            var none = new ToggleMenuFlyoutItem { Text = "Désactivés", IsChecked = current is null };
            none.Click += (_, _) => _ = SwitchTrackAsync(type, null);
            menu.Items.Add(none);
        }
        foreach (var t in tracks)
        {
            var label = t.IsForced ? $"{t.Label} (forcés)" : t.Label;
            var entry = new ToggleMenuFlyoutItem { Text = label, IsChecked = t.Index == current };
            entry.Click += (_, _) => _ = SwitchTrackAsync(type, t);
            menu.Items.Add(entry);
        }
        if (menu.Items.Count == 0) menu.Items.Add(new MenuFlyoutItem { Text = "Aucune piste", IsEnabled = false });
        menu.ShowAt(anchor);
        ShowControls(autoHide: false);
        menu.Closed += (_, _) => ScheduleHide();
    }

    /// <summary>Lecture directe : changement local par mpv. Transcodage : nouveau flux du serveur.</summary>
    private async Task SwitchTrackAsync(TrackType type, MediaTrack? track)
    {
        if (_plan is not { } plan || _mpv is null) return;
        var audio = type == TrackType.Audio ? track?.Index : plan.AudioIndex;
        var subtitle = type == TrackType.Subtitle ? track?.Index : plan.SubtitleIndex;
        var local = plan.Method == PlayMethod.DirectPlay &&
                    (track is null || !track.IsExternal || track.DeliveryUrl != null);
        if (local)
        {
            _plan = plan with { AudioIndex = audio, SubtitleIndex = subtitle };
            if (type == TrackType.Audio && track != null && plan.MpvId(track) is { } aid) _mpv.SelectAudio(aid);
            if (type == TrackType.Subtitle) SelectSubtitle(track);
            AppLog.Info("player", $"Piste {type} : {track?.Label ?? "aucune"}");
            return;
        }
        var position = _position;
        ShowPreparing("Changement de piste…");
        try
        {
            _plan = await AppServices.Playback!.PrepareAsync(plan.ItemId, position, audio, subtitle, plan.Method == PlayMethod.Transcode,
                AppServices.Settings.EffectiveMaxBitrate, plan.MediaSourceId);
            _started = false;
            _startupTimer.Start();
            _mpv.Load(_plan.StreamUrl, new Dictionary<string, string> { ["Authorization"] = AppServices.Client!.AuthorizationHeader }, position);
        }
        catch (ApiException e)
        {
            ShowError(e.UserMessage, e.Detail);
        }
    }

    /// <summary>
    /// Sortie en douceur : le son baisse, l'image s'assombrit jusqu'au noir, puis la fenêtre se
    /// ferme et la fenêtre principale réapparaît en fondu.
    /// </summary>
    private void RequestClose()
    {
        if (_leaving || _closing) return;
        _leaving = true;
        SetOverlayVisible(true);
        Controls.Opacity = 0;
        StatsPanel.Visibility = Visibility.Collapsed;
        Curtain.Opacity = 1;
        var volume = AppServices.Settings.Volume;
        var step = 0;
        var fade = DispatcherQueue.GetForCurrentThread().CreateTimer();
        fade.Interval = TimeSpan.FromMilliseconds(35);
        fade.Tick += (_, _) =>
        {
            step++;
            _mpv?.SetVolume(volume * Math.Max(0, 1 - step / 8.0));
            if (step < 9) return;
            fade.Stop();
            Close();
        };
        fade.Start();
    }

    // ------------------------------------------------------------ Infos de lecture

    private void ToggleStats(bool on)
    {
        _stats = on;
        StatsPanel.Visibility = on ? Visibility.Visible : Visibility.Collapsed;
        InfoButton.Background = on ? OptiFin.App.Controls.Ui.Res("OFGlassBrush") : new SolidColorBrush(Microsoft.UI.Colors.Transparent);
        InfoIcon.Foreground = on ? OptiFin.App.Controls.Ui.Res("OFAccentBrush") : OptiFin.App.Controls.Ui.Res("OFTextPrimaryBrush");
        if (on)
        {
            SetOverlayVisible(true);
            UpdateStats();
            _statsTimer.Start();
        }
        else
        {
            _statsTimer.Stop();
            ScheduleHide();
        }
    }

    /// <summary>Tableau technique mis à jour chaque seconde : flux, décodage, HDR, débit, cache, images perdues.</summary>
    private void UpdateStats()
    {
        if (!_stats) return;
        var rows = new List<(string Label, string Value)>();
        var mpv = _mpv;
        var plan = _plan;
        if (plan != null)
            rows.Add(("Lecture", $"{plan.Method.Label()}{(plan.Container is { } c ? $" · {c}" : "")}{(plan.Bitrate is { } b ? $" · {b / 1e6:0.#} Mb/s" : "")}"));
        if (mpv != null)
        {
            string? G(string name) => mpv.Get(name) is { Length: > 0 } v ? v : null;
            double? D(string name) => mpv.GetDouble(name);
            var fr = CultureInfo.GetCultureInfo("fr-FR");
            var w = G("video-params/w");
            var h = G("video-params/h");
            var fps = D("container-fps") ?? D("estimated-vf-fps");
            rows.Add(("Vidéo", string.Join(" · ", new[]
            {
                G("video-codec-name") ?? G("video-format"),
                w != null && h != null ? $"{w}×{h}" : null,
                fps is { } f ? $"{f.ToString("0.###", fr)} i/s" : null,
                G("video-params/pixelformat"),
            }.Where(x => x != null))));
            rows.Add(("Couleurs", $"{G("video-params/gamma") ?? "?"} · {G("video-params/primaries") ?? "?"}{(G("video-params/max-luma") is { } luma ? $" · {luma} nits" : "")}"));
            var hw = G("hwdec-current");
            rows.Add(("Décodage", hw is null or "no" ? "logiciel (processeur)" : $"matériel ({hw})"));
            rows.Add(("Sortie", $"{G("current-vo") ?? "?"} · {G("video-target-params/gamma") ?? "?"} · {G("video-target-params/primaries") ?? "?"}"));
            var display = D("display-fps");
            rows.Add(("Écran", $"{G("osd-width")}×{G("osd-height")}{(display is { } d ? $" · {d.ToString("0.##", fr)} Hz" : "")}"));
            var channels = G("audio-params/channel-count");
            var rate = D("audio-params/samplerate");
            rows.Add(("Audio", string.Join(" · ", new[]
            {
                G("audio-codec-name"),
                channels != null ? $"{channels} canaux" : null,
                rate is { } r ? $"{r / 1000:0.#} kHz" : null,
                G("current-ao"),
            }.Where(x => x != null))));
            var vbr = D("video-bitrate");
            var abr = D("audio-bitrate");
            rows.Add(("Débit", $"vidéo {(vbr is { } v ? $"{v / 1e6:0.0} Mb/s" : "?")} · audio {(abr is { } a ? $"{a / 1e3:0} kb/s" : "?")}"));
            var cache = D("demuxer-cache-duration");
            var speed = D("cache-speed");
            rows.Add(("Cache", $"{(cache is { } cd ? $"{cd:0} s" : "?")}{(speed is { } sp ? $" · {sp * 8 / 1e6:0.0} Mb/s" : "")}"));
            var avsync = D("avsync");
            rows.Add(("Images perdues", $"{mpv.DroppedFrames}{(D("vo-delayed-frame-count") is { } late ? $" · {late:0} en retard" : "")}{(avsync is { } av ? $" · synchro A/V {av * 1000:0} ms" : "")}"));
        }
        StatsGrid.Children.Clear();
        StatsGrid.RowDefinitions.Clear();
        for (var i = 0; i < rows.Count; i++)
        {
            StatsGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            if (string.IsNullOrWhiteSpace(rows[i].Value)) rows[i] = (rows[i].Label, "—");
            var label = new TextBlock { Text = rows[i].Label, FontSize = 12, Foreground = OptiFin.App.Controls.Ui.Res("OFTextTertiaryBrush") };
            var value = new TextBlock { Text = rows[i].Value, FontSize = 12, FontFamily = new FontFamily("Cascadia Mono, Consolas"), TextWrapping = TextWrapping.Wrap, MaxWidth = 460 };
            Grid.SetRow(label, i);
            Grid.SetRow(value, i);
            Grid.SetColumn(value, 1);
            StatsGrid.Children.Add(label);
            StatsGrid.Children.Add(value);
        }
    }

    private double _subtitleDelay;
    private double _audioDelay;

    private static string Seconds(double value) =>
        value == 0 ? "aucun" : (value > 0 ? "+" : "−") + Math.Abs(value).ToString("0.0", CultureInfo.GetCultureInfo("fr-FR")) + " s";

    private static MenuFlyoutSubItem DelayMenu(string title, string hint, Func<double> current, Action<double> set)
    {
        var menu = new MenuFlyoutSubItem { Text = $"{title} ({Seconds(current())})" };
        menu.Items.Add(new MenuFlyoutItem { Text = hint, IsEnabled = false });
        menu.Items.Add(new MenuFlyoutSeparator());
        foreach (var step in new[] { -1.0, -0.5, -0.1, 0.1, 0.5, 1.0 })
        {
            var item = new MenuFlyoutItem { Text = (step > 0 ? "+" : "−") + Math.Abs(step).ToString("0.0", CultureInfo.GetCultureInfo("fr-FR")) + " s" };
            item.Click += (_, _) => set(Math.Round(current() + step, 2));
            menu.Items.Add(item);
        }
        var reset = new MenuFlyoutItem { Text = "Aucun décalage" };
        reset.Click += (_, _) => set(0);
        menu.Items.Add(reset);
        return menu;
    }

    private static readonly (string Code, string Name)[] SubtitleLanguages =
    [
        ("fre", "Français"), ("eng", "Anglais"), ("spa", "Espagnol"), ("ger", "Allemand"), ("ita", "Italien"),
        ("por", "Portugais"), ("dut", "Néerlandais"), ("jpn", "Japonais"), ("ara", "Arabe"),
    ];

    /// <summary>Recherche de sous-titres par les fournisseurs du serveur, puis affichage immédiat.</summary>
    private async Task SearchSubtitlesAsync()
    {
        if (_plan is not { } plan || Content.XamlRoot is not { } root) return;
        ShowControls(autoHide: false);
        var language = new ComboBox { MinWidth = 180 };
        foreach (var (code, name) in SubtitleLanguages) language.Items.Add(name);
        var preferred = Array.FindIndex(SubtitleLanguages, l => l.Code == (AppServices.Settings.SubtitleLanguage ?? "fre"));
        language.SelectedIndex = preferred < 0 ? 0 : preferred;
        var results = new StackPanel { Spacing = 6 };
        var status = new TextBlock { Style = OptiFin.App.Controls.Ui.StyleOf("OFCaption"), TextWrapping = TextWrapping.Wrap };
        var dialog = new ContentDialog
        {
            XamlRoot = root,
            Title = "Rechercher des sous-titres",
            CloseButtonText = "Fermer",
            RequestedTheme = ElementTheme.Dark,
            Content = new StackPanel
            {
                Width = 520,
                Spacing = 12,
                Children =
                {
                    language,
                    status,
                    new ScrollViewer { Content = results, MaxHeight = 360, VerticalScrollBarVisibility = ScrollBarVisibility.Auto },
                },
            },
        };

        async Task SearchAsync()
        {
            results.Children.Clear();
            status.Text = "Recherche…";
            try
            {
                var found = await AppServices.Playback!.SearchSubtitlesAsync(plan.ItemId, SubtitleLanguages[language.SelectedIndex].Code);
                status.Text = found.Count == 0 ? "Aucun sous-titre trouvé dans cette langue." : $"{found.Count} résultat{(found.Count > 1 ? "s" : "")}";
                foreach (var subtitle in found.Take(40))
                {
                    var row = new Button
                    {
                        HorizontalAlignment = HorizontalAlignment.Stretch,
                        HorizontalContentAlignment = HorizontalAlignment.Left,
                        CornerRadius = new CornerRadius(10),
                        Padding = new Thickness(12, 8, 12, 8),
                        Content = new StackPanel
                        {
                            Children =
                            {
                                new TextBlock { Text = subtitle.Name, TextWrapping = TextWrapping.Wrap, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold },
                                new TextBlock { Text = subtitle.Details, Style = OptiFin.App.Controls.Ui.StyleOf("OFCaption") },
                            },
                        },
                    };
                    row.Click += async (_, _) =>
                    {
                        status.Text = $"Téléchargement de « {subtitle.Name} »…";
                        results.IsHitTestVisible = false;
                        try
                        {
                            await DownloadSubtitleAsync(subtitle);
                            dialog.Hide();
                        }
                        catch (Exception e)
                        {
                            status.Text = e is ApiException api ? api.UserMessage : e.Message;
                            results.IsHitTestVisible = true;
                        }
                    };
                    results.Children.Add(row);
                }
            }
            catch (ApiException e)
            {
                status.Text = e.UserMessage;
            }
        }

        language.SelectionChanged += (_, _) => _ = SearchAsync();
        _ = SearchAsync();
        await dialog.ShowAsync();
        ScheduleHide();
    }

    private async Task DownloadSubtitleAsync(RemoteSubtitle subtitle)
    {
        if (_plan is not { } plan) return;
        await AppServices.Playback!.DownloadSubtitleAsync(plan.ItemId, subtitle.Id);
        var known = plan.SubtitleTracks.Select(t => t.Index).ToHashSet();
        MediaTrack? added = null;
        PlaybackPlan? refreshed = null;
        // Le serveur enregistre le fichier puis rafraîchit l'élément : quelques essais.
        for (var attempt = 0; attempt < 3 && added is null; attempt++)
        {
            if (attempt > 0) await Task.Delay(2000);
            refreshed = await AppServices.Playback!.PrepareAsync(plan.ItemId, _position, plan.AudioIndex, plan.SubtitleIndex,
                plan.Method == PlayMethod.Transcode, AppServices.Settings.EffectiveMaxBitrate, plan.MediaSourceId);
            added = refreshed.SubtitleTracks.FirstOrDefault(t => !known.Contains(t.Index));
        }
        if (added is null || refreshed is null) throw new InvalidOperationException("Le serveur n’a pas encore ajouté ce sous-titre. Réessayez.");
        AppLog.Info("player", $"Sous-titre téléchargé : {added.Label}");
        _plan = _plan! with { SubtitleTracks = refreshed.SubtitleTracks };
        await SwitchTrackAsync(TrackType.Subtitle, added);
    }

    private void ShowSettingsMenu()
    {
        var menu = new MenuFlyout();
        var speed = new MenuFlyoutSubItem { Text = "Vitesse" };
        foreach (var s in new[] { 0.5, 0.75, 1.0, 1.25, 1.5, 2.0 })
        {
            var item = new MenuFlyoutItem { Text = s == 1 ? "Normale" : $"{s.ToString("0.##", CultureInfo.GetCultureInfo("fr-FR"))}×" };
            item.Click += (_, _) => _mpv?.SetSpeed(s);
            speed.Items.Add(item);
        }
        menu.Items.Add(speed);
        if (_extras.Chapters.Count > 0)
        {
            var chapters = new MenuFlyoutSubItem { Text = "Chapitres" };
            foreach (var c in _extras.Chapters)
            {
                var item = new MenuFlyoutItem { Text = $"{MediaFormat.Clock(c.Start)}  {c.Name}" };
                item.Click += (_, _) => UserSeek(c.Start);
                chapters.Items.Add(item);
            }
            menu.Items.Add(chapters);
        }
        var size = new MenuFlyoutSubItem { Text = "Taille des sous-titres" };
        foreach (var scale in new[] { 0.8, 1.0, 1.2, 1.5 })
        {
            var item = new ToggleMenuFlyoutItem { Text = $"{scale * 100:0} %", IsChecked = Math.Abs(AppServices.Settings.SubtitleScale - scale) < 0.01 };
            item.Click += (_, _) =>
            {
                AppServices.Settings.SubtitleScale = scale;
                AppServices.SaveSettings();
                ApplySubtitleStyle();
            };
            size.Items.Add(item);
        }
        menu.Items.Add(size);
        var background = new MenuFlyoutSubItem { Text = "Fond des sous-titres" };
        foreach (var (mode, label) in new[] { (SubtitleBackground.None, "Contour"), (SubtitleBackground.Shadow, "Ombre"), (SubtitleBackground.Box, "Bandeau") })
        {
            var item = new ToggleMenuFlyoutItem { Text = label, IsChecked = AppServices.Settings.SubtitleBackground == mode };
            item.Click += (_, _) =>
            {
                AppServices.Settings.SubtitleBackground = mode;
                AppServices.SaveSettings();
                ApplySubtitleStyle();
            };
            background.Items.Add(item);
        }
        menu.Items.Add(background);

        // Synchronisation : décalage des sous-titres et du son (comme sur mobile).
        var sync = new MenuFlyoutSubItem { Text = "Synchronisation" };
        sync.Items.Add(DelayMenu("Décalage des sous-titres", "Positif : les sous-titres apparaissent plus tard.", () => _subtitleDelay, d =>
        {
            _subtitleDelay = d;
            _mpv?.TrySet("sub-delay", d.ToString("0.###", CultureInfo.InvariantCulture));
        }));
        sync.Items.Add(DelayMenu("Décalage du son", "Positif : le son est retardé.", () => _audioDelay, d =>
        {
            _audioDelay = d;
            _mpv?.TrySet("audio-delay", d.ToString("0.###", CultureInfo.InvariantCulture));
        }));
        menu.Items.Add(sync);
        var online = new MenuFlyoutItem { Text = "Rechercher des sous-titres en ligne…", IsEnabled = _plan != null };
        online.Click += (_, _) => _ = SearchSubtitlesAsync();
        menu.Items.Add(online);
        menu.Items.Add(new MenuFlyoutSeparator());
        var transcode = new MenuFlyoutItem { Text = "Lire via le serveur (transcodage)", IsEnabled = _plan?.Method == PlayMethod.DirectPlay };
        transcode.Click += (_, _) =>
        {
            _transcodeTried = true;
            _ = StartAsync(_item, _position, forceTranscode: true);
        };
        menu.Items.Add(transcode);
        var stats = new ToggleMenuFlyoutItem { Text = "Infos de lecture", IsChecked = _stats };
        stats.Click += (_, _) => ToggleStats(stats.IsChecked);
        menu.Items.Add(stats);
        menu.ShowAt(SettingsButton);
        ShowControls(autoHide: false);
        menu.Closed += (_, _) => ScheduleHide();
    }

    private void ApplySubtitleStyle()
    {
        if (_mpv is null) return;
        var s = AppServices.Settings;
        _mpv.TrySet("sub-scale", s.SubtitleScale.ToString("0.00", CultureInfo.InvariantCulture));
        switch (s.SubtitleBackground)
        {
            case SubtitleBackground.Box:
                _mpv.TrySet("sub-border-style", "opaque-box");
                _mpv.TrySet("sub-back-color", "#99000000");
                break;
            case SubtitleBackground.Shadow:
                _mpv.TrySet("sub-border-style", "outline-and-shadow");
                _mpv.TrySet("sub-border-size", "1.5");
                _mpv.TrySet("sub-shadow-offset", "2");
                break;
            default:
                _mpv.TrySet("sub-border-style", "outline-and-shadow");
                _mpv.TrySet("sub-border-size", "2.5");
                _mpv.TrySet("sub-shadow-offset", "0");
                break;
        }
    }

    // ------------------------------------------------------------ États

    private void SetTitles(MediaItem item)
    {
        if (item.Kind == MediaKind.Episode)
        {
            TitleText.Text = item.SeriesName ?? item.Name;
            SubtitleText.Text = string.Join(" · ", new[] { item.EpisodeLabel, item.Name }.Where(s => !string.IsNullOrEmpty(s)));
        }
        else
        {
            TitleText.Text = item.Name;
            SubtitleText.Text = item.Year?.ToString() ?? "";
        }
        Title = item.Name;
    }

    private void ShowPreparing(string? notice)
    {
        SetOverlayVisible(true);
        Preparing.Visibility = Visibility.Visible;
        ErrorPanel.Visibility = Visibility.Collapsed;
        Notice.Text = notice ?? "";
    }

    private void ShowError(string message, string? detail)
    {
        _startupTimer.Stop();
        Preparing.Visibility = Visibility.Collapsed;
        SetOverlayVisible(true);
        ErrorText.Text = message;
        ErrorDetail.Text = AppServices.Settings.DebugMode ? detail ?? "" : "";
        ErrorPanel.Visibility = Visibility.Visible;
        Root.ProtectedCursorReset();
        _video.Show(false);
    }

    private void OnMediaButton(Windows.Media.SystemMediaTransportControlsButton button)
    {
        switch (button)
        {
            case Windows.Media.SystemMediaTransportControlsButton.Play: if (_paused) TogglePlay(); break;
            case Windows.Media.SystemMediaTransportControlsButton.Pause: if (!_paused) TogglePlay(); break;
            case Windows.Media.SystemMediaTransportControlsButton.Next when _extras.NextEpisode is { } next: _ = PlayNextAsync(next); break;
            case Windows.Media.SystemMediaTransportControlsButton.Previous: SeekBy(-10); break;
        }
    }

    private void Shutdown()
    {
        if (_closing) return;
        _closing = true;
        MediaSession.ButtonPressed -= OnMediaButton;
        WatchParty.CommandReceived -= OnPartyCommand;
        WatchParty.StateReceived -= OnPartyState;
        WatchParty.Changed -= UpdatePartyBadge;
        _syncTimer.Stop();
        _hideTimer.Stop();
        _cursorTimer.Stop();
        _overlayTimer.Stop();
        _statsTimer.Stop();
        Win32.SetCursorHidden(false);
        _reportTimer.Stop();
        _startupTimer.Stop();
        Win32.SetThreadExecutionState(Win32.ES_CONTINUOUS);
        MediaSession.Clear();
        var plan = _plan;
        var position = _position;
        var mpv = _mpv;
        _mpv = null;
        mpv?.Pause();
        _video.Show(false);
        // Rapport final et libération de mpv en arrière-plan : la fenêtre se ferme tout de suite.
        _ = Task.Run(async () =>
        {
            if (plan != null && _started) await AppServices.Playback!.ReportStoppedAsync(plan, position);
            mpv?.Dispose();
            Nav.Ui(() =>
            {
                _video.Dispose();
                PlayerLauncher.OnClosed();
            });
        });
    }
}

internal static class CursorExtensions
{
    /// <summary>Masque le curseur au-dessus de la vidéo (contrôles masqués) ; il revient au moindre mouvement.</summary>
    public static void HideCursor(this Grid _) => Win32.SetCursorHidden(true);

    public static void ProtectedCursorReset(this Grid _) => Win32.SetCursorHidden(false);
}
