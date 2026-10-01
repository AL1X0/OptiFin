using Microsoft.UI.Windowing;
using OptiFin.App.Services;
using OptiFin.Core.Logging;
using OptiFin.Core.Media;

namespace OptiFin.App.Player;

/// <summary>Ouvre le lecteur par-dessus la fenêtre principale (masquée pendant la lecture).</summary>
public static class PlayerLauncher
{
    private static PlayerWindow? _current;

    /// <summary>Contenu du lecteur ouvert (outil de capture).</summary>
    internal static Microsoft.UI.Xaml.FrameworkElement? CurrentRoot => _current?.Content as Microsoft.UI.Xaml.FrameworkElement;

    /// <summary>Lecteur fermé : les pages rafraîchissent progression et « Reprendre ».</summary>
    public static event Action? Closed;

    public static void Play(MediaItem item, bool fromStart = false)
    {
        if (AppServices.Playback is null) return;
        // En soirée : le titre est lancé pour tout le groupe, le lecteur s'ouvre à réception de la file.
        if (WatchParty.InParty)
        {
            _ = WatchParty.PlayAsync(item, fromStart ? TimeSpan.Zero : item.ResumePosition);
            return;
        }
        Open(item, fromStart, null);
    }

    /// <summary>Titre lancé par la soirée : lecteur ouvert (ou réutilisé) et synchronisé avec le groupe.</summary>
    public static void PlayInParty(MediaItem item, PartyStart party)
    {
        if (AppServices.Playback is null) return;
        if (_current != null)
        {
            _current.JoinParty(item, party);
            return;
        }
        Open(item, false, party);
    }

    private static void Open(MediaItem item, bool fromStart, PartyStart? party)
    {
        try
        {
            _current?.Close();
            var main = Nav.Window.AppWindow;
            var player = new PlayerWindow(item, fromStart, party);
            _current = player;
            player.ShowOver(main);
            // La fenêtre principale disparaît une fois le lecteur apparu en fondu par-dessus.
            var hide = Nav.Dispatcher.CreateTimer();
            hide.Interval = TimeSpan.FromMilliseconds(300);
            hide.IsRepeating = false;
            hide.Tick += (_, _) =>
            {
                if (_current == player) main.Hide();
            };
            hide.Start();
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
        Nav.Window.PlayEntrance();
        main.Show();
        Nav.Window.Activate();
        Closed?.Invoke();
    }
}
