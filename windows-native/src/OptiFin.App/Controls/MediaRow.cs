using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using OptiFin.Core.Media;

namespace OptiFin.App.Controls;

/// <summary>
/// Rangée horizontale de cartes (titre, « Tout voir »). À la souris, deux flèches apparaissent au
/// survol pour avancer ou reculer d'une page ; la molette défile aussi (Maj + molette).
/// </summary>
public sealed partial class MediaRow : Grid
{
    public event Action<MediaItem>? ItemActivated;
    public event Action? SeeAll;

    private readonly ScrollViewer _scroll;
    private readonly Button _back;
    private readonly Button _forward;

    public static double CardWidth(CardStyle style) => style switch
    {
        CardStyle.Landscape => 300,
        CardStyle.Square => 180,
        _ => 168,
    };

    public MediaRow(string title, IReadOnlyList<MediaItem> items, CardStyle style, double gutter, bool seeAll = false)
    {
        RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var header = new Grid { Margin = new Thickness(gutter, 0, gutter, 12) };
        header.Children.Add(new TextBlock { Text = title, Style = Ui.StyleOf("OFTitle2") });
        if (seeAll)
        {
            var link = new HyperlinkButton
            {
                Content = "Tout voir",
                HorizontalAlignment = HorizontalAlignment.Right,
                Foreground = Ui.Res("OFTextSecondaryBrush"),
                Padding = new Thickness(8, 2, 8, 2),
            };
            link.Click += (_, _) => SeeAll?.Invoke();
            header.Children.Add(link);
        }
        Children.Add(header);

        var width = CardWidth(style);
        var panel = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 16,
            Padding = new Thickness(gutter, 8, gutter, 12),
            XYFocusKeyboardNavigation = Microsoft.UI.Xaml.Input.XYFocusKeyboardNavigationMode.Enabled,
            // Les cartes arrivent en cascade, de droite à gauche.
            ChildrenTransitions = Ui.Entrance(vertical: 0, horizontal: 60),
        };
        foreach (var item in items)
        {
            var card = new MediaCard(item, style, width);
            card.Activated += i => ItemActivated?.Invoke(i);
            panel.Children.Add(card);
        }
        _scroll = new ScrollViewer
        {
            Content = panel,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Hidden,
            HorizontalScrollMode = ScrollMode.Enabled,
            VerticalScrollMode = ScrollMode.Disabled,
            VerticalScrollBarVisibility = ScrollBarVisibility.Disabled,
        };
        var body = new Grid();
        body.Children.Add(_scroll);
        _back = Arrow("", HorizontalAlignment.Left, gutter, -1);
        _forward = Arrow("", HorizontalAlignment.Right, gutter, 1);
        body.Children.Add(_back);
        body.Children.Add(_forward);
        SetRow(body, 1);
        Children.Add(body);

        body.PointerEntered += (_, _) => UpdateArrows(true);
        body.PointerExited += (_, _) => UpdateArrows(false);
        _scroll.ViewChanged += (_, _) => UpdateArrows(_hovered);
    }

    private bool _hovered;

    private Button Arrow(string glyph, HorizontalAlignment side, double gutter, int direction)
    {
        var button = new Button
        {
            Content = new FontIcon { Glyph = glyph, FontSize = 18 },
            Width = 44,
            Height = 44,
            Padding = new Thickness(0),
            CornerRadius = new CornerRadius(22),
            HorizontalAlignment = side,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(gutter * 0.25, 0, gutter * 0.25, 40),
            Background = Ui.Res("OFGlassBrush"),
            BorderBrush = new SolidColorBrush(Windows.UI.Color.FromArgb(0x33, 0xFF, 0xFF, 0xFF)),
            BorderThickness = new Thickness(1),
            Opacity = 0,
            IsHitTestVisible = false,
            IsTabStop = false,
            OpacityTransition = new ScalarTransition { Duration = TimeSpan.FromMilliseconds(150) },
        };
        ToolTipService.SetToolTip(button, direction < 0 ? "Précédents" : "Suivants");
        button.Click += (_, _) =>
            _scroll.ChangeView(_scroll.HorizontalOffset + direction * _scroll.ViewportWidth * 0.85, null, null);
        return button;
    }

    private void UpdateArrows(bool hovered)
    {
        _hovered = hovered;
        var canBack = _scroll.HorizontalOffset > 1;
        var canForward = _scroll.HorizontalOffset < _scroll.ScrollableWidth - 1;
        Show(_back, hovered && canBack);
        Show(_forward, hovered && canForward);
    }

    private static void Show(Button b, bool visible)
    {
        b.Opacity = visible ? 1 : 0;
        b.IsHitTestVisible = visible;
    }
}
