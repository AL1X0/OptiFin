import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/features/auth/data/server_discovery.dart';

void main() {
  List<int> json(Object o) => utf8.encode(jsonEncode(o));

  test('réponse valide', () {
    final s = ServerDiscovery.parseResponse(
      json({'Address': 'http://192.168.1.20:8096', 'Id': 'abc', 'Name': 'Salon', 'EndpointAddress': null}),
    );
    expect(s, isNotNull);
    expect(s!.id, 'abc');
    expect(s.name, 'Salon');
    expect(s.address, Uri.parse('http://192.168.1.20:8096'));
  });

  test('nom manquant : repli sur l’hôte', () {
    final s = ServerDiscovery.parseResponse(json({'Address': 'http://nas:8096', 'Id': 'x'}));
    expect(s!.name, 'nas');
  });

  test('réponses invalides ignorées', () {
    expect(ServerDiscovery.parseResponse(utf8.encode('pas du json')), isNull);
    expect(ServerDiscovery.parseResponse(json([1, 2])), isNull);
    expect(ServerDiscovery.parseResponse(json({'Address': 'http://h'})), isNull);
    expect(ServerDiscovery.parseResponse(json({'Id': 'x', 'Address': 'ftp://h'})), isNull);
    expect(ServerDiscovery.parseResponse([0xff, 0xfe]), isNull);
  });
}
