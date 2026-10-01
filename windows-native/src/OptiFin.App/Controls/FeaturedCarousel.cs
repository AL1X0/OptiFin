using Microsoft.UI;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using OptiFin.App.Pages;
using OptiFin.App.Player;
using OptiFin.App.Services;
using OptiFin.Core.Media;
using Windows.UI;

namespace OptiFin.App.Controls;

/// <summary>
/// Carrousel « à la une » : image de fond plein cadre (fondu enchaîné), logo du titre, genres et
/// année, synopsis, boutons Lecture / Infos, points de pagination. Défilement automatique toutes
/// les 8 s, suspendu au survol ; ← → au clavier.
/// </summary>
public sealed partial class FeaturedCarousel : Grid
{
    private readonly IReadOnlyList<MediaItem> _items;
    private readonly Image[] _layers = [new() { Stretch = Stretch.UniformToFill, Opacity = 1 }, new() { Stretch = Stretch.UniformToFill, Opacity = 0 }];
    private readonly StackPanel _info = new() { Spacing = 16, VerticalAlignment = VerticalAlignment.Bottom, MaxWidth = 620, HorizontalAlignment = HorizontalAlignment.Left };
    private readonly StackPanel _dots = new() { Orientation = Orientation.Horizontal, Spacing = 6 };
    private readonly DispatcherQueueTimer _timer;
    private int _index;
    private int _front;

    public FeaturedCarousel(IReadOnlyList<MediaItem> items)
    {
        _items = items;
        Height = 620;
        foreach (var layer in _layers)
        {
            layer.OpacityTransition = new ScalarTransition { Duration = TimeSpan.FromMilliseconds(600) };
            Children.Add(layer);
        }
        // Voiles : lisibilité du texte à gauche, fondu vers le noir en bas.
        Children.Add(new Border
        {
            Background = Gradient(new Windows.Foundation.Point(0, 0.5), new Windows.Foundation.Point(1, 0.5),
                (0, Color.FromArgb(0xE6, 0, 0, 0)), (0.45, Color.FromArgb(0x66, 0, 0, 0)), (1, Color.FromArgb(0, 0, 0, 0))),
        });
        Children.Add(new Border
        {
            Background = Gradient(new Windows.Foundation.Point(0.5, 0), new Windows.Foundation.Point(0.5, 1),
                (0, Color.FromArgb(0x59, 0, 0, 0)), (0.25, Color.FromArgb(0, 0, 0, 0)), (0.7, Color.FromArgb(0, 0, 0, 0)),
                (1, Color.FromArgb(0xFF, 0, 0, 0))),
        });
        var bottom = new StackPanel { Spacing = 22, VerticalAlignment = VerticalAlignment.Bottom, Margin = new Thickness(HomePage.Gutter, 0, HomePage.Gutter, 28) };
        bottom.Children.Add(_info);
        bottom.Children.Add(_dots);
        Children.Add(bottom);

        for (var i = 0; i < items.Count; i++)
        {
            var index = i;
            var dot = new Border
            {
                Height = 6, Width = 6, CornerRadius = new CornerRadius(3),
                Background = new SolidColorBrush(Color.FromArgb(0x66, 0xFF, 0xFF, 0xFF)),
            };
            var hit = new HandGrid { Padding = new Thickness(2, 6, 2, 6), Background = new SolidColorBrush(Colors.Transparent) };
            hit.Children.Add(dot);
            hit.Tapped += (_, _) => Show(index, user: true);
            _dots.Children.Add(hit);
        }

        _timer = DispatcherQueue.GetForCurrentThread().CreateTimer();
        _timer.Interval = TimeSpan.FromSeconds(8);
        _timer.Tick += (_, _) => Show((_index + 1) % _items.Count);
        PointerEntered += (_, _) => _timer.Stop();
        PointerExited += (_, _) => _timer.Start();
        Unloaded += (_, _) => _timer.Stop();
        Loaded += (_, _) =>
        {
            if (_items.Count > 1) _timer.Start();
        };
        KeyDown += (_, e) =>
        {
            if (e.Key == Windows.System.VirtualKey.Right) Show((_index + 1) % _items.Count, user: true);
            else if (e.Key == Windows.System.VirtualKey.Left) Show((_index - 1 + _items.Count) % _items.Count, user: true);
            else return;
            e.Handled = true;
        };
        Show(0);
    }

    private static LinearGradientBrush Gradient(Windows.Foundation.Point start, Windows.Foundation.Point end, params (double Offset, Color Color)[] stops)
    {
        var brush = new LinearGradientBrush { StartPoint = start, EndPoint = end };
        foreach (var (offset, color) in stops) brush.GradientStops.Add(new GradientStop { Offset = offset, Color = color });
        return brush;
    }

    private void Show(int index, bool user = false)
    {
        if (_items.Count == 0) return;
        _index = index;
        var item = _items[index];
        if (user && _items.Count > 1)
        {
            _timer.Stop();
            _timer.Start();
        }

        // Fondu enchaîné entre deux calques d'image.
        var back = _layers[1 - _front];
        if (AppServices.Images?.Maybe(item.Backdrop, 1920, 1, 80) is { } url)
            back.Source = new BitmapImage(url) { DecodePixelWidth = 1920 };
        back.Opacity = 1;
        _layers[_front].Opacity = 0;
        _front = 1 - _front;
        // Le calque visible passe au-dessus (ordre des enfants : 0 et 1).
        Children.Move((uint)Children.IndexOf(_layers[_front]), 1);

        _info.Children.Clear();
        if (AppServices.Images?.Maybe(item.Logo, 460, 1.5) is { } logo)
        {
            _info.Children.Add(new Image
            {
                Source = new BitmapImage(logo),
                MaxHeight = 150,
                MaxWidth = 460,
                HorizontalAlignment = HorizontalAlignment.Left,
                Stretch = Stretch.Uniform,
            });
        }
        else
        {
            _info.Children.Add(new TextBlock { Text = item.Name, Style = Ui.StyleOf("OFDisplay"), FontSize = 48, MaxLines = 2 });
        }
        var meta = item.Genres.Take(2).Select(g => g.Name).ToList();
        if (MediaFormat.Years(item) is { } year) meta.Add(year);
        if (meta.Count > 0)
            _info.Children.Add(new TextBlock { Text = string.Join(" · ", meta), FontSize = 15, Foreground = Ui.Res("OFTextSecondaryBrush") });
        if (item.Overview is { } overview)
        {
            _info.Children.Add(new TextBlock
            {
                Text = overview, FontSize = 15, MaxLines = 3, TextWrapping = TextWrapping.Wrap,
                TextTrimming = TextTrimming.WordEllipsis, Foreground = Ui.Res("OFTextPrimaryBrush"),
            });
        }
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 12, Margin = new Thickness(0, 4, 0, 0) };
        var play = Ui.Primary("Lecture", "");
        play.Click += (_, _) =>
        {
            // Film : lecture directe. Série : la fiche choisit l'épisode à suivre.
            if (item.Kind.IsPlayableVideo()) PlayerLauncher.Play(item);
            else HomePage.Open(item);
        };
        var info = Ui.Secondary("Infos", "");
        info.Click += (_, _) => HomePage.Open(item);
        buttons.Children.Add(play);
        buttons.Children.Add(info);
        _info.Children.Add(buttons);

        for (var i = 0; i < _dots.Children.Count; i++)
        {
            var dot = (Border)((Grid)_dots.Children[i]).Children[0];
            dot.Width = i == index ? 22 : 6;
            dot.Background = new SolidColorBrush(i == index ? Color.FromArgb(0xFF, 0xFF, 0xFF, 0xFF) : Color.FromArgb(0x66, 0xFF, 0xFF, 0xFF));
        }
    }
}
