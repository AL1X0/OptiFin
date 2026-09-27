// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'codec_profile.dart';
import 'container_profile.dart';
import 'direct_play_profile.dart';
import 'subtitle_profile.dart';
import 'transcoding_profile.dart';

part 'device_profile.g.dart';

/// A MediaBrowser.Model.Dlna.DeviceProfile represents a set of metadata which determines which content a certain device is able to play.
///
///
/// Specifically, it defines the supported <see cref="P:MediaBrowser.Model.Dlna.DeviceProfile.ContainerProfiles">containers</see> and.
/// <see cref="P:MediaBrowser.Model.Dlna.DeviceProfile.CodecProfiles">codecs</see> (video and/or audio, including codec profiles and levels).
/// the device is able to direct play (without transcoding or remuxing),.
/// as well as which <see cref="P:MediaBrowser.Model.Dlna.DeviceProfile.TranscodingProfiles">containers/codecs to transcode to</see> in case it isn't.
@JsonSerializable()
class DeviceProfile {
  const DeviceProfile({
    this.name,
    this.id,
    this.maxStreamingBitrate,
    this.maxStaticBitrate,
    this.musicStreamingTranscodingBitrate,
    this.maxStaticMusicBitrate,
    this.directPlayProfiles,
    this.transcodingProfiles,
    this.containerProfiles,
    this.codecProfiles,
    this.subtitleProfiles,
  });
  
  factory DeviceProfile.fromJson(Map<String, Object?> json) => _$DeviceProfileFromJson(json);
  
  /// Gets or sets the name of this device profile. User profiles must have a unique name.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets the unique internal identifier.
  @JsonKey(name: 'Id')
  final String? id;

  /// Gets or sets the maximum allowed bitrate for all streamed content.
  @JsonKey(name: 'MaxStreamingBitrate')
  final int? maxStreamingBitrate;

  /// Gets or sets the maximum allowed bitrate for statically streamed content (= direct played files).
  @JsonKey(name: 'MaxStaticBitrate')
  final int? maxStaticBitrate;

  /// Gets or sets the maximum allowed bitrate for transcoded music streams.
  @JsonKey(name: 'MusicStreamingTranscodingBitrate')
  final int? musicStreamingTranscodingBitrate;

  /// Gets or sets the maximum allowed bitrate for statically streamed (= direct played) music files.
  @JsonKey(name: 'MaxStaticMusicBitrate')
  final int? maxStaticMusicBitrate;

  /// Gets or sets the direct play profiles.
  @JsonKey(name: 'DirectPlayProfiles')
  final List<DirectPlayProfile>? directPlayProfiles;

  /// Gets or sets the transcoding profiles.
  @JsonKey(name: 'TranscodingProfiles')
  final List<TranscodingProfile>? transcodingProfiles;

  /// Gets or sets the container profiles. Failing to meet these optional conditions causes transcoding to occur.
  @JsonKey(name: 'ContainerProfiles')
  final List<ContainerProfile>? containerProfiles;

  /// Gets or sets the codec profiles.
  @JsonKey(name: 'CodecProfiles')
  final List<CodecProfile>? codecProfiles;

  /// Gets or sets the subtitle profiles.
  @JsonKey(name: 'SubtitleProfiles')
  final List<SubtitleProfile>? subtitleProfiles;

  Map<String, Object?> toJson() => _$DeviceProfileToJson(this);
}
