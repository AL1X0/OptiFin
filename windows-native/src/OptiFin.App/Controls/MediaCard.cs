using System.Numerics;
using Microsoft.UI;
using Microsoft.UI.Input;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using OptiFin.App.Services;
using OptiFin.Core.Media;

namespace OptiFin.App.Controls;

public enum CardStyle { Poster, Landscape, Square }

/// <summary>
/// Carte d'un élément : image (affiche 2:3, paysage 16:9 ou carré), titre, sous-titre, progression,
/// pastille « vu ». Au survol : léger zoom, voile et bouton lecture (lecture directe ; le reste de la
/// carte ouvre la fiche). Activable au clavier.
/// </summary>
public sealed partial class MediaCard : Grid
{
    public MediaItem Item { get; }
    public event Action<MediaItem>? Activated;

    private readonly Border _hover;
    private readonly Border _frame;
    private readonly Border? _play;
    private bool _starting;
    private static readonly SolidColorBrush PlayIdle = new(Windows.UI.Color.FromArgb(0xE6, 0xFF, 0xFF, 0xFF));
    private static readonly SolidColorBrush PlayHover = new(Windows.UI.Color.FromArgb(0xFF, 0xFF, 0xFF, 0xFF));
    private static readonly SolidColorBrush NoStroke = new(Windows.UI.Color.FromArgb(0x14, 0xFF, 0xFF, 0xFF));
    private static readonly SolidColorBrush HoverStroke = new(Windows.UI.Color.FromArgb(0x8C, 0xFF, 0xFF, 0xFF));

    public MediaCard(MediaItem item, CardStyle style, double width)
    {
        Item = item;
        Width = width;
        IsTabStop = true;
        UseSystemFocusVisuals = true;
        CornerRadius = new CornerRadius(12);
        RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var height = style switch
        {
            CardStyle.Poster => width * 1.5,
            CardStyle.Square => width,
            _ => width * 9 / 16,
        };
        var imageRef = style == CardStyle.Landscape ? item.Landscape : item.Poster ?? item.Primary;
        var artwork = new Grid { Height = height, Background = Brush("OFSurfaceBrush") };
        if (AppServices.Images?.Maybe(imageRef, width, 1.5) is { } url)
        {
            artwork.Children.Add(Ui.FadeIn(new Image
            {
                Source = new BitmapImage(url) { DecodePixelWidth = (int)Math.Ceiling(width * 1.5), DecodePixelType = DecodePixelType.Physical },
                Stretch = Stretch.UniformToFill,
            }));
        }
        else
        {
            artwork.Children.Add(new TextBlock
            {
                Text = item.Name,
                Style = Ui.StyleOf("OFCaption"),
                TextWrapping = TextWrapping.Wrap,
                TextAlignment = TextAlignment.Center,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(12),
                MaxLines = 4,
            });
        }

        if (item.User.Progress is { } progress)
        {
            var bar = new ProgressBar
            {
                Value = progress * 100,
                Maximum = 100,
                Height = 3,
                MinHeight = 3,
                VerticalAlignment = VerticalAlignment.Bottom,
                Margin = new Thickness(10, 0, 10, 10),
                CornerRadius = new CornerRadius(2),
                Background = new SolidColorBrush(Windows.UI.Color.FromArgb(0x55, 0xFF, 0xFF, 0xFF)),
            };
            artwork.Children.Add(bar);
            // Barre aux couleurs du film (comme sur mobile).
            if (FilmAccent.Cached(item) is { } cached) bar.Foreground = new SolidColorBrush(cached);
            else
            {
                _ = FilmAccent.ForAsync(item).ContinueWith(t => bar.DispatcherQueue.TryEnqueue(() =>
                {
                    if (t.Result is { } c) bar.Foreground = new SolidColorBrush(c);
                }), TaskScheduler.Default);
            }
        }
        if (item.User.Played && item.Kind is not (MediaKind.Series or MediaKind.Season))
        {
            artwork.Children.Add(new Border
            {
                Width = 24, Height = 24, CornerRadius = new CornerRadius(12),
                Background = new SolidColorBrush(Windows.UI.Color.FromArgb(0xCC, 0, 0, 0)),
                HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Top,
                Margin = new Thickness(8),
                Child = new FontIcon { Glyph = "", FontSize = 12, Foreground = new SolidColorBrush(Colors.White) },
            });
        }

        // Survol : voile, et bouton lecture qui lance directement la lecture (le reste de la carte
        // ouvre la fiche). Série : prochain épisode à voir.
        _hover = new Border
        {
            Background = new SolidColorBrush(Windows.UI.Color.FromArgb(0x40, 0, 0, 0)),
            Opacity = 0,
            OpacityTransition = new ScalarTransition { Duration = TimeSpan.FromMilliseconds(150) },
            IsHitTestVisible = false,
        };
        artwork.Children.Add(_hover);
        if (item.Kind.IsPlayableVideo() || item.Kind == MediaKind.Series)
        {
            var playIcon = new FontIcon { Glyph = "", FontSize = 18, Foreground = new SolidColorBrush(Colors.Black) };
            _play = new Border
            {
                Width = 48, Height = 48, CornerRadius = new CornerRadius(24),
                Background = PlayIdle,
                HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center,
                Opacity = 0,
                OpacityTransition = new ScalarTransition { Duration = TimeSpan.FromMilliseconds(150) },
                ScaleTransition = new Vector3Transition { Duration = TimeSpan.FromMilliseconds(120) },
                CenterPoint = new Vector3(24, 24, 0),
                Child = playIcon,
            };
            _play.PointerEntered += (_, _) => { _play.Background = PlayHover; _play.Scale = new Vector3(1.12f, 1.12f, 1); };
            _play.PointerExited += (_, _) => { _play.Background = PlayIdle; _play.Scale = Vector3.One; };
            _play.Tapped += (_, e) =>
            {
                e.Handled = true;
                _ = PlayAsync();
            };
            Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(_play, "Lecture");
            artwork.Children.Add(_play);
        }

        _frame = new Border { CornerRadius = new CornerRadius(12), Child = artwork, BorderThickness = new Thickness(1), BorderBrush = NoStroke };
        var frame = _frame;
        Children.Add(frame);

        var text = new StackPanel { Margin = new Thickness(2, 8, 2, 0), Spacing = 1 };
        text.Children.Add(new TextBlock
        {
            Text = Title(item, style),
            FontSize = 14,
            FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
            Foreground = Brush("OFTextPrimaryBrush"),
            TextTrimming = TextTrimming.CharacterEllipsis,
            MaxLines = 1,
        });
        if (Subtitle(item, style) is { } subtitle)
        {
            text.Children.Add(new TextBlock { Text = subtitle, Style = Ui.StyleOf("OFCaption"), MaxLines = 1 });
        }
        SetRow(text, 1);
        Children.Add(text);

        ScaleTransition = new Vector3Transition { Duration = TimeSpan.FromMilliseconds(200) };
        SizeChanged += (_, e) => CenterPoint = new Vector3((float)e.NewSize.Width / 2, (float)height / 2, 0);
        PointerEntered += (_, _) => SetHover(true);
        PointerExited += (_, _) => SetHover(false);
        PointerCanceled += (_, _) => SetHover(false);
        Tapped += (_, e) =>
        {
            if (!e.Handled) Activated?.Invoke(Item);
        };
        KeyDown += OnKeyDown;
        GotFocus += (_, _) => SetHover(true);
        LostFocus += (_, _) => SetHover(false);
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(this, Title(item, style));
        ProtectedCursor = InputSystemCursor.Create(InputSystemCursorShape.Hand);
    }

    private void SetHover(bool on)
    {
        Scale = on ? new Vector3(1.05f, 1.05f, 1) : Vector3.One;
        _hover.Opacity = on ? 1 : 0;
        if (_play != null) _play.Opacity = on ? 1 : 0;
        _frame.BorderBrush = on ? HoverStroke : NoStroke;
    }

    /// <summary>Bouton lecture de la carte : film ou épisode lancé tel quel, série au prochain épisode.</summary>
    private async Task PlayAsync()
    {
        if (_starting) return;
        if (Item.Kind.IsPlayableVideo())
        {
            Player.PlayerLauncher.Play(Item);
            return;
        }
        if (AppServices.Media is not { } media) return;
        _starting = true;
        try
        {
            if (await media.NextUpForAsync(Item.Id) is { } next) Player.PlayerLauncher.Play(next);
            else Activated?.Invoke(Item);
        }
        catch (Exception e)
        {
            OptiFin.Core.Logging.AppLog.Error("card", "Lecture impossible", e);
            Activated?.Invoke(Item);
        }
        finally
        {
            _starting = false;
        }
    }

    /// <summary>Outil de capture : survol puis « clic » (test de l'élément touché) au centre ou en haut de l'affiche.</summary>
    internal void DevClick(bool center)
    {
        SetHover(true);
        var local = new Windows.Foundation.Point(ActualWidth / 2, center ? _frame.ActualHeight / 2 : 16);
        var point = TransformToVisual(null).TransformPoint(local);
        UIElement? hit = null;
        foreach (var e in VisualTreeHelper.FindElementsInHostCoordinates(point, XamlRoot.Content)) { hit = e; break; }
        OptiFin.Core.Logging.AppLog.Info("dev", $"Clic carte {(center ? "centre" : "haut")} : {(ReferenceEquals(hit, _play) || IsChild(hit, _play) ? "bouton lecture" : "carte")}");
        if (_play != null && (ReferenceEquals(hit, _play) || IsChild(hit, _play))) _ = PlayAsync();
        else Activated?.Invoke(Item);
    }

    private static bool IsChild(DependencyObject? e, DependencyObject? parent)
    {
        for (; e != null && parent != null; e = VisualTreeHelper.GetParent(e)) if (ReferenceEquals(e, parent)) return true;
        return false;
    }

    private void OnKeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key is Windows.System.VirtualKey.Enter or Windows.System.VirtualKey.Space)
        {
            Activated?.Invoke(Item);
            e.Handled = true;
        }
    }

    private static Brush Brush(string key) => Ui.Res(key);

    public static string Title(MediaItem i, CardStyle style) =>
        i.Kind == MediaKind.Episode && style == CardStyle.Landscape && i.SeriesName != null ? i.SeriesName : i.Name;

    public static string? Subtitle(MediaItem i, CardStyle style)
    {
        if (i.Kind == MediaKind.Episode)
        {
            return style == CardStyle.Landscape
                ? string.Join(" · ", new[] { i.EpisodeLabel, i.Name }.Where(s => !string.IsNullOrEmpty(s)))
                : i.EpisodeLabel;
        }
        if (i.Kind == MediaKind.Series && i.User.UnplayedCount is > 0 and var n)
            return $"{n} épisode{(n > 1 ? "s" : "")} non vu{(n > 1 ? "s" : "")}";
        return i.Year?.ToString();
    }
}
