using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using OptiFin.App.Controls;
using OptiFin.App.Services;
using OptiFin.Core.Api;
using OptiFin.Core.Logging;
using OptiFin.Core.Media;
using OptiFin.Core.Localization;

namespace OptiFin.App.Pages;

/// <summary>Accueil : carrousel à la une puis rangées (Reprendre, À suivre, ajouts récents, favoris).</summary>
public sealed partial class HomePage : Page
{
    public const double Gutter = 48;
    private CancellationTokenSource? _cts;
    private bool _loaded;
    private string? _rendered;
    private string? _featuredSig;
    private FeaturedCarousel? _carousel;
    private Border? _spacer;
    private TextBlock? _emptyText;
    private readonly List<(string Sig, MediaRow Row)> _rows = [];

    public HomePage()
    {
        InitializeComponent();
        OptiFin.App.Controls.Ui.Translate(this);
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
        _cts?.Dispose();
        _cts = new CancellationTokenSource();
        var ct = _cts.Token;
        ErrorPanel.Visibility = Visibility.Collapsed;
        if (!quiet && !_loaded) ShowSkeleton();
        var started = Environment.TickCount64;
        try
        {
            await foreach (var data in home.WatchAsync(ct))
            {
                Render(data);
                _loaded = true;
                AppLog.Timing("home", $"Accueil affiché ({(data.FromCache ? "cache" : "serveur")}{(quiet ? ", retour" : "")})", started);
                if (!App.HomeShown)
                {
                    App.HomeShown = true;
                    Nav.Window.HideSplash();
                    AppLog.Timing("app", "Accueil affiché depuis le lancement du processus", App.ProcessStarted);
                }
            }
        }
        catch (OperationCanceledException)
        {
        }
        catch (Exception e)
        {
            if (_loaded) return;
            Nav.Window.HideSplash();
            Body.Children.Clear();
            ErrorText.Text = e is ApiException api ? api.UserMessage : L.T("L’accueil n’a pas pu être chargé.");
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

    private static string FeaturedSignature(HomeData data) =>
        string.Join('|', data.Featured.Select(i => $"{i.Id}:{i.Name}:{i.Overview}:{i.Backdrop?.Tag}:{i.Logo?.Tag}"));

    private static string SectionSignature(HomeSection s) =>
        $"{s.Title}|{s.Landscape}|{s.LibraryId}|" +
        string.Join('|', s.Items.Select(i => $"{i.Id}:{i.User.Progress:F3}:{i.User.Played}:{i.User.Favorite}:{i.Primary?.Tag}:{i.Thumb?.Tag}"));

    private static MediaRow BuildRow(HomeSection section, IReadOnlyList<MediaItem> libraries)
    {
        var style = section.Landscape ? CardStyle.Landscape : CardStyle.Poster;
        var row = new MediaRow(section.Title, section.Items, style, Gutter, seeAll: section.LibraryId != null);
        row.ItemActivated += Open;
        if (section.LibraryId is { } libraryId)
        {
            var library = libraries.FirstOrDefault(l => l.Id == libraryId);
            if (library != null) row.SeeAll += () => Nav.Go(typeof(LibraryPage), library);
        }
        return row;
    }

    private void Render(HomeData data)
    {
        var signature = Signature(data);
        if (signature == _rendered) return;
        var first = _rendered is null;
        _rendered = signature;
        var offset = Scroll.VerticalOffset;
        // Première apparition : carrousel et rangées arrivent en cascade. Ensuite, mise à jour incrémentale sans animation.
        Body.ChildrenTransitions = first ? Ui.Entrance(vertical: 60) : null;

        var featuredSig = FeaturedSignature(data);
        if (first)
        {
            Body.Children.Clear();
            _rows.Clear();
            _carousel = null;
            _spacer = null;
            _emptyText = null;
            if (data.Featured.Count > 0)
            {
                _carousel = new FeaturedCarousel(data.Featured);
                _featuredSig = featuredSig;
                Body.Children.Add(_carousel);
            }
            else
            {
                _featuredSig = null;
                _spacer = new Border { Height = 64 };
                Body.Children.Add(_spacer);
            }
            foreach (var section in data.Sections)
            {
                var row = BuildRow(section, data.Libraries);
                _rows.Add((SectionSignature(section), row));
                Body.Children.Add(row);
            }
            if (data.Sections.Count == 0 && data.Featured.Count == 0)
            {
                _emptyText = new TextBlock
                {
                    Text = L.T("Vos bibliothèques sont vides pour l’instant."),
                    Style = Ui.StyleOf("OFBody"),
                    Margin = new Thickness(Gutter, 80, Gutter, 0),
                };
                Body.Children.Add(_emptyText);
            }
            Scroll.UpdateLayout();
            Scroll.ChangeView(null, offset, null, disableAnimation: true);
            return;
        }

        // En-tête (carrousel ou espace réservé) : conservé s'il n'a pas changé.
        if (data.Featured.Count > 0)
        {
            if (_carousel is null || featuredSig != _featuredSig)
            {
                _carousel = new FeaturedCarousel(data.Featured);
                _featuredSig = featuredSig;
                _spacer = null;
                if (Body.Children.Count > 0) Body.Children[0] = _carousel;
                else Body.Children.Add(_carousel);
            }
        }
        else if (_spacer is null)
        {
            _carousel = null;
            _featuredSig = null;
            _spacer = new Border { Height = 64 };
            if (Body.Children.Count > 0) Body.Children[0] = _spacer;
            else Body.Children.Add(_spacer);
        }

        if (_emptyText != null && (data.Sections.Count > 0 || data.Featured.Count > 0))
        {
            Body.Children.Remove(_emptyText);
            _emptyText = null;
        }

        // Rangées : réutilise celles dont le contenu est identique.
        var desired = new List<(string Sig, MediaRow Row)>(data.Sections.Count);
        var reused = new HashSet<MediaRow>();
        foreach (var section in data.Sections)
        {
            var sig = SectionSignature(section);
            var existing = _rows.FirstOrDefault(r => r.Sig == sig && !reused.Contains(r.Row)).Row;
            var row = existing ?? BuildRow(section, data.Libraries);
            reused.Add(row);
            desired.Add((sig, row));
        }

        for (var i = Body.Children.Count - 1; i >= 1; i--)
        {
            if (Body.Children[i] is MediaRow r && reused.Contains(r)) continue;
            Body.Children.RemoveAt(i);
        }
        for (var i = 0; i < desired.Count; i++)
        {
            var targetIndex = i + 1;
            var row = desired[i].Row;
            if (targetIndex < Body.Children.Count && ReferenceEquals(Body.Children[targetIndex], row)) continue;
            Body.Children.Remove(row);
            Body.Children.Insert(targetIndex, row);
        }
        while (Body.Children.Count > desired.Count + 1) Body.Children.RemoveAt(Body.Children.Count - 1);
        _rows.Clear();
        _rows.AddRange(desired);

        if (data.Sections.Count == 0 && data.Featured.Count == 0 && _emptyText is null)
        {
            _emptyText = new TextBlock
            {
                Text = L.T("Vos bibliothèques sont vides pour l’instant."),
                Style = Ui.StyleOf("OFBody"),
                Margin = new Thickness(Gutter, 80, Gutter, 0),
            };
            Body.Children.Add(_emptyText);
        }
    }

    public static void Open(MediaItem item) => Nav.Go(typeof(DetailsPage), item);
}
