using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.UI.Xaml.Navigation;
using OptiFin.App.Controls;
using OptiFin.App.Player;
using OptiFin.App.Services;
using OptiFin.Core.Api;
using OptiFin.Core.Logging;
using OptiFin.Core.Media;
using Windows.UI;

namespace OptiFin.App.Pages;

/// <summary>
/// Fiche : image de fond, affiche, logo ou titre, métadonnées, badges qualité, actions (lecture,
/// reprise, depuis le début, vu, favori), synopsis, saisons et épisodes, distribution, similaires.
/// </summary>
public sealed partial class DetailsPage : Page
{
    private const double Gutter = HomePage.Gutter;
    private MediaItem _item = null!;
    private CancellationTokenSource? _cts;

    // Accent du film (comme sur mobile) : couleur vive dominante de son illustration.
    private Color _accent = FilmAccent.Default;
    private readonly LinearGradientBrush _glow = new() { StartPoint = new(0, 0.85), EndPoint = new(0.8, 0) };

    public DetailsPage()
    {
        InitializeComponent();
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        if (e.Parameter is MediaItem item)
        {
            _item = item;
            _ = LoadAsync();
        }
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e) => _cts?.Cancel();

    private async Task LoadAsync()
    {
        if (AppServices.Media is not { } media) return;
        _cts?.Cancel();
        _cts = new CancellationTokenSource();
        var ct = _cts.Token;
        try
        {
            var accent = FilmAccent.ForAsync(_item);
            var item = _item.Kind == MediaKind.Person ? await media.PersonAsync(_item.Id, ct) : await media.ItemAsync(_item.Id, ct);
            _item = item;
            // L'accent (image de 24 px) arrive en général avant la fiche ; on l'attend au plus 0,6 s.
            await Task.WhenAny(accent, Task.Delay(600, ct));
            ApplyAccent(accent.IsCompletedSuccessfully ? accent.Result : null);
            if (!accent.IsCompleted) _ = accent.ContinueWith(t => DispatcherQueue.TryEnqueue(() => ApplyAccent(t.Result)),
                ct, TaskContinuationOptions.OnlyOnRanToCompletion, TaskScheduler.Default);
            Render(item);
            Spinner.IsActive = false;
            await LoadExtrasAsync(item, media, ct);
        }
        catch (OperationCanceledException)
        {
        }
        catch (Exception e)
        {
            Spinner.IsActive = false;
            ErrorText.Text = e is ApiException api ? api.UserMessage : "Cette fiche n’a pas pu être chargée.";
            ErrorText.Visibility = Visibility.Visible;
            AppLog.Error("details", "Fiche indisponible", e);
        }
    }

    // ------------------------------------------------------------ En-tête

    private readonly StackPanel _actions = new() { Orientation = Orientation.Horizontal, Spacing = 12 };
    // Saisons, distribution, similaires : chaque section glisse en place à son arrivée.
    private readonly StackPanel _extras = new() { Spacing = 32, ChildrenTransitions = Ui.Entrance() };

    private void Render(MediaItem item)
    {
        Body.ChildrenTransitions ??= Ui.Entrance(vertical: 50);
        Body.Children.Clear();
        Body.Children.Add(Hero(item));
        var body = new StackPanel { Spacing = 20, Padding = new Thickness(Gutter, 0, Gutter, 0), MaxWidth = 1400, HorizontalAlignment = HorizontalAlignment.Left };
        BuildActions(item);
        body.Children.Add(_actions);
        if (item.Kind == MediaKind.Person)
        {
            if (item.Overview is { } bio) body.Children.Add(new TextBlock { Text = bio, Style = Ui.StyleOf("OFBody"), MaxWidth = 900 });
        }
        else
        {
            if (item.Tagline is { } tagline)
                body.Children.Add(new TextBlock { Text = tagline, FontSize = 17, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Foreground = Ui.Res("OFTextSecondaryBrush") });
            if (item.Overview is { } overview)
                body.Children.Add(new TextBlock { Text = overview, Style = Ui.StyleOf("OFBody"), MaxWidth = 900, FontSize = 16, LineHeight = 24 });
            if (Credits(item) is { } credits) body.Children.Add(credits);
        }
        Body.Children.Add(body);
        _extras.Children.Clear();
        Body.Children.Add(_extras);
    }

    /// <summary>
    /// Teinte la fiche : halo coloré sous l'image de fond, onglets de saison, barres de progression,
    /// bouton « vu » (ressources redéfinies pour cette page uniquement).
    /// </summary>
    private void ApplyAccent(Color? color)
    {
        _accent = color ?? FilmAccent.Default;
        Brush Solid(Color c) => new SolidColorBrush(c);
        var hover = Color.FromArgb(0xFF, (byte)Math.Min(255, _accent.R + 24), (byte)Math.Min(255, _accent.G + 24), (byte)Math.Min(255, _accent.B + 24));
        var pressed = Color.FromArgb(0xFF, (byte)(_accent.R * 0.85), (byte)(_accent.G * 0.85), (byte)(_accent.B * 0.85));
        Resources["OFAccentBrush"] = Solid(_accent);
        Resources["AccentFillColorDefaultBrush"] = Solid(_accent);
        Resources["ProgressBarForeground"] = Solid(_accent);
        Resources["ToggleButtonBackgroundChecked"] = Solid(_accent);
        Resources["ToggleButtonBackgroundCheckedPointerOver"] = Solid(hover);
        Resources["ToggleButtonBackgroundCheckedPressed"] = Solid(pressed);
        Resources["ToggleButtonBorderBrushChecked"] = Solid(_accent);
        _glow.GradientStops.Clear();
        _glow.GradientStops.Add(new GradientStop { Offset = 0, Color = _accent.WithAlpha(color is null ? (byte)0 : (byte)0x8C) });
        _glow.GradientStops.Add(new GradientStop { Offset = 0.55, Color = _accent.WithAlpha(color is null ? (byte)0 : (byte)0x26) });
        _glow.GradientStops.Add(new GradientStop { Offset = 1, Color = _accent.WithAlpha(0) });
    }

    private Brush AccentBrush => new SolidColorBrush(_accent);

    private FrameworkElement Hero(MediaItem item)
    {
        var hero = new Grid { Height = 560 };
        if (AppServices.Images?.Maybe(item.Backdrop, 1920, 1, 80) is { } backdrop)
            hero.Children.Add(Ui.FadeIn(new Image { Source = new BitmapImage(backdrop) { DecodePixelWidth = 1920 }, Stretch = Stretch.UniformToFill, VerticalAlignment = VerticalAlignment.Top }, 700));
        // Halo aux couleurs du film, sous les voiles : il se fond dans le noir en bas de l'en-tête.
        hero.Children.Add(new Border { Background = _glow, IsHitTestVisible = false });
        hero.Children.Add(new Border
        {
            Background = Gradient(new(0.5, 0), new(0.5, 1),
                (0, Color.FromArgb(0x40, 0, 0, 0)), (0.45, Color.FromArgb(0x26, 0, 0, 0)), (1, Color.FromArgb(0xFF, 0, 0, 0))),
        });
        hero.Children.Add(new Border
        {
            Background = Gradient(new(0, 0.5), new(1, 0.5), (0, Color.FromArgb(0xB3, 0, 0, 0)), (0.6, Color.FromArgb(0, 0, 0, 0))),
        });

        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 32, VerticalAlignment = VerticalAlignment.Bottom, Margin = new Thickness(Gutter, 0, Gutter, 28) };
        var posterRef = item.Kind == MediaKind.Episode ? item.Primary : item.Poster ?? item.Primary;
        var posterWidth = item.Kind == MediaKind.Episode ? 320.0 : 200.0;
        var posterHeight = item.Kind == MediaKind.Episode ? 180.0 : 300.0;
        if (AppServices.Images?.Maybe(posterRef, posterWidth, 1.5) is { } poster)
        {
            row.Children.Add(new Border
            {
                Width = posterWidth, Height = posterHeight, CornerRadius = new CornerRadius(12),
                Background = Ui.Res("OFSurfaceBrush"),
                Child = Ui.FadeIn(new Image { Source = new BitmapImage(poster) { DecodePixelWidth = (int)(posterWidth * 1.5) }, Stretch = Stretch.UniformToFill }),
            });
        }
        var info = new StackPanel { Spacing = 12, VerticalAlignment = VerticalAlignment.Bottom, MaxWidth = 760 };
        if (item.Kind == MediaKind.Episode && item.SeriesName != null)
            info.Children.Add(new TextBlock { Text = item.SeriesName, FontSize = 18, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Foreground = Ui.Res("OFTextSecondaryBrush") });
        if (item.Kind != MediaKind.Episode && AppServices.Images?.Maybe(item.Logo, 460, 1.5) is { } logo)
            info.Children.Add(Ui.FadeIn(new Image { Source = new BitmapImage(logo), MaxHeight = 140, MaxWidth = 460, HorizontalAlignment = HorizontalAlignment.Left, Margin = new Thickness(0, 0, 0, 6) }));
        else
            info.Children.Add(new TextBlock { Text = item.Kind == MediaKind.Episode ? $"{item.EpisodeLabel} · {item.Name}" : item.Name, Style = Ui.StyleOf("OFDisplay"), MaxLines = 2 });
        var meta = MediaFormat.MetadataLine(item);
        if (meta.Count > 0) info.Children.Add(new TextBlock { Text = string.Join("  ·  ", meta), FontSize = 15, Foreground = Ui.Res("OFTextSecondaryBrush") });
        var badges = QualityBadges.For(item.Streams);
        if (badges.Count > 0)
        {
            var strip = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
            foreach (var b in badges)
            {
                strip.Children.Add(new Border
                {
                    BorderBrush = Ui.Res("OFTextTertiaryBrush"), BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(5),
                    Padding = new Thickness(7, 2, 7, 2),
                    Child = new TextBlock { Text = b, FontSize = 12, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Foreground = Ui.Res("OFTextSecondaryBrush") },
                });
            }
            info.Children.Add(strip);
        }
        row.Children.Add(info);
        hero.Children.Add(row);
        return hero;
    }

    private static LinearGradientBrush Gradient(Windows.Foundation.Point start, Windows.Foundation.Point end, params (double Offset, Color Color)[] stops)
    {
        var brush = new LinearGradientBrush { StartPoint = start, EndPoint = end };
        foreach (var (offset, color) in stops) brush.GradientStops.Add(new GradientStop { Offset = offset, Color = color });
        return brush;
    }

    // ------------------------------------------------------------ Actions

    private void BuildActions(MediaItem item)
    {
        _actions.Children.Clear();
        if (item.Kind.IsPlayableVideo())
        {
            var resume = item.User.PositionTicks > 0;
            var play = Ui.Primary(resume ? "Reprendre" : "Lecture", "");
            play.Click += (_, _) => PlayerLauncher.Play(item);
            _actions.Children.Add(play);
            if (resume)
            {
                var restart = Ui.Round("", "Lire depuis le début");
                restart.Click += (_, _) => PlayerLauncher.Play(item, fromStart: true);
                _actions.Children.Add(restart);
            }
        }
        if (item.Kind is not (MediaKind.Person or MediaKind.BoxSet))
        {
            var played = Ui.Round(item.User.Played ? "" : "", item.User.Played ? "Marquer comme non vu" : "Marquer comme vu");
            if (item.User.Played) played.Background = AccentBrush;
            played.Click += async (_, _) => await Toggle(() => AppServices.Media!.SetPlayedAsync(item.Id, !_item.User.Played));
            _actions.Children.Add(played);
        }
        if (item.Kind != MediaKind.Person)
        {
            var fav = Ui.Round(item.User.Favorite ? "" : "", item.User.Favorite ? "Retirer des favoris" : "Ajouter aux favoris");
            if (item.User.Favorite) ((FontIcon)fav.Content).Foreground = new SolidColorBrush(Color.FromArgb(0xFF, 0xFF, 0x45, 0x3A));
            fav.Click += async (_, _) => await Toggle(() => AppServices.Media!.SetFavoriteAsync(item.Id, !_item.User.Favorite));
            _actions.Children.Add(fav);
        }
        if (item.Kind.IsPlayableVideo() && MediaFormat.Remaining(item) is { } remaining && item.User.Progress is { } progress)
        {
            var bar = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 12, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(8, 0, 0, 0) };
            bar.Children.Add(new ProgressBar { Width = 120, Value = progress * 100, VerticalAlignment = VerticalAlignment.Center, Foreground = AccentBrush });
            bar.Children.Add(new TextBlock { Text = remaining, Style = Ui.StyleOf("OFCaption"), VerticalAlignment = VerticalAlignment.Center });
            _actions.Children.Add(bar);
        }
    }

    private async Task Toggle(Func<Task<UserState>> call)
    {
        try
        {
            var state = await call();
            _item = _item with { User = state };
            BuildActions(_item);
        }
        catch (ApiException e)
        {
            AppLog.Warn("details", e.UserMessage);
        }
    }

    private static FrameworkElement? Credits(MediaItem item)
    {
        var lines = new List<(string Label, string Value)>();
        if (item.Genres.Count > 0) lines.Add(("Genres", string.Join(", ", item.Genres.Select(g => g.Name))));
        var directors = item.People.Where(p => p.Kind == PersonKind.Director).Select(p => p.Name).ToList();
        if (directors.Count > 0) lines.Add((directors.Count > 1 ? "Réalisation" : "Réalisation", string.Join(", ", directors)));
        var writers = item.People.Where(p => p.Kind == PersonKind.Writer).Select(p => p.Name).Take(3).ToList();
        if (writers.Count > 0) lines.Add(("Scénario", string.Join(", ", writers)));
        if (item.Studios.Count > 0) lines.Add(("Studio", string.Join(", ", item.Studios.Take(2).Select(s => s.Name))));
        if (lines.Count == 0) return null;
        var grid = new Grid { ColumnSpacing = 24, RowSpacing = 6 };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        for (var i = 0; i < lines.Count; i++)
        {
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            var label = new TextBlock { Text = lines[i].Label, Style = Ui.StyleOf("OFCaption") };
            var value = new TextBlock { Text = lines[i].Value, FontSize = 13, TextWrapping = TextWrapping.Wrap, Foreground = Ui.Res("OFTextPrimaryBrush") };
            Grid.SetRow(label, i);
            Grid.SetRow(value, i);
            Grid.SetColumn(value, 1);
            grid.Children.Add(label);
            grid.Children.Add(value);
        }
        return grid;
    }

    // ------------------------------------------------------------ Saisons, épisodes, distribution

    private async Task LoadExtrasAsync(MediaItem item, MediaRepository media, CancellationToken ct)
    {
        switch (item.Kind)
        {
            case MediaKind.Series:
                await SeriesAsync(item, media, ct);
                break;
            case MediaKind.Season when item.SeriesId != null:
                await EpisodesAsync(item.SeriesId, item.Id, media, ct, _extras);
                break;
            case MediaKind.BoxSet or MediaKind.Folder or MediaKind.Playlist:
                AddRow("Contenu", await media.ChildrenAsync(item.Id, ct: ct), CardStyle.Poster);
                break;
            case MediaKind.Person:
                AddRow("Filmographie", await media.CreditsAsync(item.Id, ct), CardStyle.Poster);
                return;
        }
        var cast = item.People.Where(p => p.Kind is PersonKind.Actor or PersonKind.GuestStar).Take(30).ToList();
        if (cast.Count > 0) _extras.Children.Add(CastRow(cast));
        if (item.Kind is MediaKind.Movie or MediaKind.Series)
        {
            try
            {
                var similar = await media.SimilarAsync(item.Id, ct: ct);
                AddRow("Titres similaires", similar, CardStyle.Poster);
            }
            catch (ApiException)
            {
            }
        }
    }

    private void AddRow(string title, IReadOnlyList<MediaItem> items, CardStyle style)
    {
        if (items.Count == 0) return;
        var row = new MediaRow(title, items, style, Gutter);
        row.ItemActivated += HomePage.Open;
        _extras.Children.Add(row);
    }

    private async Task SeriesAsync(MediaItem series, MediaRepository media, CancellationToken ct)
    {
        var seasonsTask = media.SeasonsAsync(series.Id, ct);
        var nextTask = media.NextUpForAsync(series.Id, ct);
        var seasons = await seasonsTask;
        var next = await nextTask;
        if (next != null)
        {
            var label = next.User.PositionTicks > 0 ? "Reprendre" : "Lecture";
            var play = Ui.Primary($"{label} {next.EpisodeLabel}", "");
            play.Click += (_, _) => PlayerLauncher.Play(next);
            _actions.Children.Insert(0, play);
        }
        if (seasons.Count == 0) return;

        var section = new StackPanel { Spacing = 16 };
        var tabs = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, Padding = new Thickness(Gutter, 0, Gutter, 0) };
        var episodes = new StackPanel();
        section.Children.Add(new ScrollViewer
        {
            Content = tabs, HorizontalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollMode = ScrollMode.Enabled,
            VerticalScrollMode = ScrollMode.Disabled,
        });
        section.Children.Add(episodes);
        _extras.Children.Add(section);

        var initial = seasons.FirstOrDefault(s => s.Id == next?.SeasonId) ?? seasons[0];
        void Select(MediaItem season)
        {
            foreach (var child in tabs.Children.OfType<ToggleButton>()) child.IsChecked = (string)child.Tag == season.Id;
            _ = EpisodesAsync(series.Id, season.Id, media, ct, episodes, replace: true);
        }
        foreach (var season in seasons)
        {
            var tab = new ToggleButton
            {
                Content = season.Name,
                Tag = season.Id,
                CornerRadius = new CornerRadius(18),
                Padding = new Thickness(16, 8, 16, 8),
                FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
            };
            tab.Click += (_, _) => Select(season);
            tabs.Children.Add(tab);
        }
        Select(initial);
    }

    private async Task EpisodesAsync(string seriesId, string seasonId, MediaRepository media, CancellationToken ct, Panel target,
        bool replace = false)
    {
        IReadOnlyList<MediaItem> list;
        try
        {
            list = await media.EpisodesAsync(seriesId, seasonId, ct);
        }
        catch (ApiException e)
        {
            AppLog.Warn("details", $"Épisodes indisponibles : {e.Message}");
            return;
        }
        if (replace) target.Children.Clear();
        var column = new StackPanel { Spacing = 8, Padding = new Thickness(Gutter - 12, 0, Gutter, 0), MaxWidth = 1200, HorizontalAlignment = HorizontalAlignment.Left };
        foreach (var episode in list) column.Children.Add(EpisodeRow(episode));
        target.Children.Add(column);
    }

    /// <summary>Épisode : vignette (lecture au clic), titre, durée, synopsis, progression.</summary>
    private FrameworkElement EpisodeRow(MediaItem e)
    {
        var row = new HandGrid { Padding = new Thickness(12), CornerRadius = new CornerRadius(14), ColumnSpacing = 20, IsTabStop = true, UseSystemFocusVisuals = true };
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(260) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        var thumb = new Grid { Height = 146, Width = 260, CornerRadius = new CornerRadius(10), Background = Ui.Res("OFSurfaceBrush") };
        if (AppServices.Images?.Maybe(e.Landscape, 260, 1.5) is { } url)
            thumb.Children.Add(Ui.FadeIn(new Image { Source = new BitmapImage(url) { DecodePixelWidth = 390 }, Stretch = Stretch.UniformToFill }));
        if (e.User.Progress is { } progress)
            thumb.Children.Add(new ProgressBar { Value = progress * 100, VerticalAlignment = VerticalAlignment.Bottom, Margin = new Thickness(8, 0, 8, 8), Foreground = AccentBrush });
        var playIcon = new Border
        {
            Width = 44, Height = 44, CornerRadius = new CornerRadius(22), Opacity = 0,
            Background = new SolidColorBrush(Color.FromArgb(0xE6, 0xFF, 0xFF, 0xFF)),
            HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center,
            Child = new FontIcon { Glyph = "", FontSize = 16, Foreground = new SolidColorBrush(Color.FromArgb(0xFF, 0, 0, 0)) },
            OpacityTransition = new ScalarTransition { Duration = TimeSpan.FromMilliseconds(150) },
        };
        thumb.Children.Add(playIcon);
        row.Children.Add(thumb);
        var text = new StackPanel { Spacing = 6, VerticalAlignment = VerticalAlignment.Center };
        var head = $"{e.IndexNumber}. {e.Name}";
        text.Children.Add(new TextBlock { Text = head, FontSize = 16, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, TextTrimming = TextTrimming.CharacterEllipsis });
        var meta = new List<string>();
        if (MediaFormat.Duration(e.Runtime) is { } d) meta.Add(d);
        if (e.PremiereDate is { } date) meta.Add(date.ToString("d MMM yyyy", System.Globalization.CultureInfo.GetCultureInfo("fr-FR")));
        if (e.User.Played) meta.Add("Vu");
        if (meta.Count > 0) text.Children.Add(new TextBlock { Text = string.Join(" · ", meta), Style = Ui.StyleOf("OFCaption") });
        if (e.Overview is { } overview)
            text.Children.Add(new TextBlock { Text = overview, FontSize = 14, MaxLines = 3, TextWrapping = TextWrapping.Wrap, TextTrimming = TextTrimming.WordEllipsis, Foreground = Ui.Res("OFTextSecondaryBrush") });
        Grid.SetColumn(text, 1);
        row.Children.Add(text);
        var transparent = new SolidColorBrush(Color.FromArgb(0, 0, 0, 0));
        row.Background = transparent;
        Ui.Clickable(row, () => PlayerLauncher.Play(e), transparent, Ui.Res("OFSurfaceBrush"));
        row.PointerEntered += (_, _) => playIcon.Opacity = 1;
        row.PointerExited += (_, _) => playIcon.Opacity = 0;
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(row, $"Lire {head}");
        return row;
    }

    private static FrameworkElement CastRow(IReadOnlyList<PersonCredit> cast)
    {
        var section = new StackPanel { Spacing = 12 };
        section.Children.Add(new TextBlock { Text = "Distribution", Style = Ui.StyleOf("OFTitle2"), Margin = new Thickness(Gutter, 0, Gutter, 0) });
        var panel = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 20, Padding = new Thickness(Gutter, 4, Gutter, 4) };
        foreach (var p in cast)
        {
            var cell = new HandGrid { Width = 112, IsTabStop = true, UseSystemFocusVisuals = true, CornerRadius = new CornerRadius(12), Padding = new Thickness(0, 4, 0, 4) };
            var stack = new StackPanel { Spacing = 6, HorizontalAlignment = HorizontalAlignment.Center };
            var avatar = Ui.Avatar(p.Name, AppServices.Images?.Maybe(p.Image, 96, 2), 96);
            avatar.HorizontalAlignment = HorizontalAlignment.Center;
            stack.Children.Add(avatar);
            stack.Children.Add(new TextBlock { Text = p.Name, FontSize = 13, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, TextAlignment = TextAlignment.Center, TextWrapping = TextWrapping.Wrap, MaxLines = 2 });
            if (p.Role is { } role)
                stack.Children.Add(new TextBlock { Text = role, Style = Ui.StyleOf("OFCaption"), TextAlignment = TextAlignment.Center, MaxLines = 1 });
            cell.Children.Add(stack);
            var transparent = new SolidColorBrush(Color.FromArgb(0, 0, 0, 0));
            cell.Background = transparent;
            Ui.Clickable(cell, () => HomePage.Open(new MediaItem { Id = p.Id, Name = p.Name, Kind = MediaKind.Person }), transparent, Ui.Res("OFSurfaceBrush"));
            panel.Children.Add(cell);
        }
        section.Children.Add(new ScrollViewer
        {
            Content = panel, HorizontalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollMode = ScrollMode.Enabled,
            VerticalScrollMode = ScrollMode.Disabled,
        });
        return section;
    }
}
