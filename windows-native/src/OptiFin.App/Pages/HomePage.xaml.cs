using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using OptiFin.App.Controls;
using OptiFin.App.Services;
using OptiFin.Core.Api;
using OptiFin.Core.Logging;
using OptiFin.Core.Media;

namespace OptiFin.App.Pages;

/// <summary>Accueil : carrousel à la une puis rangées (Reprendre, À suivre, ajouts récents, favoris).</summary>
public sealed partial class HomePage : Page
{
    public const double Gutter = 48;
    private CancellationTokenSource? _cts;
    private bool _loaded;
    private string? _rendered;

    public HomePage()
    {
        InitializeComponent();
        RetryButton.Click += (_, _) => _ = LoadAsync();
        Nav.TrackScroll(Scroll);
        // Retour du lecteur : « Reprendre » et progression mis à jour une fois la position enregistrée.
        void Refresh() => _ = LoadAsync(quiet: _loaded);
        Loaded += (_, _) => Player.PlayerLauncher.Closed += Refresh;
        Unloaded += (_, _) => Player.PlayerLauncher.Closed -= Refresh;
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        // Retour sur l'accueil : progression et « Reprendre » rafraîchis sans tout redessiner.
        _ = LoadAsync(quiet: _loaded);
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e) => _cts?.Cancel();

    private async Task LoadAsync(bool quiet = false)
    {
        if (AppServices.Home is not { } home) return;
        _cts?.Cancel();
        _cts = new CancellationTokenSource();
        var ct = _cts.Token;
        ErrorPanel.Visibility = Visibility.Collapsed;
        if (!quiet && !_loaded) ShowSkeleton();
        try
        {
            await foreach (var data in home.WatchAsync(ct))
            {
                Render(data);
                _loaded = true;
            }
        }
        catch (OperationCanceledException)
        {
        }
        catch (Exception e)
        {
            if (_loaded) return;
            Body.Children.Clear();
            ErrorText.Text = e is ApiException api ? api.UserMessage : "L’accueil n’a pas pu être chargé.";
            ErrorPanel.Visibility = Visibility.Visible;
            AppLog.Error("home", "Accueil indisponible", e);
        }
    }

    /// <summary>Squelette de l'accueil (carrousel et deux rangées) qui pulse pendant le premier chargement.</summary>
    private void ShowSkeleton()
    {
        Body.ChildrenTransitions = null;
        Body.Children.Clear();
        var hero = new StackPanel { Height = 620, Spacing = 16, Padding = new Thickness(Gutter, 0, Gutter, 64), VerticalAlignment = VerticalAlignment.Bottom };
        var heroContent = new StackPanel { Spacing = 16, VerticalAlignment = VerticalAlignment.Bottom, Margin = new Thickness(0, 300, 0, 0) };
        heroContent.Children.Add(Ui.Skeleton(380, 96, 14));
        heroContent.Children.Add(Ui.Skeleton(220, 14, 7));
        heroContent.Children.Add(Ui.Skeleton(560, 14, 7));
        heroContent.Children.Add(Ui.Skeleton(480, 14, 7));
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 12, Margin = new Thickness(0, 8, 0, 0) };
        buttons.Children.Add(Ui.Skeleton(132, 44, 22));
        buttons.Children.Add(Ui.Skeleton(112, 44, 22));
        heroContent.Children.Add(buttons);
        hero.Children.Add(heroContent);
        Body.Children.Add(hero);
        foreach (var style in new[] { CardStyle.Landscape, CardStyle.Poster })
        {
            var row = new StackPanel { Spacing = 16, Padding = new Thickness(Gutter, 0, 0, 0) };
            row.Children.Add(Ui.Skeleton(180, 22, 8));
            var cards = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 16 };
            var width = MediaRow.CardWidth(style);
            for (var i = 0; i < 9; i++)
                cards.Children.Add(Ui.Skeleton(width, style == CardStyle.Landscape ? width * 9 / 16 : width * 1.5));
            row.Children.Add(cards);
            Body.Children.Add(row);
        }
    }

    /// <summary>Empreinte du contenu affiché : un rafraîchissement identique ne redessine rien.</summary>
    private static string Signature(HomeData data) => string.Join('|',
        data.Featured.Select(i => i.Id).Concat(data.Sections.SelectMany(s =>
            s.Items.Select(i => $"{s.Title}:{i.Id}:{i.User.Progress:F3}:{i.User.Played}:{i.User.Favorite}"))));

    private void Render(HomeData data)
    {
        var signature = Signature(data);
        if (signature == _rendered) return;
        var first = _rendered is null;
        _rendered = signature;
        var offset = Scroll.VerticalOffset;
        // Première apparition : carrousel et rangées arrivent en cascade. Ensuite, mise à jour sans animation.
        Body.ChildrenTransitions = first ? Ui.Entrance(vertical: 60) : null;
        Body.Children.Clear();
        if (data.Featured.Count > 0) Body.Children.Add(new FeaturedCarousel(data.Featured));
        else Body.Children.Add(new Border { Height = 64 });
        foreach (var section in data.Sections)
        {
            var style = section.Landscape ? CardStyle.Landscape : CardStyle.Poster;
            var row = new MediaRow(section.Title, section.Items, style, Gutter, seeAll: section.LibraryId != null);
            row.ItemActivated += Open;
            if (section.LibraryId is { } libraryId)
            {
                var library = data.Libraries.FirstOrDefault(l => l.Id == libraryId);
                if (library != null) row.SeeAll += () => Nav.Go(typeof(LibraryPage), library);
            }
            Body.Children.Add(row);
        }
        if (data.Sections.Count == 0 && data.Featured.Count == 0)
        {
            Body.Children.Add(new TextBlock
            {
                Text = "Vos bibliothèques sont vides pour l’instant.",
                Style = Ui.StyleOf("OFBody"),
                Margin = new Thickness(Gutter, 80, Gutter, 0),
            });
        }
        Scroll.UpdateLayout();
        Scroll.ChangeView(null, offset, null, disableAnimation: true);
    }

    public static void Open(MediaItem item) => Nav.Go(typeof(DetailsPage), item);
}
