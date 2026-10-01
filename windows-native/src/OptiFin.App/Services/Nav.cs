using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Animation;

namespace OptiFin.App.Services;

/// <summary>
/// Navigation : un cadre racine (connexion ou coquille) et, une fois connecté, le cadre de contenu
/// de la coquille (accueil, bibliothèques, fiches…).
/// </summary>
public static class Nav
{
    public static MainWindow Window { get; private set; } = null!;
    public static Frame RootFrame { get; private set; } = null!;
    public static Frame? ContentFrame { get; set; }
    public static DispatcherQueue Dispatcher { get; private set; } = null!;

    public static event Action? ContentNavigated;

    public static void Attach(MainWindow window, Frame root)
    {
        Window = window;
        RootFrame = root;
        Dispatcher = DispatcherQueue.GetForCurrentThread();
    }

    public static void Root(Type page, object? parameter = null)
    {
        RootFrame.Navigate(page, parameter, new DrillInNavigationTransitionInfo());
        RootFrame.BackStack.Clear();
    }

    public static void PushRoot(Type page, object? parameter = null) =>
        RootFrame.Navigate(page, parameter, new SlideNavigationTransitionInfo { Effect = SlideNavigationTransitionEffect.FromRight });

    public static void Go(Type page, object? parameter = null)
    {
        if (ContentFrame is null) return;
        ContentFrame.Navigate(page, parameter, new DrillInNavigationTransitionInfo());
        ContentNavigated?.Invoke();
    }

    /// <summary>Rubrique de la barre latérale : remplace l'historique.</summary>
    public static void Section(Type page, object? parameter = null)
    {
        if (ContentFrame is null) return;
        ContentFrame.Navigate(page, parameter, new EntranceNavigationTransitionInfo());
        ContentFrame.BackStack.Clear();
        ContentNavigated?.Invoke();
    }

    public static bool CanGoBack => ContentFrame?.CanGoBack == true || RootFrame.CanGoBack;

    public static bool Back()
    {
        if (ContentFrame?.CanGoBack == true)
        {
            ContentFrame.GoBack();
            ContentNavigated?.Invoke();
            return true;
        }
        if (RootFrame.CanGoBack)
        {
            RootFrame.GoBack();
            return true;
        }
        return false;
    }

    public static void Ui(Action action)
    {
        if (Dispatcher.HasThreadAccess) action();
        else Dispatcher.TryEnqueue(() => action());
    }
}
