using OptiFin.Core.Api;
using OptiFin.Core.Auth;
using OptiFin.Core.Logging;
using OptiFin.Core.Media;
using OptiFin.Core.Playback;
using OptiFin.Core.Settings;

namespace OptiFin.App.Services;

/// <summary>
/// Services de l'appli (un seul jeu, comme un conteneur d'injection minimal) : identité du client,
/// comptes, réglages, et — une fois connecté — client Jellyfin, contenus, accueil, lecture.
/// </summary>
public static class AppServices
{
    public static AccountStore Accounts { get; } = new();
    public static SettingsStore SettingsStore { get; } = new();
    public static AppSettings Settings { get; private set; } = new();
    public static ClientIdentity Identity { get; private set; } = new("OptiFin", Environment.MachineName, "", Version);
    public static AuthService Auth { get; private set; } = new(Identity);

    public static ActiveSession? Session { get; private set; }
    public static JellyfinClient? Client { get; private set; }
    public static MediaRepository? Media { get; private set; }
    public static HomeRepository? Home { get; private set; }
    public static PlaybackService? Playback { get; private set; }
    public static ImageUrls? Images { get; private set; }

    /// <summary>Jeton révoqué côté serveur pendant l'utilisation : retour à la connexion.</summary>
    public static event Action? SessionLost;
    public static event Action? SessionChanged;

    public static string Version =>
        typeof(AppServices).Assembly.GetName().Version is { } v ? $"{v.Major}.{v.Minor}.{v.Build}" : "1.0.0";

    public static void Initialize()
    {
        Settings = SettingsStore.Load();
        AppLog.Verbose = Settings.DebugMode;
        Identity = new ClientIdentity("OptiFin", Environment.MachineName, Accounts.DeviceId(), Version);
        Auth = new AuthService(Identity);
        if (Accounts.Restore() is { } session) Activate(session);
    }

    public static void SaveSettings() => SettingsStore.Save(Settings);

    public static void SignIn(ActiveSession session)
    {
        Accounts.Remember(session);
        Activate(session);
        SessionChanged?.Invoke();
    }

    public static void SwitchTo(string accountId)
    {
        if (Accounts.Restore(accountId) is { } session)
        {
            Activate(session);
            SessionChanged?.Invoke();
        }
    }

    public static async Task SignOutAsync(bool forget = false)
    {
        if (Session is { } s)
        {
            await Auth.LogoutAsync(s);
            Accounts.SignOut(s.Account.Id, forget);
        }
        Session = null;
        Client = null;
        Media = null;
        Home = null;
        Playback = null;
        Images = null;
        WatchParty.Attach(null);
        SessionChanged?.Invoke();
    }

    private static void Activate(ActiveSession session)
    {
        Session = session;
        var token = session.Token;
        Client = new JellyfinClient(session.Server.BaseUrl, Identity, () => token)
        {
            OnUnauthorized = () =>
            {
                AppLog.Warn("auth", "Jeton refusé par le serveur : reconnexion nécessaire");
                Accounts.SignOut(session.Account.Id, forget: false);
                SessionLost?.Invoke();
            },
        };
        Media = new MediaRepository(Client, session.Account.UserId);
        Home = new HomeRepository(Media, session.Account.Id);
        Playback = new PlaybackService(Client, session.Account.UserId);
        Images = new ImageUrls(session.Server.BaseUrl);
        WatchParty.Attach(Client);
        AppLog.Info("app", $"Session : {session.Account.UserName} sur {session.Server.Name} (Jellyfin {session.Server.Version})");
    }
}
