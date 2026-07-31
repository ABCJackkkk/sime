import 'dart:convert';
import 'dart:typed_data';

class CharacterDisplayState {
  Map<String, String> remarkNames = {};
  Map<String, String> bioOverrides = {};
  Map<String, String> signOverrides = {};
  Map<String, String> avatarColors = {};
  Map<String, String> illustrations = {};
  Map<String, Uint8List?> imageBytes = {};
  Map<String, bool> unreadFlags = {};

  String displayName(String charId, String fallback) {
    final remark = remarkNames[charId];
    if (remark != null && remark.isNotEmpty) return remark;
    return fallback;
  }

  String getBioOverride(String charId) => bioOverrides[charId] ?? '';
  String getSignOverride(String charId) => signOverrides[charId] ?? '';
  bool hasUnread(String charId) => unreadFlags[charId] ?? false;

  void markRead(String charId) { unreadFlags[charId] = false; }
  void notifyNewMessage(String charId) { unreadFlags[charId] = true; }

  Map<String, dynamic> toJson() => {
    'remarkNames': remarkNames,
    'bioOverrides': bioOverrides,
    'signOverrides': signOverrides,
    'avatarColors': avatarColors,
    'illustrations': illustrations,
    'imageBytes': imageBytes.map((k, v) => MapEntry(k, v != null ? base64Encode(v) : null)),
    'unreadFlags': unreadFlags,
  };

  void fromJson(Map<String, dynamic> json) {
    remarkNames = Map<String, String>.from(json['remarkNames'] ?? {});
    bioOverrides = Map<String, String>.from(json['bioOverrides'] ?? {});
    signOverrides = Map<String, String>.from(json['signOverrides'] ?? {});
    avatarColors = Map<String, String>.from(json['avatarColors'] ?? {});
    illustrations = Map<String, String>.from(json['illustrations'] ?? {});
    final ib = json['imageBytes'] as Map<String, dynamic>?;
    imageBytes = ib?.map((k, v) => MapEntry(k, v != null ? Uint8List.fromList(base64Decode(v as String)) : null)) ?? {};
    unreadFlags = Map<String, bool>.from(json['unreadFlags'] ?? {});
  }
}
