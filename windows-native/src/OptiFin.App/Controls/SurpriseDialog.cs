using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Imaging;
using OptiFin.App.Pages;
using OptiFin.App.Services;
using OptiFin.Core.Api;
using OptiFin.Core.Localization;
using OptiFin.Core.Media;

namespace OptiFin.App.Controls;

/// <summary>« Surprends-moi » : un titre tiré au sort tout de suite, à refaire ou à filtrer par genre et durée.</summary>
public static class SurpriseDialog
{
    /// <summary>Outil de capture : contenu de la fenêtre ouverte.</summary>
    internal static FrameworkElement? DevBody { get; private set; }

    public static async Task ShowAsync(XamlRoot root)
    {
        if (AppServices.Media is not { } media) return;
        (string Label, int? Minutes)[] durations = [(L.T("Peu importe la durée"), null), (L.T("Moins de 1 h 30"), 90), (L.T("Moins de 2 h"), 120)];
        var genreBox = new ComboBox { MinWidth = 200 };
        genreBox.Items.Add(L.T("Tous les genres"));
        genreBox.SelectedIndex = 0;
        var durationBox = new ComboBox { MinWidth = 200 };
        foreach (var d in durations) durationBox.Items.Add(d.Label);
        durationBox.SelectedIndex = 0;
        var filters = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 12 };
        filters.Children.Add(genreBox);
        filters.Children.Add(durationBox);

        var poster = new Image { Width = 130, Height = 195, Stretch = Microsoft.UI.Xaml.Media.Stretch.UniformToFill };
        var title = new TextBlock { Style = Ui.StyleOf("OFTitle2"), TextWrapping = TextWrapping.Wrap };
        var meta = new TextBlock { Style = Ui.StyleOf("OFCaption"), TextWrapping = TextWrapping.Wrap };
        var overview = new TextBlock { Style = Ui.StyleOf("OFBody"), TextWrapping = TextWrapping.Wrap, MaxLines = 6, TextTrimming = TextTrimming.CharacterEllipsis };
        var texts = new StackPanel { Spacing = 6 };
        texts.Children.Add(title);
        texts.Children.Add(meta);
        texts.Children.Add(overview);
        var result = new Grid { ColumnSpacing = 16, MinHeight = 195 };
        result.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        result.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        result.Children.Add(new Border { CornerRadius = new CornerRadius(8), Background = Ui.Res("OFSurfaceRaisedBrush"), Child = poster, VerticalAlignment = VerticalAlignment.Top });
        Grid.SetColumn(texts, 1);
        result.Children.Add(texts);

        var body = new StackPanel { Spacing = 16, Width = 520 };
        body.Children.Add(filters);
        body.Children.Add(result);
        DevBody = body;
        var dialog = new ContentDialog
        {
            XamlRoot = root,
            Title = L.T("Surprends-moi"),
            Content = body,
            PrimaryButtonText = L.T("Voir la fiche"),
            SecondaryButtonText = L.T("Encore"),
            CloseButtonText = L.T("Fermer"),
            DefaultButton = ContentDialogButton.Primary,
            RequestedTheme = ElementTheme.Dark,
            IsPrimaryButtonEnabled = false,
        };

        IReadOnlyList<NamedRef> genres = [];
        MediaItem? current = null;
        var draw = 0;
        async Task DrawAsync()
        {
            var ticket = ++draw;
            dialog.IsSecondaryButtonEnabled = false;
            try
            {
                var genre = genreBox.SelectedIndex > 0 ? genres[genreBox.SelectedIndex - 1].Id : null;
                var pick = await media.SurpriseAsync(genre, durations[Math.Max(0, durationBox.SelectedIndex)].Minutes, current?.Id);
                if (ticket != draw) return;
                current = pick;
                dialog.IsPrimaryButtonEnabled = pick != null;
                title.Text = pick?.Name ?? L.T("Aucun titre ne correspond.");
                meta.Text = pick is null ? "" : string.Join(" · ", MediaFormat.MetadataLine(pick));
                overview.Text = pick?.Overview ?? "";
                poster.Source = pick?.Poster is { } image && AppServices.Images is { } urls
                    ? new BitmapImage(urls.Image(image, 130, 2))
                    : null;
            }
            catch (ApiException e)
            {
                if (ticket != draw) return;
                current = null;
                dialog.IsPrimaryButtonEnabled = false;
                title.Text = e.UserMessage;
                meta.Text = overview.Text = "";
                poster.Source = null;
            }
            if (ticket == draw) dialog.IsSecondaryButtonEnabled = true;
        }

        dialog.SecondaryButtonClick += (sender, args) =>
        {
            args.Cancel = true;
            _ = DrawAsync();
        };
        genreBox.SelectionChanged += (_, _) => _ = DrawAsync();
        durationBox.SelectionChanged += (_, _) => _ = DrawAsync();
        _ = DrawAsync();
        _ = LoadGenresAsync();
        async Task LoadGenresAsync()
        {
            try
            {
                genres = (await media.FilterOptionsAsync(new LibraryQuery { Kinds = [MediaKind.Movie, MediaKind.Series] })).Genres;
                foreach (var g in genres) genreBox.Items.Add(g.Name);
            }
            catch (ApiException e)
            {
                OptiFin.Core.Logging.AppLog.Debug("surprise", $"Genres indisponibles : {e.UserMessage}");
            }
        }

        if (await dialog.ShowAsync() == ContentDialogResult.Primary && current != null) HomePage.Open(current);
    }
}
