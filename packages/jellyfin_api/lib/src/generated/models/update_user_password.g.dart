// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_user_password.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateUserPassword _$UpdateUserPasswordFromJson(Map<String, dynamic> json) =>
    UpdateUserPassword(
      currentPassword: json['CurrentPassword'] as String?,
      currentPw: json['CurrentPw'] as String?,
      newPw: json['NewPw'] as String?,
      resetPassword: json['ResetPassword'] as bool?,
    );

Map<String, dynamic> _$UpdateUserPasswordToJson(UpdateUserPassword instance) =>
    <String, dynamic>{
      'CurrentPassword': ?instance.currentPassword,
      'CurrentPw': ?instance.currentPw,
      'NewPw': ?instance.newPw,
      'ResetPassword': ?instance.resetPassword,
    };
