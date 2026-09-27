import 'dart:async';

import 'package:jellyfin_api/jellyfin_api.dart';

import '../../../core/network/api_failure.dart';
import '../domain/entities.dart';
import '../domain/server_address.dart';

/// Fabrique un client Jellyfin pour une URL de base et un token éventuel.
typedef JellyfinClientFactory = JellyfinClient Function(Uri baseUrl, {String? token});

/// Ticket Quick Connect : `code` à saisir sur un autre appareil, `secret` à sonder.
class QuickConnectTicket {
  const QuickConnectTicket({required this.code, required this.secret});

  final String code;
  final String secret;
}

/// Connexion : sonde de serveur, login par identifiants, Quick Connect.
class AuthRepository {
  AuthRepository(this._clientFor);

  final JellyfinClientFactory _clientFor;

  static const _jellyfinProductName = 'Jellyfin Server';

  /// Essaie chaque URL candidate et retourne le premier serveur Jellyfin valide.
  ///
  /// Lève [NotJellyfinFailure], [UnsupportedVersionFailure] ou l'erreur réseau
  /// de la dernière tentative si aucune ne répond.
  Future<JellyfinServer> probe(String input) async {
    final candidates = ServerAddress.candidates(input);
    if (candidates.isEmpty) throw const UnreachableFailure();

    ApiFailure? lastFailure;
    for (final url in candidates) {
      try {
        final info = await _clientFor(url).system.getPublicSystemInfo();
        final product = info.productName;
        if (info.id == null || (product != null && product != _jellyfinProductName)) {
          lastFailure = const NotJellyfinFailure();
          continue;
        }
        if (!ServerAddress.isSupportedVersion(info.version)) {
          throw UnsupportedVersionFailure(info.version ?? '?');
        }
        return JellyfinServer(
          id: info.id!,
          name: (info.serverName?.isNotEmpty ?? false) ? info.serverName! : url.host,
          baseUrl: url,
          version: info.version!,
        );
      } on UnsupportedVersionFailure {
        rethrow;
      } catch (e) {
        final failure = ApiFailure.from(e);
        // Une réponse HTTP qui n'est pas du JSON Jellyfin = mauvais service à cette URL.
        lastFailure = failure is UnexpectedFailure ? const NotJellyfinFailure() : failure;
      }
    }
    throw lastFailure ?? const UnreachableFailure();
  }

  /// Utilisateurs visibles sur l'écran de connexion (peut être vide si masqués).
  Future<List<PublicUser>> publicUsers(JellyfinServer server) async {
    try {
      final users = await _clientFor(server.baseUrl).user.getPublicUsers();
      return [
        for (final u in users)
          PublicUser(
            id: u.id,
            name: u.name ?? '',
            avatarTag: u.primaryImageTag,
            hasPassword: u.hasPassword ?? true,
          ),
      ];
    } catch (_) {
      // Non bloquant : l'utilisateur peut toujours saisir son identifiant.
      return const [];
    }
  }

  Future<ActiveSession> login(JellyfinServer server, {required String username, required String password}) async {
    try {
      final result = await _clientFor(server.baseUrl)
          .authentication
          .authenticateUserByName(body: AuthenticateUserByName(username: username, pw: password));
      return _toSession(server, result);
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }

  Future<bool> isQuickConnectEnabled(JellyfinServer server) async {
    try {
      return await _clientFor(server.baseUrl).authentication.getQuickConnectEnabled();
    } catch (_) {
      return false;
    }
  }

  Future<QuickConnectTicket> initiateQuickConnect(JellyfinServer server) async {
    try {
      final r = await _clientFor(server.baseUrl).authentication.initiateQuickConnect();
      if (r.code == null || r.secret == null) throw const UnexpectedFailure('QuickConnect sans code');
      return QuickConnectTicket(code: r.code!, secret: r.secret!);
    } catch (e) {
      final failure = ApiFailure.from(e);
      // Le serveur répond 401 quand Quick Connect est désactivé.
      throw failure is UnauthorizedFailure ? const QuickConnectDisabledFailure() : failure;
    }
  }

  /// Sonde l'état du ticket jusqu'à autorisation, puis échange le secret contre un token.
  ///
  /// S'arrête (StateError) si [timeout] est atteint ; les erreurs réseau
  /// transitoires pendant le sondage sont ignorées.
  Future<ActiveSession> awaitQuickConnect(
    JellyfinServer server,
    QuickConnectTicket ticket, {
    Duration interval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final api = _clientFor(server.baseUrl).authentication;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final state = await api.getQuickConnectState(secret: ticket.secret);
        if (state.authenticated ?? false) {
          final result = await api.authenticateWithQuickConnect(body: QuickConnectDto(secret: ticket.secret));
          return _toSession(server, result);
        }
      } catch (e) {
        final failure = ApiFailure.from(e);
        // 404 = ticket expiré ; 401 = QC désactivé entre-temps : inutile d'insister.
        if (failure is UnexpectedFailure || failure is UnauthorizedFailure) throw failure;
      }
      await Future<void>.delayed(interval);
    }
    throw StateError('Quick Connect expiré');
  }

  /// Révoque le token côté serveur (best effort : l'état local est nettoyé quoi qu'il arrive).
  Future<void> logout(ActiveSession session) async {
    try {
      await _clientFor(session.server.baseUrl, token: session.token).session.reportSessionEnded();
    } catch (_) {}
  }

  ActiveSession _toSession(JellyfinServer server, AuthenticationResult result) {
    final user = result.user;
    final token = result.accessToken;
    if (user == null || token == null || token.isEmpty) {
      throw const UnexpectedFailure('Réponse d’authentification incomplète');
    }
    return ActiveSession(
      server: server,
      account: Account(serverId: server.id, userId: user.id, userName: user.name ?? '', avatarTag: user.primaryImageTag),
      token: token,
    );
  }
}
