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
}
