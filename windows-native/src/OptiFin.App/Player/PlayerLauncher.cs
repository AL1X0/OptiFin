using Microsoft.UI.Windowing;
using OptiFin.App.Services;
using OptiFin.Core.Logging;
using OptiFin.Core.Media;

namespace OptiFin.App.Player;

/// <summary>Ouvre le lecteur par-dessus la fenêtre principale (masquée pendant la lecture).</summary>
public static class PlayerLauncher
{
    private static PlayerWindow? _current;

    /// <summary>Lecteur fermé : les pages rafraîchissent progression et « Reprendre ».</summary>
    public static event Action? Closed;

    public static void Play(MediaItem item, bool fromStart = false)
    {
        if (AppServices.Playback is null) return;
        try
        {
            _current?.Close();
            var main = Nav.Window.AppWindow;
            var player = new PlayerWindow(item, fromStart);
            _current = player;
            player.ShowOver(main);
            main.Hide();
        }
        catch (Exception e)
        {
            AppLog.Error("player", "Ouverture du lecteur impossible", e);
            Nav.Window.AppWindow.Show();
        }
    }

    internal static void OnClosed()
    {
        _current = null;
        var main = Nav.Window.AppWindow;
        main.Show();
        Nav.Window.Activate();
        Closed?.Invoke();
    }
}
