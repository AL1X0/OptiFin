using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using OptiFin.App.Controls;
using OptiFin.App.Services;
using OptiFin.Core.Api;
using OptiFin.Core.Media;

namespace OptiFin.App.Pages;

/// <summary>Bibliothèques du serveur (Films, Séries…), en grandes tuiles paysage.</summary>
public sealed partial class LibrariesPage : Page
{
    private CancellationTokenSource? _cts;

    public LibrariesPage()
    {
        InitializeComponent();
        OptiFin.App.Controls.Ui.Translate(this);
        Nav.TrackScroll(Scroll);
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        _cts?.Cancel();
        _cts?.Dispose();
        _cts = null;
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        if (AppServices.Media is not { } media) return;
        _cts?.Cancel();
        _cts?.Dispose();
        _cts = new CancellationTokenSource();
        var ct = _cts.Token;
        Spinner.IsActive = true;
        try
        {
            var views = await media.UserViewsAsync(ct);
            if (ct.IsCancellationRequested) return;
            Grid.Children.Clear();
            foreach (var view in views)
            {
                var card = new MediaCard(view, CardStyle.Landscape, 320) { Margin = new Thickness(0, 0, 16, 16) };
                card.Activated += v => Nav.Go(typeof(LibraryPage), v);
                Grid.Children.Add(card);
            }
        }
        catch (OperationCanceledException)
        {
        }
        catch (ApiException ex)
        {
            Grid.Children.Clear();
            Grid.Children.Add(new TextBlock { Text = ex.UserMessage, Style = Ui.StyleOf("OFBody") });
        }
        finally
        {
            Spinner.IsActive = false;
        }
    }
}
