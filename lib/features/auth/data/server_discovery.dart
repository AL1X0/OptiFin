import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/entities.dart';
import '../domain/server_address.dart';

/// Découverte des serveurs Jellyfin du réseau local.
///
/// Protocole Jellyfin : datagramme UDP « who is JellyfinServer? » en broadcast sur
/// le port 7359 ; chaque serveur répond en JSON `{Address, Id, Name, EndpointAddress}`.
///
/// iOS 14+ : le broadcast exige l'entitlement `com.apple.developer.networking.multicast`
/// (validation Apple). Sans lui, `send` échoue silencieusement : on retourne une liste
/// vide et l'utilisateur saisit l'adresse manuellement.
class ServerDiscovery {
  static const port = 7359;
  static const message = 'who is JellyfinServer?';

  /// Émet la liste cumulée (dédupliquée) des serveurs trouvés pendant [timeout].
  Stream<List<DiscoveredServer>> discover({Duration timeout = const Duration(seconds: 3)}) async* {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.send(utf8.encode(message), InternetAddress('255.255.255.255'), port);
    } on SocketException {
      socket?.close();
      yield const [];
      return;
    }

    final found = <String, DiscoveredServer>{};
    final controller = StreamController<List<DiscoveredServer>>();
    final sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket!.receive();
      if (datagram == null) return;
      final server = parseResponse(datagram.data);
      if (server != null && found[server.id] == null) {
        found[server.id] = server;
        controller.add(found.values.toList(growable: false));
      }
    });
    final timer = Timer(timeout, controller.close);

    try {
      yield* controller.stream;
    } finally {
      timer.cancel();
      await sub.cancel();
      socket.close();
    }
  }

  /// Parse une réponse de découverte. Retourne null si invalide.
  static DiscoveredServer? parseResponse(List<int> bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map<String, dynamic>) return null;
      final id = json['Id'];
      final address = json['Address'];
      if (id is! String || id.isEmpty || address is! String) return null;
      final candidates = ServerAddress.candidates(address);
      if (candidates.isEmpty) return null;
      final name = json['Name'];
      return DiscoveredServer(
        id: id,
        name: name is String && name.isNotEmpty ? name : candidates.first.host,
        address: candidates.first,
      );
    } on FormatException {
      return null;
    }
  }
}
