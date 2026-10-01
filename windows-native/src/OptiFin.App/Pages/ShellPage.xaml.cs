using Microsoft.UI.Input;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using OptiFin.App.Controls;
using OptiFin.App.Services;
using Windows.System;

namespace OptiFin.App.Pages;

/// <summary>
/// Coquille une fois connecté : barre du haut intégrée à la barre de titre (logo et serveur,
/// rubriques Accueil / Bibliothèques / Recherche, menu du profil), transparente sur l'image à la
/// une puis opaque quand la page défile. Raccourcis : Ctrl+F (recherche), Alt+← et bouton
/// « précédent » de la souris.
/// </summary>
public sealed partial class ShellPage : Page
{
    private readonly List<(NavTab Tab, Type Page)> _tabs = [];

    public ShellPage()
    {
        InitializeComponent();
        Nav.ContentFrame = ContentFrame;
        Logo.Source = new BitmapImage(new Uri(Path.Combine(AppContext.BaseDirectory, "Assets", "Logo.png")));
        if (AppServices.Session is { } session)
        {
            ServerName.Text = session.Server.Name;
            UserName.Text = session.Account.UserName;
            var avatar = session.Account.AvatarTag is null ? null
                : AppServices.Images?.UserAvatar(session.Account.UserId, 32, 2, session.Account.AvatarTag);
            AvatarHost.Child = Ui.Avatar(session.Account.UserName, avatar, 32);
            ToolTipService.SetToolTip(Brand, $"{session.Server.Name} · {session.Server.BaseUrl}");
        }

        AddTab("Accueil", "", typeof(HomePage));
        AddTab("Bibliothèques", "", typeof(LibrariesPage));
        AddTab("Recherche", "", typeof(SearchPage));
        ProfileButton.Flyout = ProfileMenu();

        BackButton.Click += (_, _) => Nav.Back();
        // Nav.Section vide l'historique après la navigation : on remet le bouton à jour ensuite.
        Nav.ContentNavigated += UpdateBackButton;
        Nav.Scrolled += OnScrolled;
        Loaded += (_, _) =>
        {
            // Focus initial sur la page elle-même : pas de cadre de focus au lancement.
            IsTabStop = true;
            UseSystemFocusVisuals = false;
            Focus(FocusState.Programmatic);
            Nav.ContentNavigated -= UpdateBackButton;
            Nav.ContentNavigated += UpdateBackButton;
            Nav.Scrolled -= OnScrolled;
            Nav.Scrolled += OnScrolled;
            // La barre du haut sert de barre de titre : seule la zone vide déplace la fenêtre.
            Nav.Window.UseTitleBar(DragArea);
            UpdateCaptionInset();
        };
        Unloaded += (_, _) =>
        {
            Nav.ContentNavigated -= UpdateBackButton;
            Nav.Scrolled -= OnScrolled;
            Nav.Window.UseTitleBar(null);
        };
        ContentFrame.Navigated += (_, e) =>
        {
            UpdateBackButton();
            OnScrolled(0);
            // Fiche, bibliothèque… : la rubrique d'origine reste en surbrillance.
            if (_tabs.Any(t => t.Page == e.SourcePageType))
                foreach (var (tab, page) in _tabs) tab.Selected = page == e.SourcePageType;
        };
        SizeChanged += (_, e) =>
        {
            // Fenêtre étroite : nom du serveur masqué, puis rubriques réduites à leur icône.
            var compact = e.NewSize.Width < 1100;
            ServerName.Visibility = compact ? Visibility.Collapsed : Visibility.Visible;
            UserName.Visibility = compact ? Visibility.Collapsed : Visibility.Visible;
            foreach (var (tab, _) in _tabs) tab.Compact = e.NewSize.Width < 860;
            UpdateCaptionInset();
        };

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

    private void AddTab(string label, string glyph, Type page)
    {
        var tab = new NavTab(label, glyph);
        tab.Activated += () => Nav.Section(page);
        Tabs.Children.Add(tab);
        _tabs.Add((tab, page));
    }

    private static MenuFlyout ProfileMenu()
    {
        var menu = new MenuFlyout { Placement = Microsoft.UI.Xaml.Controls.Primitives.FlyoutPlacementMode.BottomEdgeAlignedRight };
        var settings = new MenuFlyoutItem { Text = "Réglages", Icon = new FontIcon { Glyph = "" } };
        settings.Click += (_, _) => Nav.Go(typeof(SettingsPage));
        var change = new MenuFlyoutItem { Text = "Changer de compte", Icon = new FontIcon { Glyph = "" } };
        change.Click += (_, _) => Nav.PushRoot(typeof(ConnectPage));
        var signOut = new MenuFlyoutItem { Text = "Se déconnecter", Icon = new FontIcon { Glyph = "" } };
        signOut.Click += async (_, _) => await AppServices.SignOutAsync();
        menu.Items.Add(settings);
        menu.Items.Add(new MenuFlyoutSeparator());
        menu.Items.Add(change);
        menu.Items.Add(signOut);
        return menu;
    }

    private void UpdateBackButton() =>
        BackButton.Visibility = ContentFrame.CanGoBack ? Visibility.Visible : Visibility.Collapsed;

    /// <summary>Barre opaque dès que le contenu défile sous elle.</summary>
    private void OnScrolled(double offset) => SolidBar.Opacity = offset > 24 ? 1 : 0;

    /// <summary>Réserve la place des boutons de la fenêtre (réduire, agrandir, fermer).</summary>
    private void UpdateCaptionInset()
    {
        if (XamlRoot is null) return;
        var inset = Nav.Window.AppWindow.TitleBar.RightInset / XamlRoot.RasterizationScale;
        CaptionColumn.Width = new GridLength(Math.Max(inset, 46) + 16);
    }
}

/// <summary>Rubrique de la barre du haut : pastille au survol, soulignée d'un trait d'accent une fois choisie.</summary>
public sealed partial class NavTab : Grid
{
    private readonly TextBlock _label;
    private readonly FontIcon _icon;
    private readonly Border _indicator;
    private readonly Border _pill;
    private bool _selected;
    private bool _hovered;

    public event Action? Activated;

    public NavTab(string label, string glyph)
    {
        Height = 40;
        IsTabStop = true;
        UseSystemFocusVisuals = true;
        CornerRadius = new CornerRadius(20);
        ProtectedCursor = InputSystemCursor.Create(InputSystemCursorShape.Hand);
        _pill = new Border
        {
            CornerRadius = new CornerRadius(20),
            Background = new SolidColorBrush(Windows.UI.Color.FromArgb(0, 0xFF, 0xFF, 0xFF)),
            BackgroundTransition = new BrushTransition { Duration = TimeSpan.FromMilliseconds(150) },
        };
        Children.Add(_pill);
        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(16, 0, 16, 0) };
        _icon = new FontIcon { Glyph = glyph, FontSize = 15, Visibility = Visibility.Collapsed };
        _label = new TextBlock { Text = label, FontSize = 15, VerticalAlignment = VerticalAlignment.Center };
        row.Children.Add(_icon);
        row.Children.Add(_label);
        Children.Add(row);
        _indicator = new Border
        {
            Height = 3, Width = 18, CornerRadius = new CornerRadius(2), Background = Ui.Res("OFAccentBrush"),
            HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Bottom, Margin = new Thickness(0, 0, 0, 2),
            Opacity = 0, OpacityTransition = new ScalarTransition { Duration = TimeSpan.FromMilliseconds(200) },
            ScaleTransition = new Vector3Transition { Duration = TimeSpan.FromMilliseconds(250) },
            CenterPoint = new System.Numerics.Vector3(9, 1.5f, 0),
        };
        Children.Add(_indicator);
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

    public bool Compact
    {
        set
        {
            _label.Visibility = value ? Visibility.Collapsed : Visibility.Visible;
            _icon.Visibility = value ? Visibility.Visible : Visibility.Collapsed;
        }
    }

    private void Refresh()
    {
        _pill.Background = new SolidColorBrush(Windows.UI.Color.FromArgb(_hovered ? (byte)0x1F : (byte)0, 0xFF, 0xFF, 0xFF));
        var brush = Ui.Res(_selected || _hovered ? "OFTextPrimaryBrush" : "OFTextSecondaryBrush");
        _label.Foreground = brush;
        _icon.Foreground = brush;
        _label.FontWeight = _selected ? Microsoft.UI.Text.FontWeights.SemiBold : Microsoft.UI.Text.FontWeights.Normal;
        _indicator.Opacity = _selected ? 1 : 0;
        _indicator.Scale = _selected ? System.Numerics.Vector3.One : new System.Numerics.Vector3(0.2f, 1, 1);
    }
}
