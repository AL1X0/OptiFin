using System.Diagnostics;
using System.Text;
using Microsoft.UI.Xaml.Controls;
using OptiFin.App.Services;
using OptiFin.Core.Logging;
using Windows.ApplicationModel.DataTransfer;
using OptiFin.Core.Localization;

namespace OptiFin.App.Pages;

/// <summary>Journaux : lecture, copie, envoi au serveur Jellyfin (Tableau de bord › Journaux).</summary>
public sealed partial class LogsPage : Page
{
    public LogsPage()
    {
        InitializeComponent();
        OptiFin.App.Controls.Ui.Translate(this);
        Text.Text = AppLog.Export();
        Text.Loaded += (_, _) => Text.Select(Text.Text.Length, 0);
        CopyButton.Click += (_, _) =>
        {
            var package = new DataPackage();
            package.SetText(AppLog.Export());
            Clipboard.SetContent(package);
            Status.Text = L.T("Copié dans le presse-papiers.");
        };
        FolderButton.Click += (_, _) =>
        {
            Directory.CreateDirectory(AppLog.Directory);
            Process.Start(new ProcessStartInfo(AppLog.Directory) { UseShellExecute = true });
        };
        SendButton.Click += async (_, _) =>
        {
            if (AppServices.Client is not { } client) return;
            SendButton.IsEnabled = false;
            try
            {
                using var content = new StringContent(AppLog.Export(), Encoding.UTF8, "text/plain");
                await client.PostAsync("ClientLog/Document", content);
                Status.Text = L.T("Envoyé au serveur (Tableau de bord › Journaux).");
            }
            catch (Exception e)
            {
                Status.Text = L.T("Envoi impossible (serveur hors ligne ou envoi désactivé).");
                AppLog.Warn("log", $"Envoi du journal impossible : {e.Message}");
            }
            finally
            {
                SendButton.IsEnabled = true;
            }
        };
    }
}
