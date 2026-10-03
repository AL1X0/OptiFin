import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const _viewType = 'optifin_native_player/mpv_surface';

/// Surface Android (SurfaceView) où libmpv dessine directement (`--wid`), comme mpv-android :
/// aucune texture Flutter intermédiaire. [onSurface] reçoit la référence de la surface et sa
/// taille en pixels ; `wid == 0` quand elle disparaît (mpv doit alors la lâcher aussitôt).
///
/// Composition hybride : seule une vraie SurfaceView passe sur tous les téléviseurs.
class MpvSurfaceView extends StatefulWidget {
  const MpvSurfaceView({super.key, required this.onSurface});

  final void Function(int wid, int width, int height) onSurface;

  @override
  State<MpvSurfaceView> createState() => _MpvSurfaceViewState();
}

class _MpvSurfaceViewState extends State<MpvSurfaceView> {
  static const _channel = MethodChannel(_viewType);
  static final _views = <int, _MpvSurfaceViewState>{};
  static bool _listening = false;

  int? _id;

  static void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'surface') return;
      final args = call.arguments as Map<Object?, Object?>;
      final view = _views[(args['view'] as num).toInt()];
      view?.widget.onSurface(
        (args['wid'] as num).toInt(),
        (args['width'] as num).toInt(),
        (args['height'] as num).toInt(),
      );
    });
  }

  @override
  void dispose() {
    if (_id != null) _views.remove(_id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) return const SizedBox.shrink();
    _listen();
    return PlatformViewLink(
      viewType: _viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      ),
      onCreatePlatformView: (params) {
        _id = params.id;
        _views[params.id] = this;
        return PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: _viewType,
            layoutDirection: TextDirection.ltr,
            creationParamsCodec: const StandardMessageCodec(),
          )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}
