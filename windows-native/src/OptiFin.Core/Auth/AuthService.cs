using OptiFin.Core.Api;

namespace OptiFin.Core.Auth;

/// <summary>Connexion : sonde de serveur, identifiants, Quick Connect, déconnexion.</summary>
public sealed class AuthService(ClientIdentity identity)
{
    private const string JellyfinProductName = "Jellyfin Server";

    private JellyfinClient Client(Uri baseUrl, string? token = null) => new(baseUrl, identity, () => token);

    /// <summary>Essaie chaque adresse candidate et renvoie le premier serveur Jellyfin valide.</summary>
    public async Task<JellyfinServer> ProbeAsync(string input, CancellationToken ct = default)
    {
        var candidates = ServerAddress.Candidates(input);
        if (candidates.Count == 0) throw new ApiException(ApiErrorKind.Unreachable);
        ApiException? last = null;
        foreach (var url in candidates)
        {
            try
            {
                var info = await Client(url).GetAsync("System/Info/Public", JellyfinJson.Default.PublicSystemInfo, ct: ct);
                if (info.Id is null || (info.ProductName != null && info.ProductName != JellyfinProductName))
                {
                    last = new ApiException(ApiErrorKind.NotJellyfin);
                    continue;
                }
                if (!ServerAddress.IsSupportedVersion(info.Version))
                    throw new ApiException(ApiErrorKind.UnsupportedVersion, info.Version ?? "?");
                return new JellyfinServer(info.Id, string.IsNullOrEmpty(info.ServerName) ? url.Host : info.ServerName, url,
                    info.Version!);
            }
            catch (ApiException e) when (e.Kind != ApiErrorKind.UnsupportedVersion)
            {
                // Une réponse qui n'est pas du JSON Jellyfin : mauvais service à cette adresse.
                last = e.Kind == ApiErrorKind.Unexpected ? new ApiException(ApiErrorKind.NotJellyfin) : e;
            }
        }
        throw last ?? new ApiException(ApiErrorKind.Unreachable);
    }

    /// <summary>Utilisateurs visibles sur l'écran de connexion (vide s'ils sont masqués).</summary>
    public async Task<IReadOnlyList<PublicUser>> PublicUsersAsync(JellyfinServer server, CancellationToken ct = default)
    {
        try
        {
            var users = await Client(server.BaseUrl).GetAsync("Users/Public", JellyfinJson.Default.ListUserDto, ct: ct);
            return [.. users.Select(u => new PublicUser(u.Id, u.Name ?? "", u.PrimaryImageTag, u.HasPassword ?? true))];
        }
        catch (ApiException)
        {
            return [];
        }
    }

    public async Task<ActiveSession> LoginAsync(JellyfinServer server, string username, string password,
        CancellationToken ct = default)
    {
        var body = JellyfinClient.Json(new AuthenticateUserByName { Username = username, Pw = password },
            JellyfinJson.Default.AuthenticateUserByName);
        var result = await Client(server.BaseUrl).PostAsync("Users/AuthenticateByName", body,
            JellyfinJson.Default.AuthenticationResult, ct: ct);
        return ToSession(server, result);
    }

    public async Task<bool> IsQuickConnectEnabledAsync(JellyfinServer server, CancellationToken ct = default)
    {
        try
        {
            var enabled = await Client(server.BaseUrl).GetAsync("QuickConnect/Enabled", JellyfinJson.Default.JsonElement, ct: ct);
            return enabled.ValueKind == System.Text.Json.JsonValueKind.True;
        }
        catch
        {
            return false;
        }
    }

    public async Task<QuickConnectTicket> InitiateQuickConnectAsync(JellyfinServer server, CancellationToken ct = default)
    {
        try
        {
            var r = await Client(server.BaseUrl).PostAsync("QuickConnect/Initiate", null, JellyfinJson.Default.QuickConnectResult, ct: ct);
            if (r.Code is null || r.Secret is null) throw new ApiException(ApiErrorKind.Unexpected, "Quick Connect sans code");
            return new QuickConnectTicket(r.Code, r.Secret);
        }
        catch (ApiException e) when (e.Kind == ApiErrorKind.Unauthorized)
        {
            // Le serveur répond 401 quand Quick Connect est désactivé.
            throw new ApiException(ApiErrorKind.QuickConnectDisabled);
        }
    }

    /// <summary>Sonde le ticket jusqu'à autorisation (toutes les 3 s, 10 min max), puis échange le secret.</summary>
    public async Task<ActiveSession> AwaitQuickConnectAsync(JellyfinServer server, QuickConnectTicket ticket,
        CancellationToken ct = default)
    {
        var client = Client(server.BaseUrl);
        var deadline = DateTime.UtcNow.AddMinutes(10);
        while (DateTime.UtcNow < deadline)
        {
            ct.ThrowIfCancellationRequested();
            try
            {
                var state = await client.GetAsync("QuickConnect/Connect", JellyfinJson.Default.QuickConnectResult,
                    [new("secret", ticket.Secret)], ct);
                if (state.Authenticated == true)
                {
                    var body = JellyfinClient.Json(new QuickConnectDto { Secret = ticket.Secret }, JellyfinJson.Default.QuickConnectDto);
                    var result = await client.PostAsync("Users/AuthenticateWithQuickConnect", body,
                        JellyfinJson.Default.AuthenticationResult, ct: ct);
                    return ToSession(server, result);
                }
            }
            catch (ApiException e) when (e.Kind is ApiErrorKind.Unexpected or ApiErrorKind.Unauthorized)
            {
                throw; // ticket expiré (404) ou Quick Connect désactivé entre-temps
            }
            catch (ApiException)
            {
                // Erreur réseau passagère : on réessaie.
            }
            await Task.Delay(TimeSpan.FromSeconds(3), ct);
        }
        throw new TimeoutException("Quick Connect expiré");
    }

    /// <summary>Révoque le jeton côté serveur (au mieux ; l'état local est nettoyé quoi qu'il arrive).</summary>
    public async Task LogoutAsync(ActiveSession session)
    {
        try
        {
            await Client(session.Server.BaseUrl, session.Token).PostAsync("Sessions/Logout");
        }
        catch
        {
        }
    }

    private static ActiveSession ToSession(JellyfinServer server, AuthenticationResult result)
    {
        if (result.User is not { } user || string.IsNullOrEmpty(result.AccessToken))
            throw new ApiException(ApiErrorKind.Unexpected, "Réponse d’authentification incomplète");
        return new ActiveSession(server, new Account(server.Id, user.Id, user.Name ?? "", user.PrimaryImageTag), result.AccessToken);
    }
}
