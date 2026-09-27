// Prépare la spec OpenAPI Jellyfin pour swagger_parser.
//
// 1. swagger_parser émet les valeurs `default` des propriétés enum référencées
//    (`allOf: [$ref]` / `$ref`) comme identifiants nus (`= Unknown`), ce qui ne compile
//    pas. Ces défauts sont purement informatifs côté client : on les retire.
// 2. Les corps de requête binaires optionnels génèrent un `File?` non compilable :
//    on les marque requis.
//
// Usage : dart run tool/prepare_spec.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final spec = jsonDecode(File('openapi/jellyfin-openapi-stable.json').readAsStringSync());
  var defaults = 0;
  var bodies = 0;

  void walk(Object? node, String? key) {
    if (node is Map<String, dynamic>) {
      final isRef = node.containsKey(r'$ref') || node.containsKey('allOf') || node.containsKey('oneOf');
      if (isRef && node.containsKey('default')) {
        node.remove('default');
        defaults++;
      }
      if (key == 'requestBody' && node['required'] != true && jsonEncode(node['content']).contains('"format":"binary"')) {
        node['required'] = true;
        bodies++;
      }
      node.forEach((k, v) => walk(v, k));
    } else if (node is List) {
      for (final v in node) {
        walk(v, null);
      }
    }
  }

  walk(spec, null);
  File('openapi/jellyfin-openapi.prepared.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(spec));
  stdout.writeln('Spec préparée : $defaults défauts enum retirés, $bodies corps binaires requis.');
}
