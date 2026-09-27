// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'image_blur_hashes.g.dart';

@JsonSerializable()
class ImageBlurHashes {
  const ImageBlurHashes({
    this.primary,
    this.art,
    this.backdrop,
    this.banner,
    this.logo,
    this.thumb,
    this.disc,
    this.box,
    this.screenshot,
    this.menu,
    this.chapter,
    this.boxRear,
    this.profile,
  });
  
  factory ImageBlurHashes.fromJson(Map<String, Object?> json) => _$ImageBlurHashesFromJson(json);
  
  @JsonKey(name: 'Primary')
  final Map<String, String?>? primary;
  @JsonKey(name: 'Art')
  final Map<String, String?>? art;
  @JsonKey(name: 'Backdrop')
  final Map<String, String?>? backdrop;
  @JsonKey(name: 'Banner')
  final Map<String, String?>? banner;
  @JsonKey(name: 'Logo')
  final Map<String, String?>? logo;
  @JsonKey(name: 'Thumb')
  final Map<String, String?>? thumb;
  @JsonKey(name: 'Disc')
  final Map<String, String?>? disc;
  @JsonKey(name: 'Box')
  final Map<String, String?>? box;
  @JsonKey(name: 'Screenshot')
  final Map<String, String?>? screenshot;
  @JsonKey(name: 'Menu')
  final Map<String, String?>? menu;
  @JsonKey(name: 'Chapter')
  final Map<String, String?>? chapter;
  @JsonKey(name: 'BoxRear')
  final Map<String, String?>? boxRear;
  @JsonKey(name: 'Profile')
  final Map<String, String?>? profile;

  Map<String, Object?> toJson() => _$ImageBlurHashesToJson(this);
}
