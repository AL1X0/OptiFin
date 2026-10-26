using Microsoft.UI.Xaml;
using OptiFin.App.Services;
using OptiFin.Core.Logging;

namespace OptiFin.App;

public partial class App : Application
{
    public const string AppId = "OptiFin.Windows";

    private Window? _window;

    /// <summary>Lancement du processus, en <see cref="Environment.TickCount64"/> (chronos du démarrage).</summary>
    public static readonly long ProcessStarted = Environment.TickCount64 -
        (long)(DateTime.Now - System.Diagnostics.Process.GetCurrentProcess().StartTime).TotalMilliseconds;

    /// <summary>Premier accueil affiché (chrono « depuis le lancement » une seule fois).</summary>
    public static bool HomeShown { get; set; }

    public App()
    {
        // Déjà ouverte : elle revient au premier plan, ce lancement-ci s'arrête là (journal intact).
        if (!Environment.GetCommandLineArgs().Contains("--capture") && !SingleInstance.Claim()) Environment.Exit(0);
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
        // Fenêtre et écran de démarrage d'abord : quelque chose s'affiche avant tout chargement.
        var window = new MainWindow();
        _window = window;
        window.Activate();
        SingleInstance.Listen(window.DispatcherQueue, BringToFront);
        window.AfterFirstFrame(() =>
        {
            AppLog.Timing("app", "Écran de démarrage affiché depuis le lancement du processus", ProcessStarted);
            var loading = Environment.TickCount64;
            AppServices.Initialize();
            AppLog.Info("app", $"Démarrage OptiFin {AppServices.Version} (Windows) — session {(AppServices.Session is null ? "aucune" : "restaurée")}");
            AppLog.Timing("app", "Services prêts", loading);
            window.Start();
            AppLog.Timing("app", "Fenêtre prête", started);
            AppLog.Timing("app", "Fenêtre prête depuis le lancement du processus", ProcessStarted);
            _ = CheckForUpdateAsync();
        });
    }

    /// <summary>Nouveau lancement alors qu'OptiFin est ouverte : le lecteur s'il est ouvert, sinon la fenêtre principale.</summary>
    private void BringToFront()
    {
        if (Player.PlayerLauncher.Current is { } player)
        {
            SingleInstance.BringToFront(WinRT.Interop.WindowNative.GetWindowHandle(player));
            return;
        }
        if (_window is null) return;
        _window.AppWindow.Show();
        SingleInstance.BringToFront(WinRT.Interop.WindowNative.GetWindowHandle(_window));
        _window.Activate();
    }

    /// <summary>
    /// Mise à jour automatique : vérifiée quelques secondes après le démarrage, proposée si une
    /// version plus récente est publiée. Pas pour les builds de développement (version 1.0.0) ni
    /// pendant l'outil de capture.
    /// </summary>
    private async Task CheckForUpdateAsync()
    {
        if (AppUpdater.ByStore || AppServices.Version == "1.0.0" || Environment.GetCommandLineArgs().Contains("--capture")) return;
        await Task.Delay(TimeSpan.FromSeconds(6));
        if (await AppUpdater.CheckAsync() is not { } update || _window?.Content?.XamlRoot is not { } root) return;
        _window.DispatcherQueue.TryEnqueue(() => _ = UpdateDialog.ShowAsync(root, update));
    }
}
