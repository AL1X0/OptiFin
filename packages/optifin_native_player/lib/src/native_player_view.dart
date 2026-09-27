import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const _viewType = 'optifin_native_player/view';

/// Surface vidéo native d'un lecteur : `AVPlayerLayer` (iOS) ou `SurfaceView`
/// Media3 (Android, composition hybride : requise pour le HDR et le PiP).
///
/// Les gestes restent à Flutter (contrôles du lecteur dessinés au-dessus).
class NativePlayerView extends StatelessWidget {
  const NativePlayerView({super.key, required this.playerId});

  final int playerId;

  @override
  Widget build(BuildContext context) {
    final params = {'playerId': playerId};
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: _viewType,
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        );
      case TargetPlatform.android:
        return PlatformViewLink(
          viewType: _viewType,
          surfaceFactory: (context, controller) => AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.transparent,
          ),
          onCreatePlatformView: (p) =>
              PlatformViewsService.initExpensiveAndroidView(
                  id: p.id,
                  viewType: _viewType,
                  layoutDirection: TextDirection.ltr,
                  creationParams: params,
                  creationParamsCodec: const StandardMessageCodec(),
                )
                ..addOnPlatformViewCreatedListener(p.onPlatformViewCreated)
                ..create(),
        );
      default:
        return const ColoredBox(color: Color(0xFF000000));
    }
  }
}
