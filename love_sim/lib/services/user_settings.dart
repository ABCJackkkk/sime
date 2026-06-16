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

  Color get simBgStartColor => Color(int.parse('0xFF$simBgColor1'));
  Color get simBgEndColor => Color(int.parse('0xFF$simBgColor2'));

  Map<String, dynamic> toJson() => {
    'name': name, 'gender': gender, 'height': height, 'birthday': birthday,
    'bio': bio, 'appearance': appearance, 'personality': personality,
    'isDarkMode': isDarkMode, 'fontSizeLevel': fontSizeLevel,
    'globalBgType': globalBgType, 'globalBgColor1': globalBgColor1, 'globalBgColor2': globalBgColor2,
    'simBgType': simBgType, 'simBgColor1': simBgColor1, 'simBgColor2': simBgColor2,
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
  }
}
