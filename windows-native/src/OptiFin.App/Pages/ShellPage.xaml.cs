using Microsoft.UI.Input;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using OptiFin.App.Services;
using Windows.System;

namespace OptiFin.App.Pages;

/// <summary>
/// Coquille une fois connecté : barre latérale (Accueil, Bibliothèques, Recherche, Réglages) et
/// zone de contenu. Raccourcis : Ctrl+F (recherche), Alt+← et bouton « précédent » de la souris.
/// </summary>
public sealed partial class ShellPage : Page
{
    private readonly List<(SidebarItem Item, Type Page)> _items = [];

    public ShellPage()
    {
        InitializeComponent();
        Nav.ContentFrame = ContentFrame;

        AddItem(MainItems, "", "Accueil", typeof(HomePage));
        AddItem(MainItems, "", "Bibliothèques", typeof(LibrariesPage));
        AddItem(MainItems, "", "Recherche", typeof(SearchPage));
        AddItem(BottomItems, "", "Réglages", typeof(SettingsPage));

        BackButton.Click += (_, _) => Nav.Back();
        // Nav.Section vide l'historique après la navigation : on remet le bouton à jour ensuite.
        Nav.ContentNavigated += UpdateBackButton;
        Loaded += (_, _) =>
        {
            Nav.ContentNavigated -= UpdateBackButton;
            Nav.ContentNavigated += UpdateBackButton;
        };
        Unloaded += (_, _) => Nav.ContentNavigated -= UpdateBackButton;
        ContentFrame.Navigated += (_, e) =>
        {
            UpdateBackButton();
            foreach (var (item, page) in _items) item.Selected = page == e.SourcePageType;
        };
        SizeChanged += (_, e) => SetWide(e.NewSize.Width >= 1100);

        KeyboardAccelerators.Add(Accelerator(VirtualKey.F, VirtualKeyModifiers.Control, () => Nav.Section(typeof(SearchPage))));
        KeyboardAccelerators.Add(Accelerator(VirtualKey.Left, VirtualKeyModifiers.Menu, () => Nav.Back()));
        KeyboardAccelerators.Add(Accelerator(VirtualKey.GoBack, VirtualKeyModifiers.None, () => Nav.Back()));
        // Bouton « précédent » des souris à 5 boutons.
        PointerPressed += (_, e) =>
        {
            if (e.GetCurrentPoint(this).Properties.IsXButton1Pressed && Nav.Back()) e.Handled = true;
        };

        Nav.Section(typeof(HomePage));
    }

    private static KeyboardAccelerator Accelerator(VirtualKey key, VirtualKeyModifiers modifiers, Action action)
    {
        var a = new KeyboardAccelerator { Key = key, Modifiers = modifiers };
        a.Invoked += (_, e) =>
        {
            action();
            e.Handled = true;
        };
        return a;
    }

    private void AddItem(Panel panel, string glyph, string label, Type page)
    {
        var item = new SidebarItem(glyph, label);
        item.Activated += () =>
        {
            if (page == typeof(SettingsPage)) Nav.Go(page);
            else Nav.Section(page);
        };
        panel.Children.Add(item);
        _items.Add((item, page));
    }

    private void UpdateBackButton() =>
        BackButton.Visibility = ContentFrame.CanGoBack ? Visibility.Visible : Visibility.Collapsed;

    private void SetWide(bool wide)
    {
        Sidebar.Width = wide ? 232 : 72;
        Brand.Text = wide ? "OptiFin" : "O";
        Brand.Margin = new Thickness(wide ? 10 : 0, 0, 0, 24);
        Brand.HorizontalAlignment = wide ? HorizontalAlignment.Left : HorizontalAlignment.Center;
        foreach (var (item, _) in _items) item.Wide = wide;
    }
}

/// <summary>Rubrique de la barre latérale : survol, sélection, clavier, info-bulle en mode réduit.</summary>
public sealed partial class SidebarItem : Grid
{
    private readonly TextBlock _label;
    private readonly FontIcon _icon;
    private bool _selected;
    private bool _hovered;

    public event Action? Activated;

    public SidebarItem(string glyph, string label)
    {
        Height = 44;
        CornerRadius = new CornerRadius(12);
        IsTabStop = true;
        UseSystemFocusVisuals = true;
        Padding = new Thickness(12, 0, 12, 0);
        ProtectedCursor = InputSystemCursor.Create(InputSystemCursorShape.Hand);
        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 16, VerticalAlignment = VerticalAlignment.Center };
        _icon = new FontIcon { Glyph = glyph, FontSize = 18 };
        _label = new TextBlock { Text = label, FontSize = 14, VerticalAlignment = VerticalAlignment.Center };
        row.Children.Add(_icon);
        row.Children.Add(_label);
        Children.Add(row);
        ToolTipService.SetToolTip(this, label);
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(this, label);
        PointerEntered += (_, _) => { _hovered = true; Refresh(); };
        PointerExited += (_, _) => { _hovered = false; Refresh(); };
        Tapped += (_, _) => Activated?.Invoke();
        KeyDown += (_, e) =>
        {
            if (e.Key is VirtualKey.Enter or VirtualKey.Space)
            {
                Activated?.Invoke();
                e.Handled = true;
            }
        };
        Refresh();
    }

    public bool Selected
    {
        get => _selected;
        set
        {
            _selected = value;
            Refresh();
        }
    }

    public bool Wide
    {
        set
        {
            _label.Visibility = value ? Visibility.Visible : Visibility.Collapsed;
            Padding = new Thickness(value ? 12 : 0, 0, value ? 12 : 0, 0);
            ((StackPanel)Children[0]).HorizontalAlignment = value ? HorizontalAlignment.Left : HorizontalAlignment.Center;
        }
    }

    private void Refresh()
    {
        var res = Application.Current.Resources;
        Background = new SolidColorBrush(_selected
            ? Windows.UI.Color.FromArgb(0x1F, 0xFF, 0xFF, 0xFF)
            : _hovered ? Windows.UI.Color.FromArgb(0x0F, 0xFF, 0xFF, 0xFF) : Windows.UI.Color.FromArgb(0, 0, 0, 0));
        _icon.Foreground = (Brush)res[_selected ? "OFAccentBrush" : _hovered ? "OFTextPrimaryBrush" : "OFTextSecondaryBrush"];
        _label.Foreground = (Brush)res[_selected || _hovered ? "OFTextPrimaryBrush" : "OFTextSecondaryBrush"];
        _label.FontWeight = _selected ? Microsoft.UI.Text.FontWeights.SemiBold : Microsoft.UI.Text.FontWeights.Normal;
    }
}
