import 'package:flutter_test/flutter_test.dart';
import 'package:optifin_native_player/optifin_native_player.dart';
import 'package:optifin_native_player/optifin_native_player_platform_interface.dart';
import 'package:optifin_native_player/optifin_native_player_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockOptifinNativePlayerPlatform
    with MockPlatformInterfaceMixin
    implements OptifinNativePlayerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final OptifinNativePlayerPlatform initialPlatform = OptifinNativePlayerPlatform.instance;

  test('$MethodChannelOptifinNativePlayer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelOptifinNativePlayer>());
  });

  test('getPlatformVersion', () async {
    OptifinNativePlayer optifinNativePlayerPlugin = OptifinNativePlayer();
    MockOptifinNativePlayerPlatform fakePlatform = MockOptifinNativePlayerPlatform();
    OptifinNativePlayerPlatform.instance = fakePlatform;

    expect(await optifinNativePlayerPlugin.getPlatformVersion(), '42');
  });
}
