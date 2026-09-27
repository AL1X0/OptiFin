import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'optifin_native_player_platform_interface.dart';

/// An implementation of [OptifinNativePlayerPlatform] that uses method channels.
class MethodChannelOptifinNativePlayer extends OptifinNativePlayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('optifin_native_player');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
