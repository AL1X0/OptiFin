using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using OptiFin.App.Controls;
using OptiFin.App.Services;
using OptiFin.Core.Api;
using OptiFin.Core.Media;

namespace OptiFin.App.Pages;

/// <summary>Recherche instantanée (300 ms après la dernière frappe), résultats groupés par type.</summary>
public sealed partial class SearchPage : Page
{
    private readonly DispatcherQueueTimer _debounce;
    private CancellationTokenSource? _cts;

    public SearchPage()
    {
        InitializeComponent();
        _debounce = DispatcherQueue.GetForCurrentThread().CreateTimer();
        _debounce.Interval = TimeSpan.FromMilliseconds(300);
        _debounce.IsRepeating = false;
        _debounce.Tick += (_, _) => _ = SearchAsync(Query.Text.Trim());
        Query.TextChanged += (_, _) =>
        {
            _debounce.Stop();
            _debounce.Start();
        };
    }

    protected override void OnNavigatedTo(NavigationEventArgs e) => Query.Focus(FocusState.Programmatic);

    public void SetQuery(string text)
    {
        Query.Text = text;
        _debounce.Stop();
        _ = SearchAsync(text.Trim());
    }

    private async Task SearchAsync(string term)
    {
        _cts?.Cancel();
        if (term.Length < 2 || AppServices.Media is not { } media)
        {
            Results.Children.Clear();
            HintText.Text = "Recherchez dans toutes vos bibliothèques.";
            Hint.Visibility = Visibility.Visible;
            return;
        }
        _cts = new CancellationTokenSource();
        var ct = _cts.Token;
        Spinner.IsActive = true;
        try
        {
            var r = await media.SearchAsync(term, ct);
            if (ct.IsCancellationRequested) return;
            Results.Children.Clear();
            Hint.Visibility = r.IsEmpty ? Visibility.Visible : Visibility.Collapsed;
            HintText.Text = $"Aucun résultat pour « {term} ».";
            Add("Films", r.Movies, CardStyle.Poster);
            Add("Séries", r.Series, CardStyle.Poster);
            Add("Épisodes", r.Episodes, CardStyle.Landscape);
            Add("Personnes", r.People, CardStyle.Poster);
            Add("Autres", r.Others, CardStyle.Poster);
        }
        catch (OperationCanceledException)
        {
        }
        catch (ApiException e)
        {
            Results.Children.Clear();
            HintText.Text = e.UserMessage;
            Hint.Visibility = Visibility.Visible;
        }
        finally
        {
            Spinner.IsActive = false;
        }
    }

    private void Add(string title, IReadOnlyList<MediaItem> items, CardStyle style)
    {
        if (items.Count == 0) return;
        var row = new MediaRow(title, items, style, HomePage.Gutter);
        row.ItemActivated += HomePage.Open;
        Results.Children.Add(row);
    }
}
