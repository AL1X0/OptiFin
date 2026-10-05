using System.Collections.ObjectModel;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Navigation;
using OptiFin.App.Controls;
using OptiFin.App.Services;
using OptiFin.Core.Api;
using OptiFin.Core.Logging;
using OptiFin.Core.Media;

namespace OptiFin.App.Pages;

/// <summary>
/// Une bibliothèque : grille virtualisée, chargée par pages de 60 au fil du défilement ; tri, sens,
/// filtres (vus, favoris, genres, résolution).
/// </summary>
public sealed partial class LibraryPage : Page
{
    private const int PageSize = 60;
    private MediaItem _library = null!;
    private LibraryQuery _query = new();
    private readonly ObservableCollection<object> _items = [];
    private int _total;
    private bool _loading;
    private int _generation;
    private ScrollViewer? _scroll;
    private CardStyle _style = CardStyle.Poster;
    private bool _listView;

    public LibraryPage()
    {
        InitializeComponent();
        Items.ItemsSource = _items;
        Items.ContainerContentChanging += (_, args) =>
        {
            if (args.InRecycleQueue || args.Item is not MediaItem item) return;
            FrameworkElement card;
            if (_listView)
            {
                var row = ListRow(item);
                card = row;
            }
            else
            {
                var media = new MediaCard(item, _style, MediaRow.CardWidth(_style));
                media.Activated += HomePage.Open;
                card = media;
            }
            if (args.ItemContainer.ContentTemplateRoot is ContentControl host) host.Content = card;
            args.Handled = true;
        };
        foreach (var letter in Letters)
        {
            var b = new TextBlock
            {
                Text = letter, FontSize = 11, FontWeight = Microsoft.UI.Text.FontWeights.Bold, HorizontalAlignment = HorizontalAlignment.Center,
                Foreground = Ui.Res("OFTextSecondaryBrush"), Padding = new Thickness(4, 1, 4, 1),
            };
            var hit = new HandGrid { Background = new SolidColorBrush(Microsoft.UI.Colors.Transparent) };
            hit.Children.Add(b);
            hit.Tapped += (_, _) => _ = JumpToLetterAsync(letter);
            ToolTipService.SetToolTip(hit, letter == "#" ? "Début" : letter);
            AlphaIndex.Children.Add(hit);
        }
        Items.Loaded += (_, _) =>
        {
            _scroll = FindScrollViewer(Items);
            if (_scroll != null)
            {
                _scroll.ViewChanged += (_, _) => MaybeLoadMore();
                Nav.TrackScroll(_scroll);
            }
        };
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        if (e.NavigationMode == NavigationMode.Back && _items.Count > 0) return;
        _library = (MediaItem)e.Parameter;
        Title.Text = _library.Name;
        _query = LibraryQuery.For(_library);
        _style = _query.Kinds.Contains(MediaKind.MusicAlbum) ? CardStyle.Square : CardStyle.Poster;
        BuildToolbar();
        _ = ReloadAsync();
    }

    private async Task ReloadAsync()
    {
        var generation = ++_generation;
        _items.Clear();
        _total = 0;
        Empty.Visibility = Visibility.Collapsed;
        Spinner.IsActive = true;
        await LoadPageAsync(generation);
        Spinner.IsActive = false;
        if (_items.Count == 0 && generation == _generation)
        {
            Empty.Text = _query.ActiveFilterCount > 0 ? "Aucun élément ne correspond à ces filtres." : "Cette bibliothèque est vide.";
            Empty.Visibility = Visibility.Visible;
        }
    }

    private async Task LoadPageAsync(int generation)
    {
        if (_loading || AppServices.Media is not { } media) return;
        _loading = true;
        try
        {
            var page = await media.PageAsync(_query, _items.Count, PageSize);
            if (generation != _generation) return;
            _total = page.Total;
            foreach (var item in page.Items) _items.Add(item);
            Count.Text = _total == 1 ? "1 élément" : $"{_total} éléments";
        }
        catch (ApiException e)
        {
            AppLog.Warn("library", e.UserMessage);
            if (_items.Count == 0)
            {
                Empty.Text = e.UserMessage;
                Empty.Visibility = Visibility.Visible;
            }
        }
        finally
        {
            _loading = false;
        }
    }

    private void MaybeLoadMore()
    {
        if (_scroll is null || _loading || _items.Count >= _total) return;
        if (_scroll.VerticalOffset > _scroll.ScrollableHeight - _scroll.ViewportHeight * 1.5) _ = LoadPageAsync(_generation);
    }

    private static ScrollViewer? FindScrollViewer(DependencyObject root)
    {
        for (var i = 0; i < VisualTreeHelper.GetChildrenCount(root); i++)
        {
            var child = VisualTreeHelper.GetChild(root, i);
            if (child is ScrollViewer sv) return sv;
            if (FindScrollViewer(child) is { } found) return found;
        }
        return null;
    }

    // ------------------------------------------------------------ Tri et filtres

    private void BuildToolbar()
    {
        Toolbar.Children.Clear();
        var sort = new ComboBox { MinWidth = 180, CornerRadius = new CornerRadius(18) };
        foreach (var s in Enum.GetValues<LibrarySort>()) sort.Items.Add(s.Label());
        sort.SelectedIndex = (int)_query.Sort;
        sort.SelectionChanged += (_, _) =>
        {
            var s = (LibrarySort)sort.SelectedIndex;
            _query = _query with { Sort = s, Descending = s.DefaultDescending() };
            BuildToolbar();
            _ = ReloadAsync();
        };
        Toolbar.Children.Add(sort);

        var order = Ui.Round(_query.Descending ? "" : "", _query.Descending ? "Décroissant" : "Croissant", 36);
        order.Click += (_, _) =>
        {
            _query = _query with { Descending = !_query.Descending };
            BuildToolbar();
            _ = ReloadAsync();
        };
        Toolbar.Children.Add(order);

        var played = new ComboBox { MinWidth = 140, CornerRadius = new CornerRadius(18) };
        played.Items.Add("Tous");
        played.Items.Add("Non vus");
        played.Items.Add("Vus");
        played.SelectedIndex = _query.Played switch { false => 1, true => 2, _ => 0 };
        played.SelectionChanged += (_, _) =>
        {
            _query = _query with { Played = played.SelectedIndex switch { 1 => false, 2 => true, _ => null } };
            _ = ReloadAsync();
        };
        Toolbar.Children.Add(played);

        var favorites = new ToggleButton { Content = "Favoris", IsChecked = _query.FavoritesOnly, CornerRadius = new CornerRadius(18) };
        favorites.Click += (_, _) =>
        {
            _query = _query with { FavoritesOnly = favorites.IsChecked == true };
            _ = ReloadAsync();
        };
        Toolbar.Children.Add(favorites);

        var resolution = new ComboBox { MinWidth = 130, CornerRadius = new CornerRadius(18) };
        resolution.Items.Add("Toutes résolutions");
        resolution.Items.Add("HD");
        resolution.Items.Add("4K");
        resolution.SelectedIndex = (int)_query.Resolution;
        resolution.SelectionChanged += (_, _) =>
        {
            _query = _query with { Resolution = (ResolutionFilter)resolution.SelectedIndex };
            _ = ReloadAsync();
        };
        Toolbar.Children.Add(resolution);

        var genres = new DropDownButton
        {
            Content = _query.GenreIds.Count == 0 ? "Genres" : $"Genres ({_query.GenreIds.Count})",
            CornerRadius = new CornerRadius(18),
        };
        genres.Click += async (_, _) => await ShowGenresAsync(genres);
        Toolbar.Children.Add(genres);

        var years = new DropDownButton
        {
            Content = _query.Years.Count == 0 ? "Années" : $"Années ({_query.Years.Count})",
            CornerRadius = new CornerRadius(18),
        };
        years.Click += async (_, _) => await ShowYearsAsync(years);
        Toolbar.Children.Add(years);

        if (_query.ActiveFilterCount > 0)
        {
            var reset = Ui.Secondary("Réinitialiser", "\uE72C");
            reset.Click += (_, _) =>
            {
                _query = LibraryQuery.For(_library) with { Sort = _query.Sort, Descending = _query.Descending };
                BuildToolbar();
                _ = ReloadAsync();
            };
            Toolbar.Children.Add(reset);
        }

        var view = Ui.Round(_listView ? "" : "", _listView ? "Affichage grille" : "Affichage liste", 36);
        view.Click += (_, _) =>
        {
            _listView = !_listView;
            BuildToolbar();
            _ = ReloadAsync();
        };
        Toolbar.Children.Add(view);
        // Index alphabétique : utile seulement en tri par titre croissant.
        AlphaIndex.Visibility = _query.Sort == LibrarySort.Title && !_query.Descending ? Visibility.Visible : Visibility.Collapsed;
    }

    private static readonly string[] Letters = ["#", .. Enumerable.Range('A', 26).Select(c => ((char)c).ToString())];

    /// <summary>Saut à la première lettre : position calculée par le serveur, pages chargées jusque-là.</summary>
    private async Task JumpToLetterAsync(string letter)
    {
        if (AppServices.Media is not { } media) return;
        try
        {
            var index = await media.IndexOfLetterAsync(_query, letter);
            var generation = _generation;
            while (_items.Count <= index && _items.Count < _total && generation == _generation)
            {
                var before = _items.Count;
                await LoadPageAsync(generation);
                if (_items.Count == before) break;
            }
            if (_items.Count == 0) return;
            Items.ScrollIntoView(_items[Math.Min(index, _items.Count - 1)], ScrollIntoViewAlignment.Leading);
        }
        catch (ApiException)
        {
            // Saut non critique.
        }
    }

    /// <summary>Ligne de l'affichage en liste : affiche, titre, informations, synopsis.</summary>
    private FrameworkElement ListRow(MediaItem item)
    {
        var row = new HandGrid
        {
            Width = Math.Max(400, Items.ActualWidth - 40),
            ColumnSpacing = 16,
            Padding = new Thickness(8),
            CornerRadius = new CornerRadius(12),
            Background = new SolidColorBrush(Microsoft.UI.Colors.Transparent),
        };
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(64) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        var art = new Border { Width = 64, Height = 96, CornerRadius = new CornerRadius(8), Background = Ui.Res("OFSurfaceBrush") };
        if (AppServices.Images?.Maybe(item.Poster ?? item.Primary, 64, 1.5) is { } url)
            art.Child = Ui.FadeIn(new Image { Source = new Microsoft.UI.Xaml.Media.Imaging.BitmapImage(url) { DecodePixelWidth = 96 }, Stretch = Stretch.UniformToFill });
        row.Children.Add(art);
        var texts = new StackPanel { Spacing = 3, VerticalAlignment = VerticalAlignment.Center };
        texts.Children.Add(new TextBlock { Text = item.Name, FontSize = 15, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, TextTrimming = TextTrimming.CharacterEllipsis });
        var meta = MediaFormat.MetadataLine(item);
        if (meta.Count > 0) texts.Children.Add(Ui.Text(string.Join("  ·  ", meta), "OFCaption"));
        if (item.Overview is { } overview)
            texts.Children.Add(new TextBlock { Text = overview, Style = Ui.StyleOf("OFCaption"), MaxLines = 2, TextWrapping = TextWrapping.Wrap, TextTrimming = TextTrimming.WordEllipsis, Foreground = Ui.Res("OFTextSecondaryBrush") });
        Grid.SetColumn(texts, 1);
        row.Children.Add(texts);
        Ui.Clickable(row, () => HomePage.Open(item), new SolidColorBrush(Microsoft.UI.Colors.Transparent), Ui.Res("OFSurfaceBrush"));
        return row;
    }

    private async Task ShowYearsAsync(DropDownButton anchor)
    {
        if (AppServices.Media is not { } media) return;
        LibraryFilterOptions options;
        try
        {
            options = await media.FilterOptionsAsync(_query);
        }
        catch (ApiException)
        {
            return;
        }
        var flyout = new MenuFlyout();
        foreach (var year in options.Years)
        {
            var item = new ToggleMenuFlyoutItem { Text = year.ToString(), IsChecked = _query.Years.Contains(year) };
            item.Click += (_, _) =>
            {
                var list = _query.Years.ToList();
                if (item.IsChecked) list.Add(year);
                else list.Remove(year);
                _query = _query with { Years = list };
                BuildToolbar();
                _ = ReloadAsync();
            };
            flyout.Items.Add(item);
        }
        if (options.Years.Count == 0) flyout.Items.Add(new MenuFlyoutItem { Text = "Aucune année", IsEnabled = false });
        flyout.ShowAt(anchor);
    }

    private async Task ShowGenresAsync(DropDownButton anchor)
    {
        if (AppServices.Media is not { } media) return;
        LibraryFilterOptions options;
        try
        {
            options = await media.FilterOptionsAsync(_query);
        }
        catch (ApiException)
        {
            return;
        }
        var flyout = new MenuFlyout();
        foreach (var genre in options.Genres)
        {
            var item = new ToggleMenuFlyoutItem { Text = genre.Name, IsChecked = _query.GenreIds.Contains(genre.Id) };
            item.Click += (_, _) =>
            {
                var ids = _query.GenreIds.ToList();
                if (item.IsChecked) ids.Add(genre.Id);
                else ids.Remove(genre.Id);
                _query = _query with { GenreIds = ids };
                BuildToolbar();
                _ = ReloadAsync();
            };
            flyout.Items.Add(item);
        }
        if (_query.GenreIds.Count > 0)
        {
            flyout.Items.Add(new MenuFlyoutSeparator());
            var clear = new MenuFlyoutItem { Text = "Tous les genres" };
            clear.Click += (_, _) =>
            {
                _query = _query with { GenreIds = [] };
                BuildToolbar();
                _ = ReloadAsync();
            };
            flyout.Items.Add(clear);
        }
        flyout.ShowAt(anchor);
    }
}
