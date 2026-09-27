// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'authenticate_user_by_name.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthenticateUserByName _$AuthenticateUserByNameFromJson(
  Map<String, dynamic> json,
) => AuthenticateUserByName(
  username: json['Username'] as String?,
  pw: json['Pw'] as String?,
);

Map<String, dynamic> _$AuthenticateUserByNameToJson(
  AuthenticateUserByName instance,
) => <String, dynamic>{'Username': ?instance.username, 'Pw': ?instance.pw};
