
import 'optifin_native_player_platform_interface.dart';

class OptifinNativePlayer {
  Future<String?> getPlatformVersion() {
    return OptifinNativePlayerPlatform.instance.getPlatformVersion();
  }
}
