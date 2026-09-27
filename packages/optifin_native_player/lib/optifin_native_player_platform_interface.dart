import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'optifin_native_player_method_channel.dart';

abstract class OptifinNativePlayerPlatform extends PlatformInterface {
  /// Constructs a OptifinNativePlayerPlatform.
  OptifinNativePlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static OptifinNativePlayerPlatform _instance = MethodChannelOptifinNativePlayer();

  /// The default instance of [OptifinNativePlayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelOptifinNativePlayer].
  static OptifinNativePlayerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OptifinNativePlayerPlatform] when
  /// they register themselves.
  static set instance(OptifinNativePlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
