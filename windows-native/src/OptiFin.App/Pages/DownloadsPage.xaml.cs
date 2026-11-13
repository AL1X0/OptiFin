using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.UI.Xaml.Navigation;
using OptiFin.App.Controls;
using OptiFin.App.Player;
using OptiFin.App.Services;
using OptiFin.Core.Downloads;
using OptiFin.Core.Localization;

namespace OptiFin.App.Pages;

/// <summary>Films et épisodes téléchargés : lecture sans connexion, progression, pause, suppression.</summary>
public sealed partial class DownloadsPage : Page
{
    private readonly Dictionary<string, (ProgressBar Bar, TextBlock Detail)> _live = [];
    private readonly Dictionary<string, (DispatcherQueueTimer Timer, Border Banner)> _pendingDeletes = [];
    private string _shown = "";

    public DownloadsPage()
    {
        InitializeComponent();
        Ui.Translate(this);
        Nav.TrackScroll(Scroll);
        Loaded += (_, _) =>
        {
            AppServices.Downloads.Changed += OnChanged;
            Refresh();
        };
        Unloaded += (_, _) =>
        {
            AppServices.Downloads.Changed -= OnChanged;
            FlushPendingDeletes();
        };
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e) => FlushPendingDeletes();

    private void OnChanged() => DispatcherQueue.TryEnqueue(Refresh);

    /// <summary>Lignes refaites seulement si la liste ou un état change : sinon un clic pouvait tomber dans le vide.</summary>
    private void Refresh()
    {
        var records = AppServices.Downloads.Records().Where(r => !_pendingDeletes.ContainsKey(r.ItemId)).ToList();
        var signature = string.Join(";", records.Select(r => $"{r.ItemId}:{r.Status}"));
        if (signature != _shown)
        {
            _shown = signature;
            _live.Clear();
            Rows.Children.Clear();
            if (records.Count == 0)
                Rows.Children.Add(new TextBlock { Text = L.T("Aucun téléchargement. Ouvrez la fiche d’un film ou d’un épisode pour le garder sur ce PC et le regarder sans connexion."), Style = Ui.StyleOf("OFBody"), TextWrapping = TextWrapping.Wrap });
            foreach (var r in records) Rows.Children.Add(Row(r));
        }
        foreach (var r in records)
        {
            if (!_live.TryGetValue(r.ItemId, out var live)) continue;
            live.Bar.Value = r.TotalBytes > 0 ? 100.0 * r.DoneBytes / r.TotalBytes : 0;
            live.Detail.Text = Detail(r);
        }
    }

    private static string Size(long bytes) => bytes >= 1L << 30
        ? L.F("{0:0.0} Go", bytes / (double)(1L << 30))
        : L.F("{0:0} Mo", bytes / (double)(1L << 20));

    private static string Detail(DownloadRecord r) => r.Status switch
    {
        DownloadStatus.Complete => Size(r.DoneBytes),
        DownloadStatus.Failed => r.Error ?? L.T("Échec du téléchargement"),
        DownloadStatus.Paused => L.F("En pause · {0} / {1}", Size(r.DoneBytes), Size(r.TotalBytes)),
        DownloadStatus.Queued => L.T("En attente"),
        _ => L.F("{0} / {1}", Size(r.DoneBytes), Size(r.TotalBytes)),
    };

    private Grid Row(DownloadRecord r)
    {
        var row = new Grid { ColumnSpacing = 16, Padding = new Thickness(12), CornerRadius = new CornerRadius(12), Background = Ui.Res("OFSurfaceBrush") };
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var poster = new Border { Width = 64, Height = 96, CornerRadius = new CornerRadius(6), Background = Ui.Res("OFSurfaceRaisedBrush") };
        var posterPath = AppServices.Downloads.PosterPathOf(r.ItemId);
        if (File.Exists(posterPath)) poster.Child = new Image { Source = new BitmapImage(new Uri(posterPath)), Stretch = Microsoft.UI.Xaml.Media.Stretch.UniformToFill };
        row.Children.Add(poster);

        var text = new StackPanel { Spacing = 4, VerticalAlignment = VerticalAlignment.Center };
        text.Children.Add(new TextBlock { Text = r.Name, FontSize = 16, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, TextTrimming = TextTrimming.CharacterEllipsis });
        if (r.Subtitle is { } subtitle) text.Children.Add(new TextBlock { Text = subtitle, Style = Ui.StyleOf("OFCaption"), TextTrimming = TextTrimming.CharacterEllipsis });
        var detail = new TextBlock { Text = Detail(r), Style = Ui.StyleOf("OFCaption"), TextWrapping = TextWrapping.Wrap };
        text.Children.Add(detail);
        var bar = new ProgressBar { Maximum = 100, Visibility = r.Status == DownloadStatus.Complete ? Visibility.Collapsed : Visibility.Visible, Margin = new Thickness(0, 4, 0, 0) };
        text.Children.Add(bar);
        _live[r.ItemId] = (bar, detail);
        Grid.SetColumn(text, 1);
        row.Children.Add(text);

        var actions = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, VerticalAlignment = VerticalAlignment.Center };
        void Action(string glyph, string tip, Action click)
        {
            var button = Ui.Round(glyph, tip);
            button.Click += (_, _) => click();
            actions.Children.Add(button);
        }
        switch (r.Status)
        {
            case DownloadStatus.Complete:
                Action("", L.T("Lecture"), () => PlayerLauncher.Play(DownloadManager.ItemOf(r)));
                break;
            case DownloadStatus.Running or DownloadStatus.Queued:
                Action("", L.T("Mettre en pause"), () => AppServices.Downloads.Pause(r.ItemId));
                break;
            case DownloadStatus.Paused:
                Action("", L.T("Reprendre"), () => AppServices.Downloads.Resume(r.ItemId));
                break;
            default:
                Action("", L.T("Réessayer"), () => AppServices.Downloads.Resume(r.ItemId));
                break;
        }
        Action("", L.T("Supprimer"), () => QueueDelete(r));
        Grid.SetColumn(actions, 2);
        row.Children.Add(actions);
        return row;
    }

    /// <summary>Masque le téléchargement aussitôt et laisse 5 s pour annuler avant la suppression réelle.</summary>
    private void QueueDelete(DownloadRecord record)
    {
        if (_pendingDeletes.ContainsKey(record.ItemId)) return;
        var undo = new Button
        {
            Content = L.T("Annuler"),
            Style = Ui.StyleOf("OFSecondaryButton"),
            Height = 36,
            CornerRadius = new CornerRadius(18),
            Padding = new Thickness(14, 0, 14, 0),
        };
        var content = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 12,
            Children =
            {
                new TextBlock { Text = L.T("Supprimé"), FontSize = 14, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center },
                new TextBlock { Text = record.Name, Style = Ui.StyleOf("OFCaption"), VerticalAlignment = VerticalAlignment.Center, MaxWidth = 240 },
                undo,
            },
        };
        var banner = new Border
        {
            Background = new SolidColorBrush(Windows.UI.Color.FromArgb(0xF2, 0x1C, 0x1C, 0x20)),
            BorderBrush = new SolidColorBrush(Windows.UI.Color.FromArgb(0x33, 0xFF, 0xFF, 0xFF)),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(22),
            Padding = new Thickness(18, 8, 10, 8),
            Child = content,
        };
        var timer = DispatcherQueue.CreateTimer();
        timer.Interval = TimeSpan.FromSeconds(5);
        timer.IsRepeating = false;
        timer.Tick += (_, _) => CommitDelete(record.ItemId);
        undo.Click += (_, _) => CancelDelete(record.ItemId);
        _pendingDeletes[record.ItemId] = (timer, banner);
        UndoBanners.Children.Add(banner);
        timer.Start();
        Refresh();
    }

    private void CancelDelete(string itemId)
    {
        if (!_pendingDeletes.Remove(itemId, out var pending)) return;
        pending.Timer.Stop();
        UndoBanners.Children.Remove(pending.Banner);
        Refresh();
    }

    private void CommitDelete(string itemId)
    {
        if (!_pendingDeletes.Remove(itemId, out var pending)) return;
        pending.Timer.Stop();
        UndoBanners.Children.Remove(pending.Banner);
        _ = AppServices.Downloads.DeleteAsync(itemId);
    }

    private void FlushPendingDeletes()
    {
        foreach (var itemId in _pendingDeletes.Keys.ToList()) CommitDelete(itemId);
    }
}
