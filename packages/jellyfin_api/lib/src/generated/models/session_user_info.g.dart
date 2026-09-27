// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_user_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionUserInfo _$SessionUserInfoFromJson(Map<String, dynamic> json) =>
    SessionUserInfo(
      userId: json['UserId'] as String?,
      userName: json['UserName'] as String?,
    );

Map<String, dynamic> _$SessionUserInfoToJson(SessionUserInfo instance) =>
    <String, dynamic>{
      'UserId': ?instance.userId,
      'UserName': ?instance.userName,
    };
