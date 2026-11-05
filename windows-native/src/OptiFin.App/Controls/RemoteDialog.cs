using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using OptiFin.App.Services;
using OptiFin.Core.Api;
using OptiFin.Core.Localization;
using OptiFin.Core.Logging;
using OptiFin.Core.Media;
using OptiFin.Core.Remote;

namespace OptiFin.App.Controls;

/// <summary>« Lire sur… » : choix de l'appareil, lancement du titre, puis télécommande de sa lecture.</summary>
public static class RemoteDialog
{
    /// <summary>Menu des appareils ; une série lance l'épisode à suivre.</summary>
    public static async Task ShowMenuAsync(FrameworkElement anchor, MediaItem item)
    {
        if (AppServices.Media is not { } media || AppServices.Client is not { } client) return;
        var remote = new RemoteControlClient(client, media.UserId);
        var menu = new MenuFlyout();
        try
        {
            var devices = await remote.DevicesAsync();
            if (devices.Count == 0)
                menu.Items.Add(new MenuFlyoutItem { Text = L.T("Aucun autre appareil disponible. Ouvrez OptiFin ou Jellyfin sur l’autre écran, puis réessayez."), IsEnabled = false });
            foreach (var device in devices)
            {
                var entry = new MenuFlyoutItem { Text = device.Client is { } c ? $"{device.Name} · {c}" : device.Name };
                entry.Click += async (_, _) =>
                {
                    try
                    {
                        var target = item.Kind == MediaKind.Series ? await media.NextUpForAsync(item.Id) ?? item : item;
                        await remote.PlayAsync(device.SessionId, target.Id, target.ResumePosition);
                        await ShowAsync(anchor.XamlRoot, remote, device, target.Name);
                    }
                    catch (ApiException e)
                    {
                        AppLog.Warn("remote", e.UserMessage);
                    }
                };
                menu.Items.Add(entry);
            }
        }
        catch (ApiException e)
        {
            menu.Items.Add(new MenuFlyoutItem { Text = e.UserMessage, IsEnabled = false });
        }
        menu.ShowAt(anchor);
    }

    private static async Task ShowAsync(XamlRoot root, RemoteControlClient remote, RemoteDevice device, string title)
    {
        var current = device;
        var name = new TextBlock { Text = title, Style = Ui.StyleOf("OFTitle2"), TextWrapping = TextWrapping.Wrap };
        var time = new TextBlock { Style = Ui.StyleOf("OFCaption") };
        var bar = new ProgressBar { Maximum = 100 };
        var playIcon = new FontIcon { Glyph = "", FontSize = 22 };
        Button Control(object content, string tip, Action click)
        {
            var button = new Button { Content = content, Width = 64, Height = 56, CornerRadius = new CornerRadius(14) };
            ToolTipService.SetToolTip(button, tip);
            button.Click += (_, _) => click();
            return button;
        }
        async void Send(Func<Task> command)
        {
            try
            {
                await command();
            }
            catch (ApiException e)
            {
                time.Text = e.UserMessage;
            }
        }
        var id = device.SessionId;
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10, HorizontalAlignment = HorizontalAlignment.Center };
        buttons.Children.Add(Control(new FontIcon { Glyph = "", FontSize = 20 }, L.T("Reculer de 10 s"), () => Send(() => remote.SeekAsync(id, Max(current.Position - TimeSpan.FromSeconds(10))))));
        buttons.Children.Add(Control(playIcon, L.T("Lecture / pause"), () => Send(() => current.Paused ? remote.UnpauseAsync(id) : remote.PauseAsync(id))));
        buttons.Children.Add(Control(new FontIcon { Glyph = "", FontSize = 20 }, L.T("Avancer de 10 s"), () => Send(() => remote.SeekAsync(id, current.Position + TimeSpan.FromSeconds(10)))));
        buttons.Children.Add(Control(new FontIcon { Glyph = "", FontSize = 20 }, L.T("Arrêter"), () => Send(() => remote.StopAsync(id))));

        var body = new StackPanel { Spacing = 14, Width = 380 };
        body.Children.Add(name);
        body.Children.Add(bar);
        body.Children.Add(time);
        body.Children.Add(buttons);
        var dialog = new ContentDialog
        {
            XamlRoot = root,
            Title = L.F("Sur {0}", device.Name),
            Content = body,
            CloseButtonText = L.T("Fermer"),
            RequestedTheme = ElementTheme.Dark,
        };

        var timer = Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread().CreateTimer();
        timer.Interval = TimeSpan.FromSeconds(2);
        timer.Tick += async (_, _) =>
        {
            try
            {
                if ((await remote.DevicesAsync()).FirstOrDefault(d => d.SessionId == id) is not { } now) return;
                current = now;
                if (now.NowPlaying is { } playing) name.Text = playing;
                playIcon.Glyph = now.Paused ? "" : "";
                if (now.Runtime is { Ticks: > 0 } total)
                {
                    bar.Value = 100.0 * now.Position.Ticks / total.Ticks;
                    time.Text = $"{MediaFormat.Clock(now.Position)} / {MediaFormat.Clock(total)}";
                }
            }
            catch (ApiException e)
            {
                AppLog.Debug("remote", e.UserMessage);
            }
        };
        timer.Start();
        await dialog.ShowAsync();
        timer.Stop();
    }

    private static TimeSpan Max(TimeSpan t) => t < TimeSpan.Zero ? TimeSpan.Zero : t;
}
