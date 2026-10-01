using Microsoft.UI.Input;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Windows.System;

namespace OptiFin.App.Controls;

/// <summary>Petits éléments d'interface réutilisés (style OptiFin), construits en code.</summary>
public static class Ui
{
    public static Brush Res(string key) => Application.Current.Resources[key] switch
    {
        Brush b => b,
        WinRT.IWinRTObject o => WinRT.CastExtensions.As<Brush>(o),
        var o => throw new InvalidCastException($"{key} : {o?.GetType().FullName ?? "absent"}"),
    };
    /// <summary>
    /// Style d'application. En NativeAOT, la projection WinRT peut rendre un simple DependencyObject
    /// pour un Style défini en XAML : on demande alors explicitement l'interface du Style.
    /// </summary>
    public static Style StyleOf(string key) => Application.Current.Resources[key] switch
    {
        Style s => s,
        WinRT.IWinRTObject o => WinRT.CastExtensions.As<Style>(o),
        var o => throw new InvalidCastException($"{key} : {o?.GetType().FullName ?? "absent"}"),
    };

    public static TextBlock Text(string text, string style = "OFBody", Brush? color = null)
    {
        var t = new TextBlock { Text = text, Style = StyleOf(style) };
        if (color != null) t.Foreground = color;
        return t;
    }

    /// <summary>Intertitre discret en capitales (« COMPTES », « SUR CE RÉSEAU »…).</summary>
    public static TextBlock Section(string text) => new()
    {
        Text = text.ToUpperInvariant(),
        FontSize = 12,
        FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
        CharacterSpacing = 120,
        Foreground = Res("OFTextTertiaryBrush"),
        Margin = new Thickness(2, 16, 0, 4),
    };

    public static Button Primary(string label, string? glyph = null) => Button(label, glyph, "OFPrimaryButton");
    public static Button Secondary(string label, string? glyph = null) => Button(label, glyph, "OFSecondaryButton");

    private static Button Button(string label, string? glyph, string style)
    {
        var content = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10 };
        if (glyph != null) content.Children.Add(new FontIcon { Glyph = glyph, FontSize = 16 });
        content.Children.Add(new TextBlock { Text = label, VerticalAlignment = VerticalAlignment.Center });
        return new Button { Content = content, Style = StyleOf(style) };
    }

    /// <summary>Bouton rond à icône (lecture depuis le début, vu, favori…).</summary>
    public static Button Round(string glyph, string tooltip, double size = 44)
    {
        var b = new Button
        {
            Style = StyleOf("OFIconButton"),
            Width = size,
            Height = size,
            CornerRadius = new CornerRadius(size / 2),
            Content = new FontIcon { Glyph = glyph, FontSize = size * 0.38 },
        };
        ToolTipService.SetToolTip(b, tooltip);
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(b, tooltip);
        return b;
    }

    /// <summary>Avatar rond : image, sinon initiales.</summary>
    public static FrameworkElement Avatar(string name, Uri? image, double size = 40)
    {
        var grid = new Grid { Width = size, Height = size, CornerRadius = new CornerRadius(size / 2), Background = Res("OFSurfaceRaisedBrush") };
        var parts = name.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var initials = parts.Length switch
        {
            0 => "?",
            1 => parts[0][..1].ToUpperInvariant(),
            _ => (parts[0][..1] + parts[^1][..1]).ToUpperInvariant(),
        };
        grid.Children.Add(new TextBlock
        {
            Text = initials, FontSize = size * 0.4, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
            HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center,
            Foreground = Res("OFTextSecondaryBrush"),
        });
        if (image != null)
        {
            grid.Children.Add(new Image
            {
                Source = new BitmapImage(image) { DecodePixelWidth = (int)(size * 2) },
                Stretch = Stretch.UniformToFill,
            });
        }
        return grid;
    }

    /// <summary>Ligne cliquable (compte, serveur) : survol, focus clavier, chevron.</summary>
    public static Grid Tile(FrameworkElement leading, string title, string subtitle, Action onSelect)
    {
        var tile = new HandGrid
        {
            Padding = new Thickness(14),
            CornerRadius = new CornerRadius(12),
            Background = Res("OFSurfaceBrush"),
            IsTabStop = true,
            UseSystemFocusVisuals = true,
            ColumnSpacing = 14,
        };
        tile.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        tile.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        tile.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        tile.Children.Add(leading);
        var texts = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        texts.Children.Add(new TextBlock { Text = title, FontSize = 16, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, TextTrimming = TextTrimming.CharacterEllipsis });
        texts.Children.Add(new TextBlock { Text = subtitle, Style = StyleOf("OFCaption") });
        Grid.SetColumn(texts, 1);
        tile.Children.Add(texts);
        var chevron = new FontIcon { Glyph = "", FontSize = 14, Foreground = Res("OFTextTertiaryBrush") };
        Grid.SetColumn(chevron, 2);
        tile.Children.Add(chevron);
        Clickable(tile, onSelect, Res("OFSurfaceBrush"), Res("OFSurfaceRaisedBrush"));
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(tile, title);
        return tile;
    }

    /// <summary>Rend un panneau cliquable : main au survol, fond éclairci, Entrée / Espace.</summary>
    public static void Clickable(Panel panel, Action onSelect, Brush normal, Brush hover)
    {
        panel.PointerEntered += (_, _) => panel.Background = hover;
        panel.PointerExited += (_, _) => panel.Background = normal;
        panel.Tapped += (_, _) => onSelect();
        panel.KeyDown += (_, e) =>
        {
            if (e.Key is VirtualKey.Enter or VirtualKey.Space)
            {
                onSelect();
                e.Handled = true;
            }
        };
    }

}

/// <summary>Grille avec le curseur « main » (éléments cliquables).</summary>
public partial class HandGrid : Grid
{
    public HandGrid() => ProtectedCursor = InputSystemCursor.Create(InputSystemCursorShape.Hand);
}
