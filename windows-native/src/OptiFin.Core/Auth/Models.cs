namespace OptiFin.Core.Auth;

/// <summary>Serveur Jellyfin validé (a répondu à /System/Info/Public).</summary>
public sealed record JellyfinServer(string Id, string Name, Uri BaseUrl, string Version);

/// <summary>Compte connecté sur un serveur.</summary>
public sealed record Account(string ServerId, string UserId, string UserName, string? AvatarTag = null)
{
    public string Id => $"{ServerId}:{UserId}";
}

/// <summary>Utilisateur public listé sur l'écran de connexion.</summary>
public sealed record PublicUser(string Id, string Name, string? AvatarTag, bool HasPassword);

/// <summary>Session active : compte, serveur et jeton (en mémoire ; chiffré sur disque).</summary>
public sealed record ActiveSession(JellyfinServer Server, Account Account, string Token);

/// <summary>Serveur annoncé sur le réseau local.</summary>
public sealed record DiscoveredServer(string Id, string Name, Uri Address);

/// <summary>Ticket Quick Connect : code à saisir sur un autre appareil, secret à sonder.</summary>
public sealed record QuickConnectTicket(string Code, string Secret);
