using Microsoft.UI.Xaml;
using OptiFin.App.Services;
using OptiFin.Core.Logging;

namespace OptiFin.App;

public partial class App : Application
{
    public const string AppId = "OptiFin.Windows";

    private Window? _window;

    public App()
    {
        InitializeComponent();
        AppLog.Open();
        // Toute erreur non interceptée finit dans le journal (Réglages › Journaux).
        UnhandledException += (_, e) =>
        {
            AppLog.Error("app", "Erreur non interceptée", e.Exception);
            e.Handled = true;
        };
        AppDomain.CurrentDomain.UnhandledException += (_, e) =>
            AppLog.Error("app", "Erreur fatale", e.ExceptionObject as Exception);
        TaskScheduler.UnobservedTaskException += (_, e) =>
        {
            AppLog.Warn("app", $"Tâche en échec non observée : {e.Exception.InnerException?.Message}");
            e.SetObserved();
        };
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        var started = Environment.TickCount64;
        Player.Win32.SetCurrentProcessExplicitAppUserModelID(AppId);
        AppServices.Initialize();
        AppLog.Info("app", $"Démarrage OptiFin {AppServices.Version} (Windows) — session {(AppServices.Session is null ? "aucune" : "restaurée")}");
        _window = new MainWindow();
        _window.Activate();
        AppLog.Info("app", $"Fenêtre prête en {Environment.TickCount64 - started} ms");
        _ = CheckForUpdateAsync();
    }

    /// <summary>
    /// Mise à jour automatique : vérifiée quelques secondes après le démarrage, proposée si une
    /// version plus récente est publiée. Pas pour les builds de développement (version 1.0.0) ni
    /// pendant l'outil de capture.
    /// </summary>
    private async Task CheckForUpdateAsync()
    {
        if (AppServices.Version == "1.0.0" || Environment.GetCommandLineArgs().Contains("--capture")) return;
        await Task.Delay(TimeSpan.FromSeconds(6));
        if (await AppUpdater.CheckAsync() is not { } update || _window?.Content?.XamlRoot is not { } root) return;
        _window.DispatcherQueue.TryEnqueue(() => _ = UpdateDialog.ShowAsync(root, update));
    }
}
