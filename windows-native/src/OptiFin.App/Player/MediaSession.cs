using OptiFin.App.Services;
using OptiFin.Core.Logging;
using OptiFin.Core.Media;
using Windows.Media;
using Windows.Storage.Streams;

namespace OptiFin.App.Player;

/// <summary>
/// Lecture connue de Windows : touches multimédias du clavier, encart de Windows (titre, affiche,
/// lecture/pause, suivant), position.
/// </summary>
public static class MediaSession
{
    private static SystemMediaTransportControls? _smtc;
    private static string? _artworkFor;

    public static event Action<SystemMediaTransportControlsButton>? ButtonPressed;

    public static void Attach(nint hwnd)
    {
        try
        {
            _smtc = SystemMediaTransportControlsInterop.GetForWindow(hwnd);
            _smtc.IsPlayEnabled = true;
            _smtc.IsPauseEnabled = true;
            _smtc.IsNextEnabled = true;
            _smtc.IsPreviousEnabled = true;
            _smtc.ButtonPressed += (_, e) => Nav.Ui(() => ButtonPressed?.Invoke(e.Button));
        }
        catch (Exception e)
        {
            AppLog.Warn("smtc", $"Contrôles multimédias de Windows indisponibles : {e.Message}");
            _smtc = null;
        }
    }

    public static void Update(MediaItem item, bool playing, TimeSpan position, TimeSpan duration)
    {
        if (_smtc is null) return;
        try
        {
            _smtc.IsEnabled = true;
            _smtc.PlaybackStatus = playing ? MediaPlaybackStatus.Playing : MediaPlaybackStatus.Paused;
            var updater = _smtc.DisplayUpdater;
            updater.Type = MediaPlaybackType.Video;
            var episode = item.Kind == MediaKind.Episode;
            updater.VideoProperties.Title = episode ? item.SeriesName ?? item.Name : item.Name;
            updater.VideoProperties.Subtitle = episode ? $"{item.EpisodeLabel} · {item.Name}" : item.Year?.ToString() ?? "";
            if (_artworkFor != item.Id && AppServices.Images?.Maybe(item.Poster ?? item.Primary, 300) is { } url)
            {
                _artworkFor = item.Id;
                updater.Thumbnail = RandomAccessStreamReference.CreateFromUri(url);
            }
            updater.Update();
            _smtc.UpdateTimelineProperties(new SystemMediaTransportControlsTimelineProperties
            {
                StartTime = TimeSpan.Zero,
                MinSeekTime = TimeSpan.Zero,
                Position = position,
                MaxSeekTime = duration,
                EndTime = duration,
            });
        }
        catch (Exception e)
        {
            AppLog.Debug("smtc", e.Message);
        }
    }

    public static void Clear()
    {
        if (_smtc is null) return;
        try
        {
            _smtc.DisplayUpdater.ClearAll();
            _smtc.PlaybackStatus = MediaPlaybackStatus.Closed;
            _smtc.IsEnabled = false;
        }
        catch
        {
        }
        _artworkFor = null;
    }
}
