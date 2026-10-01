using System.Diagnostics;
using System.Net.Http.Headers;
using Microsoft.UI.Xaml.Controls;
using OptiFin.App.Services;
using OptiFin.Core.Logging;
using Windows.ApplicationModel.DataTransfer;

namespace OptiFin.App.Pages;

/// <summary>Journaux : lecture, copie, envoi au serveur Jellyfin (Tableau de bord › Journaux).</summary>
public sealed partial class LogsPage : Page
{
    public LogsPage()
    {
        InitializeComponent();
        Text.Text = AppLog.Export();
        Text.Loaded += (_, _) => Text.Select(Text.Text.Length, 0);
        CopyButton.Click += (_, _) =>
        {
            var package = new DataPackage();
            package.SetText(AppLog.Export());
            Clipboard.SetContent(package);
            Status.Text = "Copié dans le presse-papiers.";
        };
        FolderButton.Click += (_, _) =>
            Process.Start(new ProcessStartInfo(AppLog.Directory) { UseShellExecute = true });
        SendButton.Click += async (_, _) =>
        {
            if (AppServices.Client is not { } client) return;
            try
            {
                var content = new StringContent(AppLog.Export());
                content.Headers.ContentType = new MediaTypeHeaderValue("text/plain");
                await client.PostAsync("ClientLog/Document", content);
                Status.Text = "Envoyé au serveur (Tableau de bord › Journaux).";
            }
            catch (Exception e)
            {
                Status.Text = "Envoi impossible (serveur hors ligne ou envoi désactivé).";
                AppLog.Warn("log", $"Envoi du journal impossible : {e.Message}");
            }
        };
    }
}
