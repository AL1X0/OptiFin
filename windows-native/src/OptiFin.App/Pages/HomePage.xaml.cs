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

    public HomePage()
    {
        InitializeComponent();
        RetryButton.Click += (_, _) => _ = LoadAsync();
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
        Spinner.IsActive = !quiet;
        try
        {
            await foreach (var data in home.WatchAsync(ct))
            {
                Render(data);
                _loaded = true;
                Spinner.IsActive = false;
            }
        }
        catch (OperationCanceledException)
        {
        }
        catch (Exception e)
        {
            Spinner.IsActive = false;
            if (_loaded) return;
            ErrorText.Text = e is ApiException api ? api.UserMessage : "L’accueil n’a pas pu être chargé.";
            ErrorPanel.Visibility = Visibility.Visible;
            AppLog.Error("home", "Accueil indisponible", e);
        }
    }

    private void Render(HomeData data)
    {
        var offset = Scroll.VerticalOffset;
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
