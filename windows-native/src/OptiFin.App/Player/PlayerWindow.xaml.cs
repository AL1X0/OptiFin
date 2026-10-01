using System.Globalization;
using Microsoft.UI;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Input;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using OptiFin.App.Services;
using OptiFin.Core.Api;
using OptiFin.Core.Logging;
using OptiFin.Core.Media;
using OptiFin.Core.Playback;
using OptiFin.Core.Settings;
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

    public PlayerWindow(MediaItem item, bool fromStart)
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
        // Opacité de la fenêtre au niveau de Windows : sur certains PC, le fond « transparent » du XAML
        // reste opaque et masque la vidéo (écran noir, son seul). Commandes masquées, la fenêtre devient
        // quasi invisible (1/255, elle reçoit toujours souris et clavier) : la vidéo est toujours visible.
        Win32.SetWindowLongPtr(_hwnd, Win32.GWL_EXSTYLE, Win32.GetWindowLongPtr(_hwnd, Win32.GWL_EXSTYLE) | Win32.WS_EX_LAYERED);
        SetOverlayVisible(true);
        AppWindow.Changed += (_, e) =>
        {
            if (e.DidPositionChange || e.DidSizeChange || e.DidVisibilityChange) SyncVideo();
        };

        var dispatcher = DispatcherQueue.GetForCurrentThread();
        _hideTimer = Timer(dispatcher, TimeSpan.FromSeconds(3), HideControls);
        _reportTimer = Timer(dispatcher, TimeSpan.FromSeconds(10), () =>
        {
            if (_plan != null && _started) _ = AppServices.Playback!.ReportProgressAsync(_plan, _position, _paused);
        }, repeating: true);
        _startupTimer = Timer(dispatcher, TimeSpan.FromSeconds(30), () => _ = OnStartupFailureAsync("aucune image après 30 s"));
        _overlayTimer = Timer(dispatcher, TimeSpan.FromMilliseconds(300), () =>
        {
            if (Controls.Opacity == 0 && Preparing.Visibility == Visibility.Collapsed && ErrorPanel.Visibility == Visibility.Collapsed)
                SetOverlayVisible(false);
        });
        _levelTimer = Timer(dispatcher, TimeSpan.FromMilliseconds(900), () => Level.Opacity = 0);

        WireControls();
        MediaSession.Attach(_hwnd);
        MediaSession.ButtonPressed += OnMediaButton;
        Closed += (_, _) => Shutdown();
        _startPosition = fromStart ? TimeSpan.Zero : item.ResumePosition;
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
        Activate();
        SyncVideo();
        _video.Show(true);
    }

    private void SyncVideo()
    {
        if (!AppWindow.IsVisible)
        {
            _video.Show(false);
            return;
        }
        var pos = AppWindow.Position;
        var size = AppWindow.Size;
        _video.Place(pos.X, pos.Y, size.Width, size.Height, visible: true);
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
        mpv.BufferingChanged += b => Ui(() => Buffering.IsActive = b && _started);
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
        if (_extras.NextEpisode is { } next && AppServices.Settings.AutoPlayNext && !_upNextDismissed)
        {
            _ = PlayNextAsync(next);
            return;
        }
        Close();
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
        if (segment != null && AppServices.Settings.AutoSkipSegments && _autoSkipped.Add(segment))
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
        CloseButton.Click += (_, _) => Close();
        ErrorClose.Click += (_, _) => Close();
        PlayButton.Click += (_, _) => TogglePlay();
        BackButton.Click += (_, _) => SeekBy(-10);
        ForwardButton.Click += (_, _) => SeekBy(10);
        FullscreenButton.Click += (_, _) => ToggleFullscreen();
        SkipButton.Click += (_, _) =>
        {
            if (SkipButton.Tag is MediaSegment s) _mpv?.Seek(s.End);
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
        Root.PointerMoved += (_, _) => ShowControls(autoHide: true);
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
            _mpv?.Seek(At(e.GetCurrentPoint(Scrubber).Position.X));
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
                else Close();
                break;
            case VirtualKey.S when SkipButton.Visibility == Visibility.Visible && SkipButton.Tag is MediaSegment s:
                _mpv?.Seek(s.End);
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
        if (_paused) _mpv.Play();
        else _mpv.Pause();
    }

    private void SeekBy(int seconds)
    {
        if (_mpv is null) return;
        var target = _position + TimeSpan.FromSeconds(seconds);
        _mpv.Seek(target < TimeSpan.Zero ? TimeSpan.Zero : target);
        ShowControls(autoHide: true);
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

    private void SetOverlayVisible(bool visible)
    {
        _overlayVisible = visible;
        Win32.SetLayeredWindowAttributes(_hwnd, 0, visible ? (byte)255 : (byte)1, Win32.LWA_ALPHA);
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
                item.Click += (_, _) => _mpv?.Seek(c.Start);
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
        menu.Items.Add(new MenuFlyoutSeparator());
        var transcode = new MenuFlyoutItem { Text = "Lire via le serveur (transcodage)", IsEnabled = _plan?.Method == PlayMethod.DirectPlay };
        transcode.Click += (_, _) =>
        {
            _transcodeTried = true;
            _ = StartAsync(_item, _position, forceTranscode: true);
        };
        menu.Items.Add(transcode);
        if (AppServices.Settings.DebugMode && _mpv != null && _plan != null)
        {
            menu.Items.Add(new MenuFlyoutItem
            {
                Text = $"{_plan.Method.Label()} · {MpvInfo.Describe(_mpv)} · {_mpv.DroppedFrames} images perdues",
                IsEnabled = false,
            });
        }
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
            case Windows.Media.SystemMediaTransportControlsButton.Play: _mpv?.Play(); break;
            case Windows.Media.SystemMediaTransportControlsButton.Pause: _mpv?.Pause(); break;
            case Windows.Media.SystemMediaTransportControlsButton.Next when _extras.NextEpisode is { } next: _ = PlayNextAsync(next); break;
            case Windows.Media.SystemMediaTransportControlsButton.Previous: SeekBy(-10); break;
        }
    }

    private void Shutdown()
    {
        if (_closing) return;
        _closing = true;
        MediaSession.ButtonPressed -= OnMediaButton;
        _hideTimer.Stop();
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
    public static void HideCursor(this Grid _) => Win32.SetCursor(0);

    public static void ProtectedCursorReset(this Grid _)
    {
    }
}
