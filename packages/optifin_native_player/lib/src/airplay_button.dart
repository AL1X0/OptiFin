import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Bouton AirPlay système (`AVRoutePickerView`) : iOS uniquement, vide ailleurs.
class AirPlayButton extends StatelessWidget {
  const AirPlayButton({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return const SizedBox.shrink();
    return SizedBox.square(
      dimension: size,
      child: const UiKitView(viewType: 'optifin_native_player/airplay', creationParamsCodec: StandardMessageCodec()),
    );
  }
}
