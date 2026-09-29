import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const _viewType = 'optifin_native_player/view';

/// Surface vidéo native d'un lecteur : `AVPlayerLayer` (iOS) ou Media3 (Android).
///
/// Android, deux modes :
/// - **SDR** (cas courant) : `TextureView` en composition par couche de texture, le mode
///   le plus léger (Flutter compose l'image comme une texture, sans synchroniser ses
///   threads avec ceux d'Android à chaque image) ;
/// - **HDR** ([hdr]) : `SurfaceView` en composition hybride, seule capable d'afficher le
///   HDR, mais nettement plus coûteuse (processeur, GPU, chauffe).
///
/// Les gestes restent à Flutter (contrôles du lecteur dessinés au-dessus).
class NativePlayerView extends StatelessWidget {
  const NativePlayerView({super.key, required this.playerId, this.hdr = false});

  final int playerId;
  final bool hdr;

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: _viewType,
          creationParams: {'playerId': playerId},
          creationParamsCodec: const StandardMessageCodec(),
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        );
      case TargetPlatform.android when !hdr:
        return AndroidView(
          viewType: _viewType,
          creationParams: {'playerId': playerId, 'texture': true},
          creationParamsCodec: const StandardMessageCodec(),
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        );
      case TargetPlatform.android:
        final params = {'playerId': playerId, 'texture': false};
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
