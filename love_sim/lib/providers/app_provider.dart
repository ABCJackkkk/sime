import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:love_sim/models/script.dart';
import 'package:love_sim/services/script_loader.dart';
import 'package:love_sim/services/deepseek_client.dart';
import 'package:love_sim/services/world_engine.dart';
import 'package:love_sim/services/event_scheduler.dart';
import 'package:love_sim/services/save_service.dart';
import 'package:love_sim/services/narrative_compressor.dart';
import 'package:love_sim/services/script_registry.dart';
import 'package:love_sim/services/game_session.dart';
import 'package:love_sim/services/user_settings.dart';
import 'package:love_sim/services/character_display_state.dart';
import 'package:love_sim/services/affection_engine.dart';
import 'package:love_sim/services/relationship_engine.dart';
import 'package:love_sim/services/character_memory_service.dart';
import 'package:love_sim/services/ranking_service.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:love_sim/services/phase_action_service.dart';

class AppProvider extends ChangeNotifier {
  DeepSeekClient? _deepSeekClient;
  WorldEngine? _worldEngine;
  SaveService? _saveService;
  NarrativeCompressor? _narrativeCompressor;
  final ScriptLoader _scriptLoader = ScriptLoader();

  final UserSettings _userSettings = UserSettings();
  final CharacterDisplayState _charDisplay = CharacterDisplayState();
  GameSession? _session;

  UserSettings get userSettings => _userSettings;
  CharacterDisplayState get charDisplay => _charDisplay;
  GameSession? get session => _session;

  bool isDiscovered(String charId) => true; // TODO: wire to GameSession
  List<Character> get discoveredCharacters => _session?.script?.characters.where((c) => c.fullCharacter).toList() ?? [];

  int _currentTabIndex = 0;
  int _simTabIndex = 0;
  bool _simInWorldView = true;

  bool get simInWorldView => _simInWorldView;
  void setSimInWorldView(bool v) { _simInWorldView = v; notifyListeners(); }
  void toggleSimView() { _simInWorldView = !_simInWorldView; notifyListeners(); }

  bool _hasScript = false;
  bool _simActive = false;
  String _apiKey = '';
  String _corsProxy = '';

  List<Map<String, dynamic>> _customScripts = [];
  List<Map<String, dynamic>> get customScripts => _customScripts;

  void addCustomScript(String name, String jsonString) {
    _customScripts.removeWhere((s) => s['name'] == name);
    _customScripts.insert(0, {'name': name, 'json': jsonString, 'addedAt': DateTime.now().toIso8601String()});
    if (_customScripts.length > 20) { _customScripts = _customScripts.sublist(0, 20); }
    notifyListeners();
  }

  void removeCustomScript(int index) {
    if (index >= 0 && index < _customScripts.length) { _customScripts.removeAt(index); notifyListeners(); }
  }

  // ─── Init ───

  Future<void> init() async {
    _saveService = SaveService();
    await _saveService!.init();
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('api_key') ?? '';
    _corsProxy = prefs.getString('cors_proxy') ?? '';
    if (savedKey.isNotEmpty) {
      _apiKey = savedKey;
      _deepSeekClient = DeepSeekClient(apiKey: savedKey, corsProxy: _corsProxy.isNotEmpty ? _corsProxy : null);
      _narrativeCompressor = NarrativeCompressor();
      _narrativeCompressor!.attach(_deepSeekClient!);
    }
    await _loadSaveSlots();
    notifyListeners();
  }

  String? get corsProxy => _corsProxy.isNotEmpty ? _corsProxy : null;

  Future<void> setCorsProxy(String url) async {
    _corsProxy = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cors_proxy', url);
    if (_apiKey.isNotEmpty) {
      _deepSeekClient = DeepSeekClient(apiKey: _apiKey, corsProxy: url.isNotEmpty ? url : null);
      if (_session?.script != null) {
        _worldEngine = WorldEngine(script: _session!.script!, client: _deepSeekClient!);
        _worldEngine!.initFromScript();
      }
    }
    notifyListeners();
  }

  // ─── Save/load ───

  List<Map<String, dynamic>> get saveSlots => _saveService?.slots.map((s) => s.toJson()).toList() ?? [];
  bool get hasSaveSlots => _saveService?.hasSlots ?? false;

  Future<void> _loadSaveSlots() async { await _saveService?.init(); }

  Future<String> saveCurrentToSlot({int? slotIndex}) async {
    final s = _session;
    if (s == null || s.script == null || _saveService == null) return '无法存档';
    final data = SaveData(
      scriptId: s.script!.meta.id, scriptName: s.script!.meta.name,
      currentDay: s.currentDay, currentSeason: s.currentSeason, currentWeather: s.currentWeather, currentPhase: s.currentPhase,
      narrativeHistory: s.narrativeHistory, narrativeSegments: s.narrativeSegments,
      segmentEventTypes: s.segmentEventTypes,
      affectionStates: s.affectionStates,
      chatHistories: s.chatHistories,
      inventoryItemIds: s.inventoryItemIds, currencies: s.currencies,
      currentAct: s.currentAct, triggeredBeats: s.triggeredBeats, tensionLevel: s.tensionLevel, endingProgress: s.endingProgress,
      eventCounter: s.eventCounter, recentEvents: s.recentEvents,
      userName: _userSettings.name, userGender: _userSettings.gender, userHeight: _userSettings.height, userBirthday: _userSettings.birthday,
      userBio: _userSettings.bio, userAppearance: _userSettings.appearance, userPersonality: _userSettings.personality,
      relationData: s.relationshipEngine?.toJson(), eventSchedulerData: s.eventScheduler?.toJson(),
      playerStats: s.playerStats, playerGrades: s.playerGrades,
      charMemoryData: s.charMemory?.toJson(),
      rankingData: s.rankingService?.toJson(),
      userSettingsData: _userSettings.toJson(),
      charDisplayData: _charDisplay.toJson(),
      tensionVectorData: s.tensionVectorData,
    );
    try {
      final result = await _saveService!.save(data, s.script!, slotIndex: slotIndex);
      notifyListeners(); return result;
    } catch (e) { return '存档失败: $e'; }
  }

  Future<String> autoSave() async {
    if (_session?.script == null || _saveService == null) return 'ok';
    final slots = _saveService!.slots;
    final existing = slots.indexWhere((s) => s.scriptId == _session!.script!.meta.id && s.scriptName == _session!.script!.meta.name);
    return saveCurrentToSlot(slotIndex: existing >= 0 ? existing : null);
  }

  Future<String> loadSaveSlot(int slotIndex) async {
    if (_saveService == null) return '存档服务未就绪';
    final data = await _saveService!.load(slotIndex);
    if (data == null) return '存档数据丢失';

    GameScript? loadedScript;
    if (_session?.script == null || _session!.script!.meta.id != data.scriptId) {
      final scriptJson = await _saveService!.getStoredScriptJson(slotIndex);
      if (scriptJson == null) return '剧本数据丢失，请重新导入';
      loadedScript = _scriptLoader.loadFromJsonString(scriptJson);
      _hasScript = true;
    } else {
      loadedScript = _session!.script;
    }

    _session = GameSession();
    _session!.script = loadedScript;
    _session!.deepSeekClient = _deepSeekClient;
    if (_narrativeCompressor != null) _session!.narrativeCompressor = _narrativeCompressor;
    _session!.onChanged = () => notifyListeners();

    _session!.initFromScript(userName: _userSettings.name);
    if (_deepSeekClient != null && loadedScript != null) {
      _worldEngine = WorldEngine(script: loadedScript, client: _deepSeekClient!);
      _worldEngine!.initFromScript();
      _worldEngine!.initWorldServices();
      final day = int.tryParse(_session!.currentDay) ?? 1;
      _worldEngine!.currentDay = day;
    }

    _session!.setDay(data.currentDay);
    _session!.setSeason(data.currentSeason);
    _session!.setWeather(data.currentWeather);
    _session!.setPhase(data.currentPhase);
    _session!.setNarrativeHistory(data.narrativeHistory);
    _session!.setNarrativeSegments(data.narrativeSegments);
    _session!.setSegmentEventTypes(data.segmentEventTypes);
    _session!.setAffectionStates(data.affectionStates);
    _session!.setChatHistories(data.chatHistories);
    _session!.setInventoryItemIds(data.inventoryItemIds);
    _session!.setCurrencies(data.currencies);
    _session!.setCurrentAct(data.currentAct);
    _session!.setTriggeredBeats(data.triggeredBeats);
    if (data.tensionVectorData != null) {
      _session!.restoreTension(data.tensionVectorData!);
    } else {
      _session!.setTensionLevel(data.tensionLevel);
    }
    _session!.setEndingProgress(data.endingProgress);
    _session!.setEventCounter(data.eventCounter);
    _session!.setRecentEvents(data.recentEvents);
    _session!.setPlayerStats(data.playerStats);
    _session!.setPlayerGrades(data.playerGrades);

    _session!.charMemory = CharacterMemoryService();
    if (data.charMemoryData != null) _session!.charMemory!.fromJson(data.charMemoryData!);
    if (data.rankingData != null && _session!.rankingService != null) _session!.rankingService!.fromJson(data.rankingData!);

    if (data.userSettingsData != null) _userSettings.fromJson(data.userSettingsData!);
    _userSettings.name = data.userName;
    _userSettings.gender = data.userGender;
    _userSettings.height = data.userHeight;
    _userSettings.birthday = data.userBirthday;
    _userSettings.bio = data.userBio;
    _userSettings.appearance = data.userAppearance;
    _userSettings.personality = data.userPersonality;

    if (data.charDisplayData != null) _charDisplay.fromJson(data.charDisplayData!);

    if (_session!.script != null) {
      _session!.affectionEngine = AffectionEngine(script: _session!.script!, affectionConfig: _session!.script!.gameInteraction?.affection);
      _session!.relationshipEngine = RelationshipEngine(_session!.affectionEngine!);
      _session!.eventScheduler = EventScheduler();
      for (final e in _session!.affectionStates.entries) {
        _session!.affectionEngine!.init(e.key, e.value);
        _session!.relationshipEngine!.init(e.key, e.value);
      }
      if (data.relationData != null) _session!.relationshipEngine!.fromJson(data.relationData!);
      if (data.eventSchedulerData != null) _session!.eventScheduler!.fromJson(data.eventSchedulerData!);
    }
    _session!.refreshSceneChars();
    _simActive = true;
    notifyListeners();
    return 'ok';
  }

  Future<void> deleteSaveSlot(int slotIndex) async {
    await _saveService?.delete(slotIndex); notifyListeners();
  }

  Future<void> resetSaveSlot(int slotIndex) async {
    await _saveService?.init(); notifyListeners();
  }

  // ─── Script management ───

  Future<void> loadScriptFromJsonString(String jsonString, {String? displayName}) async {
    _isLoading(true);
    try {
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      final loadedScript = GameScript.fromJson(jsonMap);
      _hasScript = true;
      _initSession(loadedScript);
      final name = displayName ?? loadedScript.meta.name;
      addCustomScript(name, jsonString);
    } catch (e) { rethrow; }
    _isLoading(false);
  }

  Future<void> loadCustomScript(int index) async {
    if (index < 0 || index >= _customScripts.length) return;
    final entry = _customScripts[index];
    await loadScriptFromJsonString(entry['json'] as String, displayName: entry['name'] as String?);
  }

  Future<String?> loadScript(String assetPath) async {
    _isLoading(true);
    GameScript? loadedScript;
    try {
      loadedScript = await _scriptLoader.loadFromAsset(assetPath);
      ScriptRegistry().registerEntry(ScriptEntry(
        id: loadedScript.meta.id, name: loadedScript.meta.name, version: loadedScript.meta.version,
        assetPath: assetPath, type: loadedScript.meta.type, description: loadedScript.meta.description,
        script: loadedScript,
      ));
    } catch (e) { _hasScript = false; _isLoading(false); return '解析失败: $e'; }
    try {
      _hasScript = true;
      _initSession(loadedScript);
    } catch (e) { _hasScript = false; _isLoading(false); return '初始化失败: $e'; }
    _isLoading(false);
    return null;
  }

  void _initSession(GameScript loadedScript) {
    _session = GameSession();
    _session!.script = loadedScript;
    _session!.deepSeekClient = _deepSeekClient;
    if (_narrativeCompressor != null) _session!.narrativeCompressor = _narrativeCompressor;
    _session!.onChanged = () => notifyListeners();
    _session!.initFromScript(userName: _userSettings.name);

    if (_deepSeekClient != null) {
      _worldEngine = WorldEngine(script: loadedScript, client: _deepSeekClient!);
      _worldEngine!.initFromScript();
      _worldEngine!.initWorldServices();
    }
  }

  void setApiKey(String key) {
    _apiKey = key;
    if (key.isNotEmpty) {
      _deepSeekClient = DeepSeekClient(apiKey: key, corsProxy: _corsProxy.isNotEmpty ? _corsProxy : null);
      _narrativeCompressor = NarrativeCompressor();
      _narrativeCompressor!.attach(_deepSeekClient!);
      if (_session?.script != null) {
        _session!.deepSeekClient = _deepSeekClient;
        if (_narrativeCompressor != null) _session!.narrativeCompressor = _narrativeCompressor;
        _worldEngine = WorldEngine(script: _session!.script!, client: _deepSeekClient!);
        _worldEngine!.initFromScript();
      }
    } else { _deepSeekClient = null; _worldEngine = null; }
    notifyListeners();
  }

  void _isLoading(bool v) { if (_session != null) _session!.setIsLoading(v); notifyListeners(); }

  // ═══════════════════════════════════════════════
  //  Gameplay delegation (→ GameSession)
  // ═══════════════════════════════════════════════

  Future<void> advance(String mode) async {
    await _session?.advance(mode,
      userName: _userSettings.name, userGender: _userSettings.gender, userHeight: _userSettings.height,
      userBirthday: _userSettings.birthday, userAppearance: _userSettings.appearance,
      userPersonality: _userSettings.personality, userBio: _userSettings.bio,
      charRemarkNames: _charDisplay.remarkNames,
    );
    autoSave();
  }

  Future<void> customAction(String action) async {
    await _session?.customAction(action,
      userName: _userSettings.name, userGender: _userSettings.gender, userHeight: _userSettings.height,
      userBirthday: _userSettings.birthday, userAppearance: _userSettings.appearance,
      userPersonality: _userSettings.personality, userBio: _userSettings.bio,
    );
    autoSave();
  }

  Future<void> pickChoice(int index) async {
    await _session?.pickChoice(index,
      userName: _userSettings.name, userGender: _userSettings.gender, userHeight: _userSettings.height,
      userBirthday: _userSettings.birthday, userAppearance: _userSettings.appearance,
      userPersonality: _userSettings.personality, userBio: _userSettings.bio,
    );
    autoSave();
  }

  void sendMessage(String charId, String message) {
    _session?.sendMessage(charId, message,
      userName: _userSettings.name, userDisplayName: _userSettings.name,
      charRemarkNames: _charDisplay.remarkNames,
    );
  }

  void sendGift(String charId, ShopItem item) {
    _session?.sendGift(charId, item, userName: _userSettings.name, charRemarkNames: _charDisplay.remarkNames);
  }

  Future<Map<String, dynamic>> triggerSceneEvent(String locationId, String charId) async {
    if (_session == null) return {'narrative': '', 'delta': 0.0};
    return await _session!.triggerSceneEvent(locationId, charId,
      userName: _userSettings.name, userGender: _userSettings.gender, userHeight: _userSettings.height,
      userBirthday: _userSettings.birthday, userAppearance: _userSettings.appearance,
      userPersonality: _userSettings.personality, userBio: _userSettings.bio,
    );
  }

  // ═══════════════════════════════════════════════
  //  Tabs
  // ═══════════════════════════════════════════════

  void setTab(int index) { _currentTabIndex = index; notifyListeners(); }
  void setSimTab(int index) { _simTabIndex = index; notifyListeners(); }

  // ═══════════════════════════════════════════════
  //  Getters → GameSession
  // ═══════════════════════════════════════════════

  GameScript? get script => _session?.script;
  DeepSeekClient? get deepSeekClient => _deepSeekClient;
  WorldEngine? get worldEngine => _session?.worldEngine;
  PhaseActionService? get phaseActions => _session != null ? PhaseActionService(_session!) : null;

  /// 预览场景
  Future<Map<String, dynamic>> previewLocation(String id) async {
    final r = await phaseActions?.previewLocation(id);
    notifyListeners(); return r ?? {};
  }

  /// 场景中行动
  Future<void> actAtLocation(String id, String action) async {
    final n = await phaseActions?.actAtLocation(id, action) ?? '';
    if (n.isNotEmpty) _session?.appendNarrative(n);
    notifyListeners();
  }

  /// 与角色互动
  Future<void> interactWithChar(String id, String action) async {
    final n = await phaseActions?.interactWithChar(id, action) ?? '';
    if (n.isNotEmpty) _session?.appendNarrative(n);
    notifyListeners();
  }

  /// 跳过 N 天
  Future<void> skipDays(int days) async {
    final n = await phaseActions?.skipDays(days) ?? '';
    notifyListeners();
  }

  /// 执行训练
  Future<void> doTraining(String id) async {
    await phaseActions?.doTraining(id);
    notifyListeners();
  }

  /// 获取当前可用的训练
  List<Map<String, dynamic>> getAvailableTraining() => phaseActions?.getAvailableTraining() ?? [];

  /// 度过当前时段
  Future<void> passPhase() async {
    final n = await phaseActions?.passPhase() ?? '';
    if (n.isNotEmpty) _session?.appendNarrative(n);
    notifyListeners();
  }

  int get currentTabIndex => _currentTabIndex;
  int get simTabIndex => _simTabIndex;

  String get narrativeHistory => _session?.narrativeHistory ?? '';
  List<String> get narrativeSegments => _session?.narrativeSegments ?? [];
  List<String> get segmentEventTypes => _session?.segmentEventTypes ?? [];
  List<Map<String, dynamic>> get pendingChoices => _session?.pendingChoices ?? [];
  bool get isLoading => _session?.isLoading ?? false;
  String get lastNarrativeSegment => _session?.lastNarrativeSegment ?? '';
  bool get inLongEvent => _session?.inLongEvent ?? false;

  // ═══════════════════════════════════════════════
  //  Getters → UserSettings
  // ═══════════════════════════════════════════════

  String get userName => _userSettings.name;
  String get userGender => _userSettings.gender;
  String get userHeight => _userSettings.height;
  String get userBirthday => _userSettings.birthday;
  String get userBio => _userSettings.bio;
  String get userAppearance => _userSettings.appearance;
  String get userPersonality => _userSettings.personality;
  Uint8List? get userImageBytes => _userSettings.avatarBytes;
  Uint8List? get userBgImageBytes => _userSettings.bgImageBytes;
  String get userAvatarColor => _userSettings.avatarColor;
  bool get isDarkMode => _userSettings.isDarkMode;
  int get fontSizeLevel => _userSettings.fontSizeLevel;
  double get baseFontSize => _userSettings.baseFontSize;
  String get globalBgType => _userSettings.globalBgType;
  String get globalBgColor1 => _userSettings.globalBgColor1;
  String get globalBgColor2 => _userSettings.globalBgColor2;
  String get simBgType => _userSettings.simBgType;
  String get simBgColor1 => _userSettings.simBgColor1;
  String get simBgColor2 => _userSettings.simBgColor2;
  Uint8List? get simBgImageBytes => _userSettings.simBgImageBytes;

  Color get simBgStartColor => _userSettings.simBgStartColor;
  Color get simBgEndColor => _userSettings.simBgEndColor;

  void setUserName(String v) { _userSettings.name = v; notifyListeners(); }
  void setUserGender(String v) { _userSettings.gender = v; notifyListeners(); }
  void setUserHeight(String v) { _userSettings.height = v; notifyListeners(); }
  void setUserBirthday(String v) { _userSettings.birthday = v; notifyListeners(); }
  void setUserBio(String v) { _userSettings.bio = v; notifyListeners(); }
  void setUserAppearance(String v) { _userSettings.appearance = v; notifyListeners(); }
  void setUserPersonality(String v) { _userSettings.personality = v; notifyListeners(); }
  void setUserImageBytes(Uint8List? v) { _userSettings.avatarBytes = v; notifyListeners(); }

  void setDarkMode(bool v) { _userSettings.isDarkMode = v; notifyListeners(); }
  void setFontSizeLevel(int v) { _userSettings.fontSizeLevel = v.clamp(0, 4); notifyListeners(); }

  void setGlobalBgType(String v) { _userSettings.globalBgType = v; notifyListeners(); }
  void setGlobalBgColor1(String v) { _userSettings.globalBgColor1 = v; notifyListeners(); }
  void setGlobalBgColor2(String v) { _userSettings.globalBgColor2 = v; notifyListeners(); }
  void setSimBgType(String v) { _userSettings.simBgType = v; notifyListeners(); }
  void setSimBgColor1(String v) { _userSettings.simBgColor1 = v; notifyListeners(); }
  void setSimBgColor2(String v) { _userSettings.simBgColor2 = v; notifyListeners(); }
  void setSimBgImageBytes(Uint8List? v) { _userSettings.simBgImageBytes = v; notifyListeners(); }

  String get playerCardForAi => _session?.buildPlayerCardForAi(
    _userSettings.name, _userSettings.gender, _userSettings.height,
    _userSettings.birthday, _userSettings.appearance, _userSettings.personality, _userSettings.bio,
  ) ?? '';

  // ═══════════════════════════════════════════════
  //  Getters → CharacterDisplay
  // ═══════════════════════════════════════════════

  String getCharRemarkName(String charId) => _charDisplay.remarkNames[charId] ?? '';
  void setCharRemarkName(String charId, String v) { _charDisplay.remarkNames[charId] = v; notifyListeners(); }

  String getCharDisplayName(String charId) {
    final remark = _charDisplay.remarkNames[charId];
    if (remark != null && remark.isNotEmpty) return remark;
    return _session?.getCharacter(charId)?.basic.name ?? charId;
  }

  Uint8List? getCharImageBytes(String charId) => _charDisplay.imageBytes[charId];
  void setCharImageBytes(String charId, Uint8List? v) { _charDisplay.imageBytes[charId] = v; notifyListeners(); }

  String getCharBioOverride(String charId) => _charDisplay.getBioOverride(charId);
  String getCharSignOverride(String charId) => _charDisplay.getSignOverride(charId);
  void setCharBioOverride(String charId, String bio) { _charDisplay.bioOverrides[charId] = bio; notifyListeners(); }
  void setCharSignOverride(String charId, String sign) { _charDisplay.signOverrides[charId] = sign; notifyListeners(); }

  bool hasUnread(String charId) => _charDisplay.hasUnread(charId);
  int unreadCount(String charId) {
    final msgs = _session?.chatHistories[charId] ?? [];
    if (msgs.isEmpty) return 0;
    int count = 0;
    for (int i = msgs.length - 1; i >= 0; i--) {
      if (msgs[i].senderId == 'player') break;
      count++;
    }
    return _charDisplay.hasUnread(charId) ? count : 0;
  }

  void markCharRead(String charId) { _charDisplay.markRead(charId); notifyListeners(); }
  void notifyCharNewMessage(String charId) { _charDisplay.notifyNewMessage(charId); notifyListeners(); }

  // ═══════════════════════════════════════════════
  //  Getters → GameSession (remaining)
  // ═══════════════════════════════════════════════

  String get currentDay => _session?.currentDay ?? '1';
  String get currentPhase => _session?.currentPhase ?? '上午';
  String get currentWeather => _session?.currentWeather ?? '晴';
  String get currentSeason => _session?.currentSeason ?? '春';
  int get daysSkipped => _session?.daysSkipped ?? 0;
  Map<String, double> get playerStats => _session?.playerStats ?? {};
  Map<String, double> get playerGrades => _session?.playerGrades ?? {};
  Map<String, double> get affectionStates => _session?.affectionStates ?? {};
  Map<String, List<ChatMessage>> get chatHistories => _session?.chatHistories ?? {};
  List<String> get inventoryItemIds => _session?.inventoryItemIds ?? [];
  Map<String, int> get currencies => _session?.currencies ?? {};
  String get currentAct => _session?.currentAct ?? 'act_1';
  double get tensionLevel => _session?.tensionLevel ?? 20.0;
  Map<String, double> get endingProgress => _session?.endingProgress ?? {};
  Map<String, bool> get triggeredBeats => _session?.triggeredBeats ?? {};
  Map<String, String> get pendingInvitation => _session?.pendingInvitation ?? {};
  bool get simActive => _simActive;
  bool get hasScript => _hasScript;
  String get apiKey => _apiKey;

  RelationshipEngine? get relationshipEngine => _session?.relationshipEngine;
  EventScheduler? get eventScheduler => _session?.eventScheduler;
  CharacterMemoryService? get charMemory => _session?.charMemory;
  RankingService? get rankingService => _session?.rankingService;

  String getRelationStateLabel(String charId) => _session?.getRelationStateLabel(charId) ?? '';
  bool isLoverOrPartner(String charId) => _session?.isLoverOrPartner(charId) ?? false;
  List<String> get loverIds => _session?.loverIds ?? [];
  bool hasMultiLovers() => _session?.hasMultiLovers() ?? false;
  String buildRelationContextForPrompt() => _session?.buildRelationContextForPrompt() ?? '';

  Character? getCharacter(String id) => _session?.getCharacter(id);
  double getAffection(String charId) => _session?.getAffection(charId) ?? 0.0;
  List<ChatMessage> getChatHistory(String charId) => _session?.getChatHistory(charId) ?? [];
  bool isPlayerMessageRead(String charId, int idx) => _session?.isPlayerMessageRead(charId, idx) ?? false;
  String getCharLastMessage(String charId) => _session?.getCharLastMessage(charId) ?? '';
  DateTime? getCharLastMessageTime(String charId) => _session?.getCharLastMessageTime(charId);

  AffectionTier? getCurrentTier(String charId) => _session?.getCurrentTier(charId);
  bool affectionNeedsEvent(String charId) => _session?.affectionNeedsEvent(charId) ?? false;

  void modifyAffectionByChat(String charId, double delta) => _session?.modifyAffectionByChat(charId, delta);
  void modifyAffectionByEvent(String charId, double delta) => _session?.modifyAffectionByEvent(charId, delta);

  List<String> getSceneChars(String locationId) => _session?.getSceneChars(locationId) ?? [];
  void refreshSceneChars() => _session?.refreshSceneChars();

  void addItem(String itemId) => _session?.addItem(itemId);
  bool hasItem(String itemId) => _session?.hasItem(itemId) ?? false;

  bool isChatLoading(String charId) => _session?.isChatLoading(charId) ?? false;

  void enterSim() { _simActive = true; notifyListeners(); }
  void exitSim() { _simActive = false; notifyListeners(); }

  void clearInvitation(String charId) => _session?.clearInvitation(charId);
}
