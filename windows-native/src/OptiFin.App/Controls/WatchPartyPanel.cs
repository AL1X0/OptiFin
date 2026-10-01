using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using OptiFin.App.Services;
using OptiFin.Core.SyncPlay;

namespace OptiFin.App.Controls;

/// <summary>
/// Panneau « Soirée » de la barre du haut : créer une soirée ou en rejoindre une ; une fois dedans,
/// participants, état et sortie. Tout titre lancé démarre alors chez tout le monde.
/// </summary>
public sealed partial class WatchPartyPanel : StackPanel
{
    private readonly StackPanel _body = new() { Spacing = 10 };

    public WatchPartyPanel()
    {
        Width = 360;
        Spacing = 12;
        Children.Add(new TextBlock { Text = "Soirée", Style = Ui.StyleOf("OFTitle2") });
        Children.Add(_body);
        Loaded += (_, _) =>
        {
            WatchParty.Changed += Render;
            Render();
        };
        Unloaded += (_, _) => WatchParty.Changed -= Render;
    }

    private void Render()
    {
        _body.Children.Clear();
        if (WatchParty.Client is not { } client)
        {
            _body.Children.Add(Ui.Text("Connectez-vous à un serveur pour regarder ensemble.", "OFCaption"));
            return;
        }
        if (WatchParty.Group is { } group) RenderGroup(group, client.Connected);
        else RenderLobby(client.Connected);
    }

    private void RenderGroup(GroupInfo group, bool connected)
    {
        _body.Children.Add(new TextBlock
        {
            Text = group.Name, FontSize = 18, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, TextWrapping = TextWrapping.Wrap,
        });
        _body.Children.Add(Ui.Text(group.State switch
        {
            GroupState.Playing => "Lecture en cours",
            GroupState.Paused => "En pause",
            GroupState.Waiting => "En attente des participants…",
            _ => "Lancez un film ou un épisode : il démarre chez tout le monde, au même moment.",
        }, "OFCaption"));
        if (!connected) _body.Children.Add(Ui.Text("Connexion au serveur interrompue, reconnexion…", "OFCaption", Ui.Res("OFDangerBrush")));

        _body.Children.Add(Ui.Section($"Participants ({group.Participants.Count})"));
        foreach (var name in group.Participants)
        {
            var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10 };
            row.Children.Add(Ui.Avatar(name, null, 30));
            row.Children.Add(new TextBlock { Text = name, VerticalAlignment = VerticalAlignment.Center, FontSize = 14 });
            _body.Children.Add(row);
        }
        var leave = Ui.Secondary("Quitter la soirée", "");
        leave.HorizontalAlignment = HorizontalAlignment.Stretch;
        leave.Margin = new Thickness(0, 6, 0, 0);
        leave.Click += async (_, _) =>
        {
            leave.IsEnabled = false;
            await WatchParty.LeaveAsync();
        };
        _body.Children.Add(leave);
    }

    private void RenderLobby(bool connected)
    {
        _body.Children.Add(Ui.Text("Regardez un film à plusieurs, chacun chez soi : lecture, pause et avance sont synchronisées.", "OFCaption"));
        var name = new TextBox
        {
            Header = "Nom de la soirée",
            Text = $"Soirée de {AppServices.Session?.Account.UserName}",
            CornerRadius = new CornerRadius(10),
        };
        var create = Ui.Primary("Créer une soirée", "");
        create.HorizontalAlignment = HorizontalAlignment.Stretch;
        create.IsEnabled = connected;
        create.Click += async (_, _) =>
        {
            create.IsEnabled = false;
            await WatchParty.CreateAsync(string.IsNullOrWhiteSpace(name.Text) ? "Soirée" : name.Text.Trim());
            create.IsEnabled = true;
        };
        _body.Children.Add(name);
        _body.Children.Add(create);
        if (!connected) _body.Children.Add(Ui.Text("Connexion au serveur en cours…", "OFCaption"));

        _body.Children.Add(Ui.Section("Soirées en cours"));
        var list = new StackPanel { Spacing = 8 };
        list.Children.Add(new ProgressRing { IsActive = true, Width = 20, Height = 20, HorizontalAlignment = HorizontalAlignment.Left });
        _body.Children.Add(list);
        _ = LoadGroupsAsync(list);
    }

    private static async Task LoadGroupsAsync(StackPanel list)
    {
        IReadOnlyList<GroupInfo> groups;
        try
        {
            groups = await WatchParty.ListAsync();
        }
        catch (Exception)
        {
            groups = [];
        }
        list.Children.Clear();
        if (groups.Count == 0)
        {
            list.Children.Add(Ui.Text("Aucune soirée pour le moment.", "OFCaption"));
            return;
        }
        foreach (var g in groups)
        {
            var row = new Grid
            {
                ColumnSpacing = 10, Padding = new Thickness(12, 10, 10, 10), CornerRadius = new CornerRadius(12),
                Background = Ui.Res("OFSurfaceRaisedBrush"),
            };
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            var texts = new StackPanel { Spacing = 2, VerticalAlignment = VerticalAlignment.Center };
            texts.Children.Add(new TextBlock { Text = g.Name, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, TextTrimming = TextTrimming.CharacterEllipsis });
            texts.Children.Add(Ui.Text(string.Join(", ", g.Participants), "OFCaption"));
            row.Children.Add(texts);
            var join = Ui.Primary("Rejoindre");
            join.Click += async (_, _) =>
            {
                join.IsEnabled = false;
                await WatchParty.JoinAsync(g.Id);
            };
            Grid.SetColumn(join, 1);
            row.Children.Add(join);
            list.Children.Add(row);
        }
    }
}
