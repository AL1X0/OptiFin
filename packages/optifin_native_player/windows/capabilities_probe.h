#ifndef OPTIFIN_CAPABILITIES_PROBE_H_
#define OPTIFIN_CAPABILITIES_PROBE_H_

#include <flutter/encodable_value.h>

namespace optifin {

// Ce que la carte graphique sait décoder (D3D11VA, utilisé par mpv) et ce que l'écran sait
// afficher (HDR). Clés lues par `DeviceCapabilities.fromJson` côté Dart.
flutter::EncodableMap ProbeCapabilities();

}  // namespace optifin

#endif  // OPTIFIN_CAPABILITIES_PROBE_H_
