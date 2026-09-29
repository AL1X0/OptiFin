/// Règles pures autour des adresses et versions de serveur (sans I/O, testées).
abstract final class ServerAddress {
  static const defaultHttpPort = 8096;

  /// Transforme une saisie utilisateur en URL candidates, dans l'ordre d'essai.
  ///
  /// - `https://x` / `http://x` : utilisée telle quelle.
  /// - `x` sans schéma : https d'abord (reverse proxy), puis http, puis http:8096
  ///   si aucun port n'est précisé (installation par défaut).
  /// Retourne une liste vide si la saisie est inexploitable.
  static List<Uri> candidates(String input) {
    var raw = input.trim();
    if (raw.isEmpty) return const [];
    // Détecter le schéma AVANT de retirer les « / » finaux (« https:// » ≠ hôte « https: »).
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(raw);
    raw = raw.replaceAll(RegExp(r'/+$'), '');

    if (hasScheme) {
      final uri = Uri.tryParse(raw);
      if (uri == null || uri.host.isEmpty || !(uri.scheme == 'http' || uri.scheme == 'https')) return const [];
      return [normalize(uri)];
    }

    final https = Uri.tryParse('https://$raw');
    if (https == null || https.host.isEmpty) return const [];
    final http = Uri.tryParse('http://$raw')!;
    final result = <Uri>[normalize(https), normalize(http)];
    if (!http.hasPort) {
      result.add(normalize(http.replace(port: defaultHttpPort)));
    }
    return result;
  }

  /// Supprime query/fragment et le `/` final ; garde un éventuel sous-chemin
  /// (serveur derrière `https://domaine/jellyfin`).
  static Uri normalize(Uri uri) {
    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    return Uri(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      port: uri.hasPort ? uri.port : null,
      path: path,
    );
  }

  static const minimumVersion = (10, 9, 0);

  /// Parse « 10.10.3 » ou « 10.11.0-rc1 » → (10, 10, 3). Null si illisible.
  static (int, int, int)? parseVersion(String? version) {
    if (version == null) return null;
    final m = RegExp(r'^(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(version.trim());
    if (m == null) return null;
    return (int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3) ?? '0'));
  }

  static bool isSupportedVersion(String? version) {
    final v = parseVersion(version);
    if (v == null) return false;
    return compareVersions(v, minimumVersion) >= 0;
  }

  static int compareVersions((int, int, int) a, (int, int, int) b) {
    if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
    if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
    return a.$3.compareTo(b.$3);
  }
}
