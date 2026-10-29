import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';

/// Copie locale du serveur Jellyfin de démonstration public (demo/server_snapshot.py) : l'app réelle
/// y fait ses vraies requêtes, rejouées depuis build/demo/server/. Toute requête ou image absente
/// est notée dans misses.txt (à récupérer avec le script, puis relancer la capture).
class ServerSnapshot {
  ServerSnapshot._(this.meta, this._responses);

  static const dir = 'build/demo/server';

  static ServerSnapshot load() {
    final meta = File('$dir/meta.json');
    if (!meta.existsSync()) {
      throw StateError('Copie du serveur de démo absente : python demo/server_snapshot.py');
    }
    final responses = File('$dir/responses.json');
    return ServerSnapshot._(
      jsonDecode(meta.readAsStringSync()) as Map<String, Object?>,
      responses.existsSync() ? jsonDecode(responses.readAsStringSync()) as Map<String, Object?> : {},
    );
  }

  final Map<String, Object?> meta;
  final Map<String, Object?> _responses;
  final _misses = <String>{};

  /// Avancement de lecture ajouté localement (le compte public n'a rien en cours) : id → fraction.
  final progress = <String, double>{};

  String get userId => meta['userId']! as String;
  String get userName => meta['userName']! as String;
  Uri get baseUrl => Uri.parse(meta['server']! as String);
  String get serverName => meta['serverName'] as String? ?? 'Jellyfin';
  String get version => meta['version'] as String? ?? '10.10.0';

  bool get complete => _misses.isEmpty;

  /// Réponse enregistrée (JSON décodé), ou null en notant le manque.
  Object? response(String method, String pathAndQuery) {
    final key = method == 'GET' ? pathAndQuery : '$method $pathAndQuery';
    final hit = _responses[key] as Map<String, Object?>?;
    if (hit == null) {
      _miss('$method $pathAndQuery');
      return null;
    }
    return _withProgress(hit['body']);
  }

  /// Réponse brute d'une requête de l'app (chemin sous l'adresse du serveur, requête triée).
  static String keyOf(Uri base, Uri uri) {
    var path = uri.path;
    if (path.startsWith(base.path)) path = path.substring(base.path.length);
    path = path.replaceFirst(RegExp('^/'), '');
    final q = uri.queryParametersAll.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (q.isEmpty) return path;
    return '$path?${[for (final e in q) for (final v in e.value) '${e.key}=${Uri.encodeQueryComponent(v)}'].join('&')}';
  }

  Object? _withProgress(Object? body) {
    if (progress.isEmpty || body == null) return body;
    Object? patch(Object? v) {
      if (v is Map<String, Object?>) {
        final out = {for (final e in v.entries) e.key: patch(e.value)};
        final fraction = progress[v['Id']];
        final ticks = v['RunTimeTicks'];
        if (fraction != null && ticks is int) {
          out['UserData'] = {
            ...?(v['UserData'] as Map<String, Object?>?),
            'PlaybackPositionTicks': (ticks * fraction).round(),
            'PlayedPercentage': fraction * 100,
            'Played': false,
          };
        }
        return out;
      }
      if (v is List) return [for (final e in v) patch(e)];
      return v;
    }

    return patch(body);
  }

  // ------------------------------------------------------------ Images

  final _images = <String, Uint8List>{};
  final _providers = <String, ImageProvider>{};

  static final _transparent = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  /// `Items/{id}/Images/{Type}[/{index}]` d'une adresse d'image Jellyfin.
  static String? imageKey(String url) {
    final seg = Uri.parse(url).pathSegments;
    final i = seg.indexOf('Images');
    if (i < 2 || i + 1 >= seg.length) return null;
    return [...seg.sublist(i - 2, i + 2), if (seg.length > i + 2) seg[i + 2]].join('/');
  }

  Uint8List? imageBytes(String key) {
    if (_images.containsKey(key)) return _images[key];
    final file = File('$dir/images/${key.replaceAll('/', '_')}.jpg');
    if (!file.existsSync()) {
      _miss('IMG $key');
      return null;
    }
    final bytes = file.readAsBytesSync();
    return _images[key] = bytes.isEmpty ? _transparent : bytes;
  }

  ImageProvider provider(String url) {
    final key = imageKey(url) ?? url;
    return _providers.putIfAbsent(key, () => MemoryImage(imageBytes(key) ?? _transparent));
  }

  /// Image « vidéo » d'un élément lu : une vraie image du film (demo/server_snapshot.py l'extrait
  /// du flux), sinon son fond.
  ImageProvider videoFrame(String itemId) {
    final key = 'Frames/$itemId';
    return _providers.putIfAbsent(key, () {
      final frame = imageBytes(key);
      if (frame != null && frame.length > 100) return MemoryImage(frame);
      return MemoryImage(imageBytes('Items/$itemId/Images/Backdrop/0') ?? imageBytes('Items/$itemId/Images/Primary') ?? _transparent);
    });
  }

  /// Durée d'un élément, d'après n'importe quelle réponse enregistrée qui le décrit.
  Duration runtimeOf(String itemId) {
    int? found;
    void scan(Object? v) {
      if (found != null) return;
      if (v is Map) {
        if (v['Id'] == itemId && v['RunTimeTicks'] is int) {
          found = v['RunTimeTicks'] as int;
          return;
        }
        v.values.forEach(scan);
      } else if (v is List) {
        v.forEach(scan);
      }
    }

    _responses.values.forEach(scan);
    return Duration(microseconds: (found ?? 60 * 60 * 10000000) ~/ 10);
  }

  /// Élément tel que le serveur le décrit (la description la plus complète enregistrée).
  Map<String, Object?>? item(String itemId) {
    Map<String, Object?>? best;
    void scan(Object? v) {
      if (v is Map<String, Object?>) {
        // ServerId : un élément, pas une de ses sources (même identifiant).
        if (v['Id'] == itemId && v.containsKey('ServerId') && (best == null || v.length > best!.length)) best = v;
        v.values.forEach(scan);
      } else if (v is List) {
        v.forEach(scan);
      }
    }

    for (final r in _responses.values) {
      scan((r! as Map)['body']);
    }
    return best == null ? null : _withProgress(best) as Map<String, Object?>;
  }

  /// Toutes les images déjà demandées, pour les décoder avant les captures.
  Iterable<ImageProvider> get all => _providers.values;

  void _miss(String line) {
    if (_misses.add(line)) File('$dir/misses.txt').writeAsStringSync('$line\n', mode: FileMode.append);
  }
}

/// Adaptateur HTTP de l'app : rejoue la copie du serveur.
class SnapshotJellyfinAdapter implements HttpClientAdapter {
  SnapshotJellyfinAdapter(this.snapshot);

  final ServerSnapshot snapshot;

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final key = ServerSnapshot.keyOf(snapshot.baseUrl, o.uri);
    // Rapports de lecture, favoris… : sans effet sur la copie.
    if (o.method == 'POST' && !key.contains('PlaybackInfo')) return ResponseBody.fromString('', 204);
    if (o.method == 'DELETE') return ResponseBody.fromString('', 204);
    final body = snapshot.response(o.method, key);
    if (body == null) return ResponseBody.fromString('{}', 404, headers: _json);
    return ResponseBody.fromString(jsonEncode(body), 200, headers: _json);
  }

  @override
  void close({bool force = false}) {}
}
