using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Navigation;
using OptiFin.App.Controls;
using OptiFin.App.Services;
using OptiFin.Core.Api;
using OptiFin.Core.Auth;
using OptiFin.Core.Media;

namespace OptiFin.App.Pages;

/// <summary>Connexion à un serveur : profils, identifiant et mot de passe, ou Quick Connect.</summary>
public sealed partial class LoginPage : Page
{
    private JellyfinServer _server = null!;
    private readonly TextBox _username = new() { PlaceholderText = "Nom d’utilisateur", FontSize = 16, Padding = new Thickness(14, 10, 14, 10), CornerRadius = new CornerRadius(12) };
    private readonly PasswordBox _password = new() { PlaceholderText = "Mot de passe", FontSize = 16, Padding = new Thickness(14, 10, 14, 10), CornerRadius = new CornerRadius(12) };
    private readonly TextBlock _error = new() { Foreground = Ui.Res("OFDangerBrush"), TextWrapping = TextWrapping.Wrap, Visibility = Visibility.Collapsed };
    private readonly Button _signIn = Ui.Primary("Se connecter");
    private readonly StackPanel _users = new() { Orientation = Orientation.Horizontal, Spacing = 20 };

    public LoginPage()
    {
        InitializeComponent();
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        var request = (LoginRequest)e.Parameter;
        _server = request.Server;
        _username.Text = request.UserName ?? "";
        ServerName.Text = _server.Name;
        ServerInfo.Text = $"{_server.BaseUrl} · Jellyfin {_server.Version}";
        _ = BuildAsync();
    }

    private async Task BuildAsync()
    {
        var quickConnect = AppServices.Auth.IsQuickConnectEnabledAsync(_server);
        var users = AppServices.Auth.PublicUsersAsync(_server);

        var back = Ui.Secondary("Changer de serveur", "");
        back.Click += (_, _) => Nav.Root(typeof(ConnectPage));

        if (await quickConnect)
        {
            Subtitle.Text = "Le plus simple : Quick Connect.";
            var qc = Ui.Primary("Se connecter avec Quick Connect", "");
            qc.HorizontalAlignment = HorizontalAlignment.Stretch;
            qc.Click += (_, _) => _ = QuickConnectAsync();
            Form.Children.Add(qc);
            Form.Children.Add(new TextBlock
            {
                Text = "Un code s’affiche : validez-le depuis Jellyfin sur votre téléphone.",
                Style = Ui.StyleOf("OFCaption"),
                TextWrapping = TextWrapping.Wrap,
            });
            Form.Children.Add(Ui.Section("Ou avec un mot de passe"));
        }

        var list = await users;
        if (list.Count > 0)
        {
            var images = new ImageUrls(_server.BaseUrl);
            foreach (var u in list)
            {
                var avatar = Ui.Avatar(u.Name, u.AvatarTag is null ? null : images.UserAvatar(u.Id, 64, 2, u.AvatarTag), 64);
                var cell = new HandGrid { IsTabStop = true, UseSystemFocusVisuals = true, CornerRadius = new CornerRadius(12), Padding = new Thickness(6) };
                var stack = new StackPanel { Spacing = 6 };
                stack.Children.Add(avatar);
                stack.Children.Add(new TextBlock { Text = u.Name, Style = Ui.StyleOf("OFCaption"), HorizontalAlignment = HorizontalAlignment.Center, MaxWidth = 84 });
                cell.Children.Add(stack);
                Ui.Clickable(cell, () =>
                {
                    _username.Text = u.Name;
                    _password.Focus(FocusState.Programmatic);
                }, new SolidColorBrush(Microsoft.UI.Colors.Transparent), Ui.Res("OFSurfaceBrush"));
                _users.Children.Add(cell);
            }
            Form.Children.Add(new ScrollViewer
            {
                Content = _users,
                HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
                VerticalScrollBarVisibility = ScrollBarVisibility.Disabled,
                HorizontalScrollMode = ScrollMode.Enabled,
                VerticalScrollMode = ScrollMode.Disabled,
            });
        }

        Form.Children.Add(_username);
        Form.Children.Add(_password);
        Form.Children.Add(_error);
        _signIn.HorizontalAlignment = HorizontalAlignment.Stretch;
        _signIn.Click += (_, _) => _ = LoginAsync();
        _password.KeyDown += (_, e) =>
        {
            if (e.Key == Windows.System.VirtualKey.Enter) _ = LoginAsync();
        };
        Form.Children.Add(_signIn);
        back.HorizontalAlignment = HorizontalAlignment.Stretch;
        Form.Children.Add(back);
        (_username.Text.Length > 0 ? (Control)_password : _username).Focus(FocusState.Programmatic);
    }

    private async Task LoginAsync()
    {
        if (string.IsNullOrWhiteSpace(_username.Text))
        {
            ShowError("Saisissez votre nom d’utilisateur.");
            return;
        }
        _error.Visibility = Visibility.Collapsed;
        _signIn.IsEnabled = false;
        try
        {
            var session = await AppServices.Auth.LoginAsync(_server, _username.Text.Trim(), _password.Password);
            _password.Password = "";
            AppServices.SignIn(session);
        }
        catch (ApiException e)
        {
            ShowError(e.UserMessage);
        }
        finally
        {
            _signIn.IsEnabled = true;
        }
    }

    private async Task QuickConnectAsync()
    {
        using var cts = new CancellationTokenSource();
        var code = new TextBlock
        {
            FontSize = 44, FontWeight = Microsoft.UI.Text.FontWeights.Bold, CharacterSpacing = 400,
            HorizontalAlignment = HorizontalAlignment.Center, IsTextSelectionEnabled = true,
        };
        var status = new TextBlock { Text = "En attente d’autorisation…", Style = Ui.StyleOf("OFCaption"), HorizontalAlignment = HorizontalAlignment.Center };
        var content = new StackPanel { Spacing = 16, Width = 420 };
        content.Children.Add(new TextBlock
        {
            Text = "Sur un appareil déjà connecté, ouvrez Jellyfin › Profil › Quick Connect et saisissez ce code.",
            TextWrapping = TextWrapping.Wrap,
            Foreground = Ui.Res("OFTextSecondaryBrush"),
        });
        content.Children.Add(new ProgressRing { IsActive = true, Width = 32, Height = 32 });
        content.Children.Add(code);
        content.Children.Add(status);
        var dialog = new ContentDialog
        {
            Title = "Quick Connect",
            Content = content,
            CloseButtonText = "Annuler",
            XamlRoot = XamlRoot,
            RequestedTheme = ElementTheme.Dark,
        };
        var shown = dialog.ShowAsync();
        try
        {
            var ticket = await AppServices.Auth.InitiateQuickConnectAsync(_server, cts.Token);
            ((ProgressRing)content.Children[1]).Visibility = Visibility.Collapsed;
            code.Text = ticket.Code;
            var waiting = AppServices.Auth.AwaitQuickConnectAsync(_server, ticket, cts.Token);
            var finished = await Task.WhenAny(waiting, shown.AsTask());
            if (finished == waiting)
            {
                var session = await waiting;
                dialog.Hide();
                AppServices.SignIn(session);
            }
            else
            {
                cts.Cancel();
            }
        }
        catch (ApiException e)
        {
            status.Text = e.UserMessage;
            status.Foreground = Ui.Res("OFDangerBrush");
        }
        catch (TimeoutException)
        {
            status.Text = "Le code a expiré. Réessayez.";
        }
        catch (OperationCanceledException)
        {
        }
    }

    private void ShowError(string message)
    {
        _error.Text = message;
        _error.Visibility = Visibility.Visible;
    }
}
