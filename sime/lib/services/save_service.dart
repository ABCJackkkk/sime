import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sime/models/script.dart';

class ChatMessage {
  final String senderId;
  final String senderName;
  String content;
  final DateTime timestamp;
  bool typewriterPlayed;
  ChatMessage({required this.senderId, required this.senderName, required this.content, DateTime? timestamp, this.typewriterPlayed = false}) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {'senderId': senderId, 'senderName': senderName, 'content': content, 'timestamp': timestamp.toIso8601String(), 'typewriterPlayed': typewriterPlayed};
  factory ChatMessage.fromSaved(Map<String, dynamic> json) {
    final ts = json['timestamp'];
    final parsed = ts != null ? DateTime.tryParse(ts.toString()) : null;
    return ChatMessage(senderId: json['senderId'] ?? '', senderName: json['senderName'] ?? '', content: json['content'] ?? '', timestamp: parsed, typewriterPlayed: json['typewriterPlayed'] == true);
  }
}

class SaveSlotMeta {
  final String slotId;
  final int index;
  final String scriptName;
  final String scriptId;
  final String currentDay;
  final String savedAt;
  final String createdAt;
  final String customName;

  SaveSlotMeta({
    required this.slotId,
    required this.index,
    required this.scriptName,
    required this.scriptId,
    required this.currentDay,
    required this.savedAt,
    required this.createdAt,
    this.customName = '',
  });

  Map<String, dynamic> toJson() => {
        'slotId': slotId, 'index': index, 'scriptName': scriptName,
        'scriptId': scriptId, 'currentDay': currentDay,
        'savedAt': savedAt, 'createdAt': createdAt,
        'customName': customName,
      };

  factory SaveSlotMeta.fromJson(Map<String, dynamic> json) => SaveSlotMeta(
        slotId: json['slotId'] ?? '', index: json['index'] ?? 0,
        scriptName: json['scriptName'] ?? '', scriptId: json['scriptId'] ?? '',
        currentDay: json['currentDay'] ?? '1', savedAt: json['savedAt'] ?? '',
        createdAt: json['createdAt'] ?? '',
        customName: json['customName'] ?? '',
      );
}

class SaveData {
  final String scriptId;
  final String scriptName;
  final String currentDay;
  final String currentSeason;
  final String currentWeather;
  final String currentPhase;
  final String narrativeHistory;
  final List<String> narrativeSegments;
  final List<String> segmentEventTypes;
  final Map<String, double> affectionStates;
  final Map<String, List<ChatMessage>> chatHistories;
  final List<String> inventoryItemIds;
  final Map<String, int> currencies;
  final String currentAct;
  final Map<String, bool> triggeredBeats;
  final double tensionLevel;
  final Map<String, double> endingProgress;
  final int eventCounter;
  final List<Map<String, dynamic>> recentEvents;
  final Map<String, dynamic>? relationData;
  final Map<String, dynamic>? eventSchedulerData;
  final Map<String, double> playerStats;
  final Map<String, double> playerGrades;
  final String userName;
  final String userGender;
  final String userHeight;
  final String userBirthday;
  final String userBio;
  final String userAppearance;
  final String userPersonality;
  final Map<String, dynamic>? charMemoryData;
  final Map<String, dynamic>? rankingData;
  final Map<String, dynamic>? userSettingsData;
  final Map<String, dynamic>? charDisplayData;
  final Map<String, dynamic>? tensionVectorData;
  final Map<String, dynamic>? worldEngineData;
  // 场景状态
  final bool sceneInteractionActive;
  final String activeSceneLocationId;
  final String activeSceneLocationName;
  final List<String> sceneInteractionChars;
  final String sceneInteractionNarrative;
  final String currentLocation;
  // 关键交互状态
  final Map<String, int> lastInteractionDays;
  final List<Map<String, dynamic>> pendingChoices;
  final Map<String, String> pendingInvitation;
  final Map<String, String?> initiativeCooldowns;
  final List<Map<String, dynamic>> activeForeshadow;
  final List<Map<String, dynamic>> butterflySeeds;
  final int longEventStepsRemaining;
  final bool inLongEvent;
  final String customName;

  SaveData({
    required this.scriptId, required this.scriptName,
    required this.currentDay, required this.currentSeason,
    required this.currentWeather, required this.currentPhase,
    required this.narrativeHistory, required this.narrativeSegments,
    required this.segmentEventTypes,
    required this.affectionStates, required this.chatHistories,
    required this.inventoryItemIds, required this.currencies,
    required this.currentAct, required this.triggeredBeats,
    required this.tensionLevel, required this.endingProgress,
    required this.eventCounter, required this.recentEvents,
    this.relationData, this.eventSchedulerData,
    required this.playerStats, required this.playerGrades,
    required this.userName, required this.userGender,
    required this.userHeight, required this.userBirthday,
    required this.userBio, required this.userAppearance,
    required this.userPersonality,
    this.charMemoryData,
    this.rankingData,
    this.userSettingsData,
    this.charDisplayData,
    this.tensionVectorData,
    this.worldEngineData,
    this.sceneInteractionActive = false,
    this.activeSceneLocationId = '',
    this.activeSceneLocationName = '',
    this.sceneInteractionChars = const [],
    this.sceneInteractionNarrative = '',
    this.currentLocation = '',
    this.lastInteractionDays = const {},
    this.pendingChoices = const [],
    this.pendingInvitation = const {},
    this.initiativeCooldowns = const {},
    this.activeForeshadow = const [],
    this.butterflySeeds = const [],
    this.longEventStepsRemaining = 0,
    this.inLongEvent = false,
    this.customName = '',
  });

  Map<String, dynamic> toJson() => {
        'scriptId': scriptId, 'scriptName': scriptName,
        'currentDay': currentDay, 'currentSeason': currentSeason,
        'currentWeather': currentWeather, 'currentPhase': currentPhase,
        'narrativeHistory': narrativeHistory, 'narrativeSegments': narrativeSegments,
        'segmentEventTypes': segmentEventTypes,
        'affectionStates': affectionStates.map((k, v) => MapEntry(k, v)),
        'chatHistories': Map<String, dynamic>.fromEntries(chatHistories.entries.map((e) => MapEntry(e.key, e.value.map((m) => m.toJson()).toList()))),
        'inventoryItemIds': inventoryItemIds, 'currencies': currencies,
        'currentAct': currentAct, 'triggeredBeats': triggeredBeats.map((k, v) => MapEntry(k, v)),
        'tensionLevel': tensionLevel, 'endingProgress': endingProgress.map((k, v) => MapEntry(k, v)),
        'eventCounter': eventCounter, 'recentEvents': recentEvents,
        'relationData': relationData, 'eventSchedulerData': eventSchedulerData,
        'playerStats': playerStats.map((k, v) => MapEntry(k, v)),
        'playerGrades': playerGrades.map((k, v) => MapEntry(k, v)),
        'userName': userName, 'userGender': userGender,
        'userHeight': userHeight, 'userBirthday': userBirthday,
        'userBio': userBio, 'userAppearance': userAppearance,
        'userPersonality': userPersonality,
        'charMemoryData': charMemoryData,
        'rankingData': rankingData,
        'userSettingsData': userSettingsData,
        'charDisplayData': charDisplayData,
        'tensionVectorData': tensionVectorData,
        'worldEngineData': worldEngineData,
        'sceneInteractionActive': sceneInteractionActive,
        'activeSceneLocationId': activeSceneLocationId,
        'activeSceneLocationName': activeSceneLocationName,
        'sceneInteractionChars': sceneInteractionChars,
        'sceneInteractionNarrative': sceneInteractionNarrative,
        'currentLocation': currentLocation,
        'lastInteractionDays': lastInteractionDays,
        'pendingChoices': pendingChoices,
        'pendingInvitation': pendingInvitation,
        'initiativeCooldowns': initiativeCooldowns,
        'activeForeshadow': activeForeshadow,
        'butterflySeeds': butterflySeeds,
        'longEventStepsRemaining': longEventStepsRemaining,
        'inLongEvent': inLongEvent,
        'customName': customName,
      };

  factory SaveData.fromJson(Map<String, dynamic> json) => SaveData(
        scriptId: json['scriptId'] ?? '',
        scriptName: json['scriptName'] ?? '',
        currentDay: json['currentDay'] ?? '1',
        currentSeason: json['currentSeason'] ?? '春',
        currentWeather: json['currentWeather'] ?? '晴',
        currentPhase: json['currentPhase'] ?? '上午',
        narrativeHistory: json['narrativeHistory'] ?? '',
        narrativeSegments: List<String>.from(json['narrativeSegments'] ?? []),
        segmentEventTypes: List<String>.from(json['segmentEventTypes'] ?? []),
        affectionStates: (json['affectionStates'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
        chatHistories: (json['chatHistories'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as List<dynamic>).map((m) => ChatMessage.fromSaved(m as Map<String, dynamic>)).toList())) ?? {},
        inventoryItemIds: List<String>.from(json['inventoryItemIds'] ?? []),
        currencies: (json['currencies'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toInt())) ?? {'gold': 50},
        currentAct: json['currentAct'] ?? 'act_1',
        triggeredBeats: (json['triggeredBeats'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v == true)) ?? {},
        tensionLevel: (json['tensionLevel'] as num?)?.toDouble() ?? 20.0,
        endingProgress: (json['endingProgress'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
        eventCounter: json['eventCounter'] ?? 0,
        recentEvents: List<Map<String, dynamic>>.from(json['recentEvents'] ?? []),
        relationData: json['relationData'] as Map<String, dynamic>?,
        eventSchedulerData: json['eventSchedulerData'] as Map<String, dynamic>?,
        playerStats: (json['playerStats'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
        playerGrades: (json['playerGrades'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
        userName: json['userName'] ?? '主角',
        userGender: json['userGender'] ?? '男',
        userHeight: json['userHeight'] ?? '',
        userBirthday: json['userBirthday'] ?? '',
        userBio: json['userBio'] ?? '',
        userAppearance: json['userAppearance'] ?? '',
        userPersonality: json['userPersonality'] ?? '',
        charMemoryData: json['charMemoryData'] as Map<String, dynamic>?,
        rankingData: json['rankingData'] as Map<String, dynamic>?,
        userSettingsData: json['userSettingsData'] as Map<String, dynamic>?,
        charDisplayData: json['charDisplayData'] as Map<String, dynamic>?,
        tensionVectorData: json['tensionVectorData'] as Map<String, dynamic>?,
        worldEngineData: json['worldEngineData'] as Map<String, dynamic>?,
        sceneInteractionActive: json['sceneInteractionActive'] == true,
        activeSceneLocationId: json['activeSceneLocationId'] as String? ?? '',
        activeSceneLocationName: json['activeSceneLocationName'] as String? ?? '',
        sceneInteractionChars: List<String>.from(json['sceneInteractionChars'] ?? []),
        sceneInteractionNarrative: json['sceneInteractionNarrative'] as String? ?? '',
        currentLocation: json['currentLocation'] as String? ?? '',
        lastInteractionDays: (json['lastInteractionDays'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toInt())) ?? {},
        pendingChoices: List<Map<String, dynamic>>.from(json['pendingChoices'] ?? []),
        pendingInvitation: (json['pendingInvitation'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? {},
        initiativeCooldowns: (json['initiativeCooldowns'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v?.toString())) ?? {},
        activeForeshadow: List<Map<String, dynamic>>.from(json['activeForeshadow'] ?? []),
        butterflySeeds: List<Map<String, dynamic>>.from(json['butterflySeeds'] ?? []),
        longEventStepsRemaining: json['longEventStepsRemaining'] as int? ?? 0,
        inLongEvent: json['inLongEvent'] == true,
        customName: json['customName'] ?? '',
      );
}

class SaveService {
  static const _slotsKey = 'save_slots_index';
  static const _maxSlots = 8;
  static const _scriptStoreKeyPrefix = 'script_store_';

  List<SaveSlotMeta> _slots = [];

  List<SaveSlotMeta> get slots => List.unmodifiable(_slots);

  bool get hasSlots => _slots.isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final indexJson = prefs.getString(_slotsKey);
    if (indexJson != null) {
      try {
        final list = json.decode(indexJson) as List;
        _slots = list.map((e) => SaveSlotMeta.fromJson(e as Map<String, dynamic>)).toList();
        // 修正 index 字段，确保和列表位置一致
        bool needsReindex = false;
        for (int i = 0; i < _slots.length; i++) {
          if (_slots[i].index != i) {
            _slots[i] = SaveSlotMeta(
              slotId: _slots[i].slotId, index: i,
              scriptName: _slots[i].scriptName, scriptId: _slots[i].scriptId,
              currentDay: _slots[i].currentDay,
              savedAt: _slots[i].savedAt, createdAt: _slots[i].createdAt,
              customName: _slots[i].customName,
            );
            needsReindex = true;
          }
        }
        if (needsReindex) await _persistSlots(prefs);
      } catch (_) {
        _slots = [];
      }
    }
  }

  Future<String> save(SaveData data, GameScript script, {int? slotIndex, String? scriptJson, String? customName}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final slotId = 'slot_${now.millisecondsSinceEpoch}';

    final saveMap = data.toJson();
    saveMap['savedAt'] = now.toIso8601String();
    saveMap['customName'] = customName ?? '';

    late final SaveSlotMeta meta;
    if (slotIndex != null && slotIndex < _slots.length) {
      meta = SaveSlotMeta(
        slotId: _slots[slotIndex].slotId, index: slotIndex,
        scriptName: script.meta.name, scriptId: script.meta.id,
        currentDay: data.currentDay,
        savedAt: now.toIso8601String(), createdAt: _slots[slotIndex].createdAt,
        customName: customName ?? _slots[slotIndex].customName,
      );
      saveMap['createdAt'] = meta.createdAt;
      _slots[slotIndex] = meta;
    } else {
      if (_slots.length >= _maxSlots) {
        return '已达最大存档数 ($_maxSlots)，请先删除旧存档';
      }
      final index = slotIndex ?? _slots.length;
      saveMap['createdAt'] = now.toIso8601String();
      meta = SaveSlotMeta(
        slotId: slotId, index: index,
        scriptName: script.meta.name, scriptId: script.meta.id,
        currentDay: data.currentDay,
        savedAt: now.toIso8601String(), createdAt: now.toIso8601String(),
        customName: customName ?? '',
      );
      _slots.add(meta);
    }

    await prefs.setString('save_data_${meta.slotId}', json.encode(saveMap));

    // 剧本 JSON 共享存储：同 scriptId 只存一份
    final scriptStoreKey = '$_scriptStoreKeyPrefix${script.meta.id}';
    final existing = prefs.getString(scriptStoreKey);
    if (existing == null) {
      String? resolved = scriptJson;
      if (resolved == null) {
        try {
          resolved = await rootBundle.loadString('assets/scripts/${script.meta.id}.json');
        } catch (_) {
          resolved = '';
        }
      }
      if (resolved.isNotEmpty) {
        await prefs.setString(scriptStoreKey, resolved);
      }
    }
    await _persistSlots(prefs);
    return 'ok';
  }

  Future<SaveData?> load(int slotIndex) async {
    if (slotIndex < 0 || slotIndex >= _slots.length) return null;
    final meta = _slots[slotIndex];
    final prefs = await SharedPreferences.getInstance();
    final dataJson = prefs.getString('save_data_${meta.slotId}');
    if (dataJson == null) return null;
    try {
      return SaveData.fromJson(json.decode(dataJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  String? getStoredScriptId(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= _slots.length) return null;
    return _slots[slotIndex].scriptId;
  }

  Future<String?> getStoredScriptJson(int slotIndex) async {
    if (slotIndex < 0 || slotIndex >= _slots.length) return null;
    final scriptId = _slots[slotIndex].scriptId;
    final prefs = await SharedPreferences.getInstance();
    // 优先从共享存储读
    final shared = prefs.getString('$_scriptStoreKeyPrefix$scriptId');
    if (shared != null) return shared;
    // 向后兼容：旧版存档可能存在 slot 级 script
    return prefs.getString('save_script_${_slots[slotIndex].slotId}');
  }

  Future<void> delete(int slotIndex) async {
    if (slotIndex < 0 || slotIndex >= _slots.length) return;
    final slotId = _slots[slotIndex].slotId;
    final scriptId = _slots[slotIndex].scriptId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('save_data_$slotId');
    await prefs.remove('save_script_$slotId'); // 清理旧版残留
    _slots.removeAt(slotIndex);
    // 修正剩余 slot 的 index
    for (int i = 0; i < _slots.length; i++) {
      if (_slots[i].index != i) {
        _slots[i] = SaveSlotMeta(
          slotId: _slots[i].slotId, index: i,
          scriptName: _slots[i].scriptName, scriptId: _slots[i].scriptId,
          currentDay: _slots[i].currentDay,
          savedAt: _slots[i].savedAt, createdAt: _slots[i].createdAt,
          customName: _slots[i].customName,
        );
      }
    }
    // 检查是否还有同 scriptId 的存档，没有则清理共享剧本存储
    final stillHas = _slots.any((s) => s.scriptId == scriptId);
    if (!stillHas) {
      await prefs.remove('$_scriptStoreKeyPrefix$scriptId');
    }
    await _persistSlots(prefs);
  }

  Future<void> _persistSlots(SharedPreferences prefs) async {
    await prefs.setString(_slotsKey, json.encode(_slots.map((s) => s.toJson()).toList()));
  }
}
