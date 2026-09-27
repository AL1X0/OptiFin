import AVFoundation
import CoreMedia
import UIKit
import VideoToolbox

/// Ce que l'AVPlayer de cet appareil sait lire et afficher.
///
/// Clés lues par `DeviceCapabilities.fromJson` côté Dart.
enum CapabilitiesProbe {
  static func probe() -> [String: Any] {
    let hevc = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)
    var video = ["h264"]
    if hevc { video.append("hevc") }
    if #available(iOS 17.0, *), VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1) {
      video.append("av1")
    }
    // VP9 : AVPlayer ne lit pas le WebM ; laissé à mpv.

    // AVPlayer affiche le HDR10 / HLG sur écran HDR et le convertit proprement
    // sur écran SDR dès que le HEVC 10 bits est décodé en matériel (A9+).
    var ranges = ["sdr"]
    if hevc { ranges += ["hdr10", "hlg"] }
    let dolbyVision = AVPlayer.availableHDRModes.contains(.dolbyVision)
    if dolbyVision { ranges.append("dolbyVision") }

    return [
      "platform": "ios",
      "nativeAvailable": true,
      "model": modelIdentifier(),
      "osVersion": UIDevice.current.systemVersion,
      "videoCodecs": video,
      "hevcMain10": hevc,
      "ranges": ranges,
      // AVPlayer : profils 5 (MP4/HLS) et 8.x ; le profil 7 passe par sa couche de base.
      "dolbyVisionProfiles": dolbyVision ? [5, 8] : [Int](),
      "audioCodecs": ["aac", "mp3", "ac3", "eac3", "alac", "flac"],
      "containers": ["mp4", "m4v", "mov"],
      "maxWidth": hevc ? 3840 : 1920,
    ]
  }

  /// Identifiant matériel (« iPhone16,1 »), utile dans les journaux.
  private static func modelIdentifier() -> String {
    var info = utsname()
    uname(&info)
    let mirror = Mirror(reflecting: info.machine)
    return mirror.children.reduce(into: "") { acc, element in
      if let value = element.value as? Int8, value != 0 { acc.append(Character(UnicodeScalar(UInt8(value)))) }
    }
  }
}
