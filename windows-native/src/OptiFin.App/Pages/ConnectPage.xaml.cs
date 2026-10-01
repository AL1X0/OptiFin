using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using OptiFin.App.Controls;
using OptiFin.App.Services;
using OptiFin.Core.Api;
using OptiFin.Core.Auth;
using OptiFin.Core.Media;

namespace OptiFin.App.Pages;

/// <summary>Connexion : comptes enregistrés, serveurs du réseau local, adresse saisie.</summary>
public sealed partial class ConnectPage : Page
{
    private readonly StackPanel _servers = new() { Spacing = 8 };
    private readonly TextBox _address = new()
    {
        PlaceholderText = "https://jellyfin.exemple.fr",
        FontSize = 16,
        Padding = new Thickness(14, 10, 14, 10),
        CornerRadius = new CornerRadius(12),
        InputScope = new Microsoft.UI.Xaml.Input.InputScope { Names = { new Microsoft.UI.Xaml.Input.InputScopeName(Microsoft.UI.Xaml.Input.InputScopeNameValue.Url) } },
    };
    private readonly TextBlock _error = new() { Foreground = Ui.Res("OFDangerBrush"), TextWrapping = TextWrapping.Wrap, Visibility = Visibility.Collapsed };
    private readonly Button _continue = Ui.Primary("Continuer");
    private readonly ProgressRing _progress = new() { IsActive = false, Width = 20, Height = 20 };
    private readonly CancellationTokenSource _cts = new();

    public ConnectPage()
    {
        InitializeComponent();
        RootGrid.Children.Insert(0, new WelcomeBackdrop());
        Column.Children.Insert(0, new WelcomeLogo());
        Unloaded += (_, _) => _cts.Cancel();

        var accounts = AppServices.Accounts.Accounts();
        if (accounts.Count > 0)
        {
            Choices.Children.Add(Ui.Section("Comptes"));
            foreach (var a in accounts)
            {
                var avatar = new ImageUrls(new Uri(a.BaseUrl)).UserAvatar(a.UserId, 40, 2, a.AvatarTag);
                Choices.Children.Add(Ui.Tile(Ui.Avatar(a.UserName, a.AvatarTag is null ? null : avatar), a.UserName, a.ServerName,
                    () => Resume(a)));
            }
        }

        Choices.Children.Add(Ui.Section("Sur ce réseau"));
        _servers.Children.Add(new TextBlock { Text = "Recherche…", Style = Ui.StyleOf("OFCaption") });
        Choices.Children.Add(_servers);

        Choices.Children.Add(Ui.Section("Adresse du serveur"));
        _address.KeyDown += (_, e) =>
        {
            if (e.Key == Windows.System.VirtualKey.Enter) _ = ConnectAsync(_address.Text);
        };
        Choices.Children.Add(_address);
        Choices.Children.Add(_error);
        _continue.HorizontalAlignment = HorizontalAlignment.Stretch;
        _continue.Margin = new Thickness(0, 8, 0, 0);
        _continue.Click += (_, _) => _ = ConnectAsync(_address.Text);
        Choices.Children.Add(_continue);
        Choices.Children.Add(_progress);

        _ = DiscoverAsync();
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        if (e.Parameter is string message) ShowError(message);
    }

    private async Task DiscoverAsync()
    {
        var found = 0;
        try
        {
            await foreach (var list in ServerDiscovery.DiscoverAsync(ct: _cts.Token))
            {
                found = list.Count;
                _servers.Children.Clear();
                foreach (var s in list)
                {
                    var icon = new Grid { Width = 40, Height = 40, CornerRadius = new CornerRadius(20), Background = Ui.Res("OFSurfaceRaisedBrush") };
                    icon.Children.Add(new FontIcon { Glyph = "", FontSize = 18, Foreground = Ui.Res("OFTextSecondaryBrush") });
                    _servers.Children.Add(Ui.Tile(icon, s.Name, s.Address.ToString(), () => _ = ConnectAsync(s.Address.ToString())));
                }
            }
        }
        catch (OperationCanceledException)
        {
            return;
        }
        if (found == 0)
        {
            _servers.Children.Clear();
            _servers.Children.Add(new TextBlock { Text = "Aucun serveur détecté automatiquement.", Style = Ui.StyleOf("OFCaption") });
        }
    }

    private void Resume(StoredAccount account)
    {
        AppServices.SwitchTo(account.Id);
        if (AppServices.Session?.Account.Id == account.Id) return;
        // Jeton perdu : on repasse par la connexion de ce serveur, identifiant prérempli.
        Nav.PushRoot(typeof(LoginPage), new LoginRequest(account.Server, account.UserName));
    }

    private async Task ConnectAsync(string input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            ShowError("Saisissez l’adresse de votre serveur.");
            return;
        }
        _error.Visibility = Visibility.Collapsed;
        _continue.IsEnabled = false;
        _progress.IsActive = true;
        try
        {
            var server = await AppServices.Auth.ProbeAsync(input, _cts.Token);
            Nav.PushRoot(typeof(LoginPage), new LoginRequest(server, null));
        }
        catch (ApiException e)
        {
            ShowError(e.UserMessage);
        }
        catch (OperationCanceledException)
        {
        }
        finally
        {
            _continue.IsEnabled = true;
            _progress.IsActive = false;
        }
    }

    private void ShowError(string message)
    {
        _error.Text = message;
        _error.Visibility = Visibility.Visible;
    }
}

public sealed record LoginRequest(JellyfinServer Server, string? UserName);
