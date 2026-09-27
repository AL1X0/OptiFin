import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../network/jellyfin_auth.dart';

/// Construit l'identité client : DeviceId stable (généré une fois, stocké
/// dans le trousseau), nom d'appareil lisible, version de l'app.
Future<ClientIdentity> loadClientIdentity({FlutterSecureStorage storage = const FlutterSecureStorage()}) async {
  const key = 'deviceId';
  var deviceId = await storage.read(key: key);
  if (deviceId == null || deviceId.isEmpty) {
    deviceId = const Uuid().v4();
    await storage.write(key: key, value: deviceId);
  }

  final info = DeviceInfoPlugin();
  String deviceName;
  try {
    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      deviceName = ios.name.isNotEmpty ? ios.name : ios.model;
    } else if (Platform.isAndroid) {
      final android = await info.androidInfo;
      deviceName = '${android.manufacturer} ${android.model}'.trim();
    } else {
      deviceName = Platform.localHostname;
    }
  } catch (_) {
    deviceName = 'OptiFin';
  }

  final package = await PackageInfo.fromPlatform();
  return ClientIdentity(clientName: 'OptiFin', deviceName: deviceName, deviceId: deviceId, version: package.version);
}
