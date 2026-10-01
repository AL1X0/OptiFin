using OptiFin.App.Pages;
using OptiFin.Core.Media;

namespace OptiFin.App.Services;

/// <summary>Actions de l'outil de capture (<c>page:Accueil</c>, <c>fiche:id</c>…), pour la documentation et les tests visuels.</summary>
public static class DevActions
{
    public static async Task RunAsync(string action)
    {
        var (verb, arg) = action.Split(':', 2) is [var v, var a] ? (v, a) : (action, "");
        switch (verb)
        {
            case "page":
                Nav.Section(arg switch
                {
                    "Bibliotheques" => typeof(LibrariesPage),
                    "Recherche" => typeof(SearchPage),
                    "Reglages" => typeof(SettingsPage),
                    _ => typeof(HomePage),
                });
                break;
            case "recherche":
                Nav.Section(typeof(SearchPage));
                if (Nav.ContentFrame?.Content is SearchPage search) search.SetQuery(arg);
                break;
            case "serveur":
                // Écran de connexion d'un serveur (serveur de démonstration local uniquement).
                Nav.PushRoot(typeof(LoginPage), new LoginRequest(await AppServices.Auth.ProbeAsync(arg), null));
                break;
            case "demo":
                // Connexion au serveur de démonstration (tools/OptiFin.DemoServer), qui accepte tout compte.
                var server = await AppServices.Auth.ProbeAsync(arg);
                AppServices.SignIn(await AppServices.Auth.LoginAsync(server, "Léa", ""));
                break;
            case "jellyfin":
                // Serveur Jellyfin de test local : fichier JSON {url, users:[{name,password}]} (hors dépôt).
                using (var doc = System.Text.Json.JsonDocument.Parse(await File.ReadAllTextAsync(arg)))
                {
                    var root = doc.RootElement;
                    var user = root.GetProperty("users")[0];
                    var jf = await AppServices.Auth.ProbeAsync(root.GetProperty("url").GetString()!);
                    AppServices.SignIn(await AppServices.Auth.LoginAsync(jf, user.GetProperty("name").GetString()!, user.GetProperty("password").GetString()!));
                }
                break;
            case "saut":
                Player.PlayerLauncher.Current?.DevSeek(TimeSpan.FromSeconds(double.Parse(arg, System.Globalization.CultureInfo.InvariantCulture)));
                break;
            case "rangee":
                if (Nav.ContentFrame?.Content is HomePage home)
                {
                    var rows = FindRows(home).ToList();
                    foreach (var row in rows) row.Page(1);
                    await Task.Delay(800);
                    OptiFin.Core.Logging.AppLog.Info("dev", "Défilement des rangées : " + string.Join(", ", rows.Select(r => r.Offset.ToString("0"))));
                }
                break;
            case "carte":
                // Clic simulé sur la première carte de l'accueil : « play » au centre (lecture), sinon en haut (fiche).
                if (Nav.ContentFrame?.Content is HomePage h && Find<Controls.MediaCard>(h).FirstOrDefault(c => c.Item.Kind.IsPlayableVideo()) is { } card)
                    card.DevClick(arg == "play");
                break;
            case "fermer":
                Player.PlayerLauncher.Current?.DevClose();
                break;
            case "soiree":
                for (var i = 0; i < 50 && WatchParty.Client?.Connected != true; i++) await Task.Delay(100);
                if ((await WatchParty.ListAsync()).FirstOrDefault() is { } g) await WatchParty.JoinAsync(g.Id);
                break;
            case "fiche" when AppServices.Media is { } media:
                Nav.Go(typeof(DetailsPage), await media.ItemAsync(arg));
                break;
            case "bibliotheque" when AppServices.Media is { } media:
                var views = await media.UserViewsAsync();
                if (views.FirstOrDefault(v => v.Name == arg) is { } view) Nav.Go(typeof(LibraryPage), view);
                break;
            case "lecture" when AppServices.Media is { } media:
                Player.PlayerLauncher.Play(await media.ItemAsync(arg));
                break;
        }
    }

    private static IEnumerable<Controls.MediaRow> FindRows(Microsoft.UI.Xaml.DependencyObject root) => Find<Controls.MediaRow>(root);

    private static IEnumerable<T> Find<T>(Microsoft.UI.Xaml.DependencyObject root) where T : class
    {
        for (var i = 0; i < Microsoft.UI.Xaml.Media.VisualTreeHelper.GetChildrenCount(root); i++)
        {
            var child = Microsoft.UI.Xaml.Media.VisualTreeHelper.GetChild(root, i);
            if (child is T match) yield return match;
            else foreach (var r in Find<T>(child)) yield return r;
        }
    }
}
