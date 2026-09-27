/// Serveur Jellyfin validé (a répondu à /System/Info/Public).
class JellyfinServer {
  const JellyfinServer({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.version,
  });

  final String id;
  final String name;
  final Uri baseUrl;
  final String version;

  @override
  bool operator ==(Object other) =>
      other is JellyfinServer && other.id == id && other.baseUrl == baseUrl && other.name == name && other.version == version;

  @override
  int get hashCode => Object.hash(id, baseUrl, name, version);
}

/// Compte connecté sur un serveur.
class Account {
  const Account({
    required this.serverId,
    required this.userId,
    required this.userName,
    this.avatarTag,
  });

  final String serverId;
  final String userId;
  final String userName;
  final String? avatarTag;

  String get id => accountIdOf(serverId, userId);

  static String accountIdOf(String serverId, String userId) => '$serverId:$userId';

  @override
  bool operator ==(Object other) =>
      other is Account && other.id == id && other.userName == userName && other.avatarTag == avatarTag;

  @override
  int get hashCode => Object.hash(id, userName, avatarTag);
}

/// Utilisateur public listé par le serveur sur l'écran de connexion.
class PublicUser {
  const PublicUser({required this.id, required this.name, this.avatarTag, required this.hasPassword});

  final String id;
  final String name;
  final String? avatarTag;
  final bool hasPassword;
}

/// Session active : compte + serveur + token (en mémoire seulement).
class ActiveSession {
  const ActiveSession({required this.server, required this.account, required this.token});

  final JellyfinServer server;
  final Account account;
  final String token;
}

/// Serveur annoncé sur le réseau local (découverte UDP).
class DiscoveredServer {
  const DiscoveredServer({required this.id, required this.name, required this.address});

  final String id;
  final String name;
  final Uri address;

  @override
  bool operator ==(Object other) => other is DiscoveredServer && other.id == id && other.address == address;

  @override
  int get hashCode => Object.hash(id, address);
}
