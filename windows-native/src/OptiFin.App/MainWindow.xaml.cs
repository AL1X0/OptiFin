using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using OptiFin.App.Pages;
using OptiFin.App.Services;
using OptiFin.Core.Logging;
using Windows.Graphics;

namespace OptiFin.App;

public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        Nav.Attach(this, RootFrame);

        // Barre de titre fondue dans le fond noir, boutons de Windows en blanc.
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(TitleBar);
        var bar = AppWindow.TitleBar;
        bar.PreferredHeightOption = TitleBarHeightOption.Tall;
        bar.ButtonBackgroundColor = Colors.Transparent;
        bar.ButtonInactiveBackgroundColor = Colors.Transparent;
        bar.ButtonForegroundColor = Colors.White;
        bar.ButtonInactiveForegroundColor = Windows.UI.Color.FromArgb(0x99, 0xFF, 0xFF, 0xFF);
        bar.ButtonHoverBackgroundColor = Windows.UI.Color.FromArgb(0x1F, 0xFF, 0xFF, 0xFF);
        bar.ButtonPressedBackgroundColor = Windows.UI.Color.FromArgb(0x33, 0xFF, 0xFF, 0xFF);
        AppWindow.SetIcon(Path.Combine(AppContext.BaseDirectory, "Assets", "OptiFin.ico"));

        if (AppWindow.Presenter is OverlappedPresenter presenter)
        {
            presenter.PreferredMinimumWidth = 960;
            presenter.PreferredMinimumHeight = 600;
        }
        WindowPlacement.Restore(AppWindow);
        AppWindow.Closing += (_, _) => WindowPlacement.Save(AppWindow);

        AppServices.SessionChanged += ShowStart;
        AppServices.SessionLost += () => DispatcherQueue.TryEnqueue(ShowStart);
        ShowStart();
        DevCapture.AttachIfRequested(this, Root);
    }

    /// <summary>Accueil si une session existe, sinon l'écran de connexion.</summary>
    private void ShowStart()
    {
        if (AppServices.Session is null)
        {
            Nav.Root(typeof(ConnectPage));
        }
        else
        {
            Nav.Root(typeof(ShellPage));
        }
    }
}

/// <summary>Taille, position et état (agrandie) de la fenêtre, retenus d'un lancement à l'autre.</summary>
internal static class WindowPlacement
{
    private static string FilePath => Path.Combine(AppLog.Directory, "window.txt");

    public static void Restore(AppWindow window)
    {
        try
        {
            var parts = File.ReadAllText(FilePath).Split(';').Select(int.Parse).ToArray();
            if (parts.Length < 5) throw new FormatException();
            var rect = new RectInt32(parts[0], parts[1], parts[2], parts[3]);
            // Écran débranché depuis : position par défaut.
            var area = DisplayArea.GetFromRect(rect, DisplayAreaFallback.None);
            if (area is null) throw new InvalidOperationException();
            window.MoveAndResize(rect);
            if (parts[4] == 1 && window.Presenter is OverlappedPresenter p) p.Maximize();
        }
        catch
        {
            var area = DisplayArea.Primary.WorkArea;
            var width = Math.Min(1440, area.Width - 80);
            var height = Math.Min(900, area.Height - 80);
            window.MoveAndResize(new RectInt32(area.X + (area.Width - width) / 2, area.Y + (area.Height - height) / 2, width, height));
        }
    }

    public static void Save(AppWindow window)
    {
        try
        {
            var maximized = window.Presenter is OverlappedPresenter { State: OverlappedPresenterState.Maximized };
            if (maximized && File.Exists(FilePath))
            {
                // Agrandie : on garde la taille « normale » précédente.
                var parts = File.ReadAllText(FilePath).Split(';');
                parts[4] = "1";
                File.WriteAllText(FilePath, string.Join(';', parts));
                return;
            }
            var p = window.Position;
            var s = window.Size;
            Directory.CreateDirectory(AppLog.Directory);
            File.WriteAllText(FilePath, $"{p.X};{p.Y};{s.Width};{s.Height};{(maximized ? 1 : 0)}");
        }
        catch
        {
        }
    }
}
