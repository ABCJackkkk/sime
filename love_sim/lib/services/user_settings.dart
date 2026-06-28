import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';

class UserSettings {
  String name = '主角';
  String gender = '男';
  String height = '';
  String birthday = '';
  String bio = '';
  String appearance = '';
  String personality = '';
  Uint8List? avatarBytes;
  Uint8List? bgImageBytes;
  String avatarColor = 'blue';

  bool isDarkMode = true;
  int fontSizeLevel = 2;

  String globalBgType = 'default';
  String globalBgColor1 = '0A0A0C';
  String globalBgColor2 = '0D0D15';
  String simBgType = 'gradient';
  String simBgColor1 = '0D0D15';
  String simBgColor2 = '0A0A0C';
  Uint8List? simBgImageBytes;

  double get baseFontSize => [14.0, 15.0, 16.0, 17.0, 18.0][fontSizeLevel.clamp(0, 4)];

  Color get simBgStartColor => Color(int.tryParse('0xFF$simBgColor1') ?? 0xFF1A1A2E);
  Color get simBgEndColor => Color(int.tryParse('0xFF$simBgColor2') ?? 0xFF1A1A2E);

  Map<String, dynamic> toJson() => {
    'name': name, 'gender': gender, 'height': height, 'birthday': birthday,
    'bio': bio, 'appearance': appearance, 'personality': personality,
    'isDarkMode': isDarkMode, 'fontSizeLevel': fontSizeLevel,
    'globalBgType': globalBgType, 'globalBgColor1': globalBgColor1, 'globalBgColor2': globalBgColor2,
    'simBgType': simBgType, 'simBgColor1': simBgColor1, 'simBgColor2': simBgColor2,
    'avatarBytes': avatarBytes != null ? base64Encode(avatarBytes!) : null,
    'bgImageBytes': bgImageBytes != null ? base64Encode(bgImageBytes!) : null,
    'simBgImageBytes': simBgImageBytes != null ? base64Encode(simBgImageBytes!) : null,
  };

  void fromJson(Map<String, dynamic> json) {
    name = json['name'] ?? '主角';
    gender = json['gender'] ?? '男';
    height = json['height'] ?? '';
    birthday = json['birthday'] ?? '';
    bio = json['bio'] ?? '';
    appearance = json['appearance'] ?? '';
    personality = json['personality'] ?? '';
    isDarkMode = json['isDarkMode'] ?? true;
    fontSizeLevel = json['fontSizeLevel'] ?? 2;
    globalBgType = json['globalBgType'] ?? 'default';
    globalBgColor1 = json['globalBgColor1'] ?? '0A0A0C';
    globalBgColor2 = json['globalBgColor2'] ?? '0D0D15';
    simBgType = json['simBgType'] ?? 'gradient';
    simBgColor1 = json['simBgColor1'] ?? '0D0D15';
    simBgColor2 = json['simBgColor2'] ?? '0A0A0C';
    final ab = json['avatarBytes'];
    avatarBytes = ab != null ? Uint8List.fromList(base64Decode(ab as String)) : null;
    final bgb = json['bgImageBytes'];
    bgImageBytes = bgb != null ? Uint8List.fromList(base64Decode(bgb as String)) : null;
    final sbg = json['simBgImageBytes'];
    simBgImageBytes = sbg != null ? Uint8List.fromList(base64Decode(sbg as String)) : null;
  }
}
