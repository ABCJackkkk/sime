import 'dart:math';
import 'package:sime/models/script.dart';
import 'package:sime/services/deepseek_client.dart';
import 'package:sime/services/world_engine.dart';
import 'package:sime/services/affection_engine.dart';
import 'package:sime/services/relationship_engine.dart';
import 'package:sime/services/event_scheduler.dart';
import 'package:sime/services/narrative_compressor.dart';
import 'package:sime/services/character_memory_service.dart';
import 'package:sime/services/ranking_service.dart';
import 'package:sime/services/save_service.dart';
import 'package:sime/services/narrative_validator.dart';
import 'package:sime/services/action_validator.dart';
import 'package:sime/services/rhythm_scheduler.dart';

class GameSession {
  void Function()? onChanged;
  void Function()? onChatCompleted;

  GameScript? script;
  DeepSeekClient? deepSeekClient;
  WorldEngine? worldEngine;
  AffectionEngine? affectionEngine;
  RelationshipEngine? relationshipEngine;
  EventScheduler? eventScheduler;
  CharacterMemoryService? charMemory;
  RhythmScheduler? rhythmScheduler;
  RankingService? rankingService;
  NarrativeCompressor? _narrativeCompressor;
  final Random _rng = Random();

  String _currentDay = '1';
  String get currentDay => _currentDay;

  String _currentPhase = '上午';
  String get currentPhase => _currentPhase;

  String _currentWeather = '晴';
  String get currentWeather => _currentWeather;

  String _currentSeason = '春';
  String get currentSeason => _currentSeason;

  int _daysSkipped = 0;
  int get daysSkipped => _daysSkipped;

  String _narrativeHistory = '';
  String get narrativeHistory => _narrativeHistory;

  List<String> _narrativeSegments = [];
  List<String> get narrativeSegments => _narrativeSegments;

  List<String> _segmentEventTypes = [];
  List<String> get segmentEventTypes => _segmentEventTypes;

  // 会话级记忆：当前行动会话的所有 segments（进入场景/开始行动时清空，结束时压缩存档）
  // 全局 _narrativeSegments 压缩时，当前会话内的 segments 会被保护，不丢失
  List<String> _currentSessionSegments = [];
  int _currentSessionStartIndex = 0; // 当前会话在 _narrativeSegments 中的起点
  bool get hasActiveSession => _currentSessionSegments.isNotEmpty;

  List<Map<String, dynamic>> _pendingChoices = [];
  List<Map<String, dynamic>> get pendingChoices => _pendingChoices;

  int _longEventStepsRemaining = 0;
  bool _inLongEvent = false;
  String _lastNarrativeSegment = '';
  String _lastEventType = 'daily';
  bool _isLoading = false;

  set isLoading(bool v) { _isLoading = v; }
  bool get isLoading => _isLoading;
  bool get inLongEvent => _inLongEvent;
  String get lastNarrativeSegment => _lastNarrativeSegment;

  Map<String, dynamic> get tensionVectorData => rhythmScheduler?.tension.toJson() ?? {};
  void restoreTension(Map<String, dynamic> d) {
    if (rhythmScheduler != null && d.isNotEmpty) {
      rhythmScheduler!.tension.loadFromJson(d);
      _tensionLevel = rhythmScheduler!.tension.composite;
      _syncTensionToScript();
    }
  }

  void appendNarrative(String text) {
    _appendToNarrative(text);
    _narrativeSegments.add(text);
    _segmentEventTypes.add('phase');
    _lastNarrativeSegment = text;
  }

  Map<String, double> _playerStats = {};
  Map<String, double> get playerStats => _playerStats;

  Map<String, double> _playerGrades = {};
  Map<String, double> get playerGrades => _playerGrades;

  Map<String, double> _affectionStates = {};
  Map<String, double> get affectionStates => Map.unmodifiable(_affectionStates);
  final Set<String> discoveredChars = {};

  Map<String, List<ChatMessage>> _chatHistories = {};
  Map<String, List<ChatMessage>> get chatHistories => _chatHistories;

  Map<String, List<String>> _sceneChars = {};
  List<String> getSceneChars(String locationId) => _sceneChars[locationId] ?? [];

  Map<String, int> _lastInteractionDay = {};
  Map<String, int> get lastInteractionDays => Map.unmodifiable(_lastInteractionDay);

  final Set<String> _loadingChatIds = {};
  bool isChatLoading(String charId) => _loadingChatIds.contains(charId);

  String _currentAct = 'act_1';
  String get currentAct => _currentAct;

  String _currentLocation = '';

  Map<String, bool> _triggeredBeats = {};
  Map<String, bool> get triggeredBeats => _triggeredBeats;

  Map<String, double> _endingProgress = {};
  Map<String, double> get endingProgress => _endingProgress;

  double _tensionLevel = 20.0;
  double get tensionLevel => _tensionLevel;

  List<Map<String, dynamic>> _activeForeshadow = [];

  int _eventCounter = 0;
  int get eventCounter => _eventCounter;

  List<Map<String, dynamic>> _recentEvents = [];
  List<Map<String, dynamic>> get recentEvents => _recentEvents;

  List<Map<String, dynamic>> _butterflySeeds = [];

  Map<String, DateTime?> _initiativeCooldowns = {};
  Map<String, String> _pendingInvitation = {};
  Map<String, String> get pendingInvitation => _pendingInvitation;

  // AI标记法场景切换：检测到[SCENE_SHIFT: id]后存入，前端读取并弹窗确认
  String _pendingSceneShiftId = '';
  String _pendingSceneShiftName = '';
  String get pendingSceneShiftId => _pendingSceneShiftId;
  String get pendingSceneShiftName => _pendingSceneShiftName;
  bool get hasPendingSceneShift => _pendingSceneShiftId.isNotEmpty;
  void clearPendingSceneShift() { _pendingSceneShiftId = ''; _pendingSceneShiftName = ''; _notify(); }

  /// 从AI叙事中检测[SCENE_SHIFT: location_id]标记
  /// 返回移除标记后的干净叙事文本
  String _extractSceneShift(String narrative) {
    final match = RegExp(r'\[SCENE_SHIFT:\s*([a-zA-Z0-9_\-]+)\]').firstMatch(narrative);
    if (match == null) return narrative;

    final locId = match.group(1)!;
    // 验证location_id是否存在
    final scenes = script?.events?.sceneLocations ?? [];
    final loc = scenes.where((s) => s.id == locId).firstOrNull;
    if (loc == null) return narrative.replaceAll(match.group(0)!, '').trim();

    _pendingSceneShiftId = locId;
    _pendingSceneShiftName = loc.name;
    return narrative.replaceAll(match.group(0)!, '').trim();
  }

  double getAffection(String charId) => _affectionStates[charId] ?? 0.0;

  Character? getCharacter(String id) {
    if (script == null) return null;
    try { return script!.characters.firstWhere((c) => c.basic.id == id); } catch (_) { return null; }
  }

  AffectionTier? getCurrentTier(String charId) {
    try { return affectionEngine?.getCurrentTier(charId); } catch (_) { return null; }
  }

  bool affectionNeedsEvent(String charId) {
    try { return affectionEngine?.needsBreakthrough(charId) ?? false; } catch (_) { return false; }
  }

  String getRelationStateLabel(String charId) => relationshipEngine?.getState(charId)?.label ?? '';
  bool isLoverOrPartner(String charId) => relationshipEngine?.isLoverOrPartner(charId) ?? false;
  List<String> get loverIds => relationshipEngine?.loverIds ?? [];
  bool hasMultiLovers() => relationshipEngine?.hasMultiLovers() ?? false;
  String buildRelationContextForPrompt() => relationshipEngine?.buildRelationContextForPrompt() ?? '';

  List<ChatMessage> getChatHistory(String charId) => _chatHistories[charId] ?? [];

  String getCharLastMessage(String charId) {
    final msgs = _chatHistories[charId];
    if (msgs == null || msgs.isEmpty) return '';
    for (int i = msgs.length - 1; i >= 0; i--) {
      if (msgs[i].senderId != 'player') return msgs[i].content;
    }
    return '';
  }

  DateTime? getCharLastMessageTime(String charId) {
    final msgs = _chatHistories[charId];
    if (msgs == null || msgs.isEmpty) return null;
    return msgs.last.timestamp;
  }

  bool isPlayerMessageRead(String charId, int msgIndex) {
    final msgs = _chatHistories[charId] ?? [];
    if (msgIndex >= msgs.length - 1) return false;
    if (msgs[msgIndex].senderId != 'player') return false;
    for (int i = msgIndex + 1; i < msgs.length; i++) {
      if (msgs[i].senderId != 'player') return true;
    }
    return false;
  }

  void _appendToNarrative(String text) {
    _narrativeHistory += _cleanNarrative(text);
    _narrativeHistory = _narrativeHistory.trim();
    if (_narrativeCompressor != null && _narrativeCompressor!.needsCompression(_narrativeHistory)) {
      // 只压缩会话起点之前的 segments，保护当前会话内的所有叙事
      final sessStart = _currentSessionStartIndex.clamp(0, _narrativeSegments.length);
      if (sessStart > 0) {
        final beforeSession = _narrativeSegments.sublist(0, sessStart);
        final sessionPart = _narrativeSegments.sublist(sessStart);
        final beforeTypes = _segmentEventTypes.sublist(0, sessStart);
        final sessionTypes = _segmentEventTypes.sublist(sessStart);
        final result = _narrativeCompressor!.compressSegments(beforeSession);
        _narrativeSegments = [...result.segments, ...sessionPart];
        final hasPrefix = result.segments.isNotEmpty && result.segments.first.startsWith('[前略');
        final newBeforeTypes = hasPrefix ? <String>['', ...beforeTypes.sublist(result.replacedCount)] : beforeTypes.sublist(result.replacedCount);
        _segmentEventTypes = [...newBeforeTypes, ...sessionTypes];
        _currentSessionStartIndex = result.segments.length; // 会话起点前移
      }
      // 重算 _narrativeHistory（只重算，不再触发递归压缩）
      _narrativeHistory = _narrativeSegments.join('\n\n');
      if (_narrativeHistory.length > 20000) {
        // 极端情况：单次会话超大，只保留会话内最近的部分
        final sessionPart = _narrativeSegments.sublist(_currentSessionStartIndex.clamp(0, _narrativeSegments.length));
        _narrativeHistory = sessionPart.join('\n\n');
      }
      onChanged?.call();
    }
  }

  void _notify() => onChanged?.call();

  String _cleanNarrative(String s) {
    return s.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]'), '');
  }

  // ─── Init ───

  void initFromScript({required String? userName}) {
    final s = script;
    if (s == null) return;
    _currentDay = s.world.memory.currentTime.day.toString();
    _currentSeason = _seasonName(s.world.memory.currentTime.season);
    _currentWeather = s.world.memory.currentTime.weather;
    _currentPhase = s.world.memory.currentTime.phase;
    affectionEngine = AffectionEngine(script: s, affectionConfig: s.gameInteraction?.affection);
    relationshipEngine = RelationshipEngine(affectionEngine!);
    eventScheduler = EventScheduler();
    _initDataLayer();
    _initRankingService();
    for (final char in s.characters.where((c) => c.fullCharacter)) {
      _affectionStates[char.basic.id] = char.initialAffection;
      affectionEngine!.init(char.basic.id, char.initialAffection);
      relationshipEngine!.init(char.basic.id, char.initialAffection);
    }
    if (deepSeekClient != null) {
      worldEngine = WorldEngine(script: s, client: deepSeekClient!);
      worldEngine!.initFromScript();
      worldEngine!.initWorldServices();
    }
    charMemory = CharacterMemoryService();
    rhythmScheduler = RhythmScheduler();
    discoveredChars.addAll(s.characters.where((c) => c.fullCharacter).map((c) => c.basic.id));
    _narrativeHistory = s.world.memory.worldSummary;
    _narrativeSegments = _narrativeHistory.isNotEmpty ? [_narrativeHistory] : [];
    _segmentEventTypes = _narrativeSegments.map((_) => '').toList();
    _pendingChoices = [];
    _lastNarrativeSegment = _narrativeHistory;
    refreshSceneChars();

    final plotMemory = s.plot?.memory;
    if (plotMemory != null) {
      _currentAct = plotMemory.currentAct.isNotEmpty ? plotMemory.currentAct : 'act_1';
      for (final beatId in plotMemory.triggeredBeats) {
        _triggeredBeats[beatId] = true;
      }
      _endingProgress = Map<String, double>.from(plotMemory.endingProgress);
      _activeForeshadow = List<Map<String, dynamic>>.from(plotMemory.activeForeshadow);
    }
    _tensionLevel = s.plot?.narrativeTension.actualLevel ?? 20.0;

    final eventMemory = s.gameEvents?.memory;
    if (eventMemory != null) {
      _eventCounter = eventMemory.eventCounter;
      _recentEvents = List<Map<String, dynamic>>.from(eventMemory.recentEvents);
    }
  }

  void refreshSceneChars() {
    if (script == null) return;
    _sceneChars.clear();
    final chars = script!.characters.where((c) => c.fullCharacter).toList();
    if (chars.isEmpty) return;
    final locations = script!.events?.sceneLocations ?? [];
    if (locations.isEmpty) return;
    for (final loc in locations) {
      final avail = chars.where((c) {
        final aff = getAffection(c.basic.id);
        return aff > 50;
      }).toList();
      if (avail.isEmpty) { _sceneChars[loc.id] = []; continue; }
      avail.shuffle();
      _sceneChars[loc.id] = avail.take(avail.length.clamp(0, 3)).map((c) => c.basic.id).toList();
    }
  }

  String _seasonName(String s) {
    switch (s) { case 'spring': return '春'; case 'summer': return '夏'; case 'autumn': return '秋'; case 'winter': return '冬'; default: return '春'; }
  }

  // ─── Data layer ───

  void _initDataLayer() {
    final dl = script?.dataLayer;
    if (dl == null) return;
    _playerStats = {};
    for (final s in dl.stats) { _playerStats[s.id] = s.initial; }
    _playerGrades = {};
    for (final g in dl.grades) { _playerGrades[g.id] = g.initial; }
  }

  void _initRankingService() {
    final dl = script?.dataLayer;
    if (dl == null) return;
    rankingService = RankingService();
    for (final char in script!.characters.where((c) => c.fullCharacter)) {
      if (char.stats != null && char.stats!.isNotEmpty && char.grades != null && char.grades!.isNotEmpty) {
        rankingService!.initCharacter(char.basic.id, char.stats!, char.grades!);
      } else {
        rankingService!.initCharacter(char.basic.id, _uniformStats(dl.stats, char.basic.id), _uniformGrades(dl.grades, char.basic.id));
      }
    }
  }

  List<CharacterStat> _uniformStats(List<PlayerStatDefinition> statDefs, String charId) {
    final rng = Random(charId.hashCode);
    return statDefs.map((s) {
      final base = s.initial + (s.max - s.initial) * 0.3 * rng.nextDouble() - (s.max - s.initial) * 0.15;
      return CharacterStat(id: s.id, name: s.name, value: base.clamp(s.min, s.max), max: s.max);
    }).toList();
  }

  List<CharacterGrade> _uniformGrades(List<PlayerGradeDefinition> gradeDefs, String charId) {
    final rng = Random(charId.hashCode * 97);
    return gradeDefs.map((g) {
      final base = g.initial + g.initial * 0.35 * rng.nextDouble() - g.initial * 0.25;
      return CharacterGrade(id: g.id, name: g.name, value: base.clamp(g.min, g.max), max: g.max);
    }).toList();
  }

  RankRecord? _checkAndProcessExam(int day) {
    final dl = script?.dataLayer;
    if (dl == null || rankingService == null) return null;
    if (!rankingService!.shouldTriggerExam(day, dl.ranking, dl.memory)) return null;

    String examName = '';
    for (final evt in dl.ranking.events) {
      if (day % evt.intervalDays == 0 || (day - 1) % evt.intervalDays == 0) { examName = evt.name; break; }
    }
    if (examName.isEmpty) examName = '考试';

    final result = rankingService!.processExam(day, examName, dl.ranking, dl.stats, dl.grades, _playerStats, _playerGrades, script!.characters, _affectionStates, gradeFormulas: dl.gradeFormulas, naturalGrowthRate: dl.naturalGrowthRate);
    dl.memory.lastRankingDay = day;
    dl.memory.gradeValues.clear();
    dl.memory.gradeValues.addAll(_playerGrades);
    dl.memory.statValues.clear();
    dl.memory.statValues.addAll(_playerStats);
    dl.memory.gradeHistory.add({'day': day, 'name': examName, 'grades': Map.from(_playerGrades), 'rank': result.playerRank});
    return result;
  }

  // ─── Player card for AI ───

  String buildPlayerCardForAi(String userName, String userGender, String userHeight, String userBirthday, String userAppearance, String userPersonality, String userBio) {
    final buf = StringBuffer();
    buf.writeln('【玩家角色卡】');
    buf.writeln('名字: $userName');
    if (userGender.isNotEmpty) buf.writeln('性别: $userGender');
    if (userHeight.isNotEmpty) buf.writeln('身高: $userHeight');
    if (userBirthday.isNotEmpty) buf.writeln('生日: $userBirthday');
    if (userAppearance.isNotEmpty) buf.writeln('外貌: $userAppearance');
    if (userPersonality.isNotEmpty) buf.writeln('性格: $userPersonality');
    if (userBio.isNotEmpty) buf.writeln('简介: $userBio');
    buf.writeln();
    final s = script;
    if (s != null) {
      final bg = s.player.background;
      if (bg.isNotEmpty) { buf.writeln('【背景经历】（剧本设定）'); buf.writeln(bg); buf.writeln(); }
      final cs = s.player.currentState;
      if (cs.isNotEmpty) { buf.writeln('【当前处境】'); buf.writeln(cs); buf.writeln(); }
    }
    final rc = relationshipEngine?.buildRelationContextForPrompt() ?? '';
    if (rc.isNotEmpty) buf.writeln(rc);
    final dl = script?.dataLayer;
    if (dl != null && _playerStats.isNotEmpty) {
      buf.writeln('【主角属性】');
      for (final st in dl.stats) {
        final v = _playerStats[st.id] ?? st.initial;
        buf.writeln('${st.name}: ${v.toStringAsFixed(0)}');
      }
      buf.writeln();
    }
    if (dl != null && _playerGrades.isNotEmpty) {
      buf.writeln('【主角成绩】');
      for (final g in dl.grades) {
        final v = _playerGrades[g.id] ?? g.initial;
        buf.writeln('${g.name}: ${v.toStringAsFixed(0)}');
      }
      buf.writeln();
    }
    return buf.toString();
  }

  // ─── Affection ───

  void modifyAffectionByChat(String charId, double delta) {
    if (affectionEngine != null) {
      _affectionStates[charId] = affectionEngine!.modifyAffectionByChat(charId, delta);
    } else {
      _affectionStates[charId] = (_affectionStates[charId] ?? 50.0) + delta;
      _affectionStates[charId] = _affectionStates[charId]!.clamp(0.0, 100.0);
    }
    relationshipEngine?.syncFromAffection(charId);
    _notify();
  }

  void modifyAffectionByEvent(String charId, double delta) {
    if (affectionEngine != null) {
      _affectionStates[charId] = affectionEngine!.modifyAffectionByEvent(charId, delta);
    } else {
      _affectionStates[charId] = (_affectionStates[charId] ?? 50.0) + delta;
      _affectionStates[charId] = _affectionStates[charId]!.clamp(0.0, 100.0);
    }
    relationshipEngine?.syncFromAffection(charId);
    _notify();
  }

  void _recordInteraction(String charId) {
    final day = int.tryParse(_currentDay) ?? 1;
    _lastInteractionDay[charId] = day;
  }

  void _recordInteractions(Iterable<String> charIds) {
    for (final id in charIds) {
      _recordInteraction(id);
    }
  }

  void _applyAffectionDecay(String charId, double delta) {
    if (affectionEngine != null) {
      _affectionStates[charId] = affectionEngine!.modifyAffectionByEvent(charId, delta);
    } else {
      _affectionStates[charId] = (_affectionStates[charId] ?? 50.0) + delta;
      _affectionStates[charId] = _affectionStates[charId]!.clamp(0.0, 100.0);
    }
    relationshipEngine?.syncFromAffection(charId);
  }

  List<String> _buildCoolingHints(int currentDay) {
    final hints = <String>[];
    if (script == null) return hints;
    bool changed = false;
    for (final char in script!.characters.where((c) => c.fullCharacter)) {
      final id = char.basic.id;
      final lastDay = _lastInteractionDay[id] ?? 0;
      final gap = currentDay - lastDay;
      final affection = _affectionStates[id] ?? 0;
      if (affection < 1) continue;

      if (gap >= 12) {
        _applyAffectionDecay(id, -0.5);
        changed = true;
        hints.add('${char.basic.name}已经太久没有出现在你的视线里了。你们之间隔了$gap天。');
      } else if (gap >= 6) {
        _applyAffectionDecay(id, -0.3);
        changed = true;
        hints.add('你有$gap天没见过${char.basic.name}了。');
      }
    }
    if (changed) _notify();
    return hints;
  }

  List<String> _buildMissedConnectionHints(WorldTickReport tickReport) {
    final hints = <String>[];
    if (script == null) return hints;
    final locations = worldEngine?.getCharacterLocations() ?? {};
    final charMap = Map.fromEntries(script!.characters.where((c) => c.fullCharacter).map((c) => MapEntry(c.basic.id, c)));
    final sceneLocs = script!.events?.sceneLocations ?? [];
    final locNameMap = Map.fromEntries(sceneLocs.map((l) => MapEntry(l.id, l.name)));

    for (final entry in locations.entries) {
      final charId = entry.key;
      final locId = entry.value;
      if (locId.isEmpty) continue;
      final affection = _affectionStates[charId] ?? 0;
      if (affection < 20) continue;

      final lastDay = _lastInteractionDay[charId] ?? 0;
      final gap = (int.tryParse(_currentDay) ?? 1) - lastDay;
      if (gap <= 3) continue;

      for (final coll in tickReport.collisions) {
        if (coll.locationId == locId && !coll.charIds.contains(charId)) {
          final locName = locNameMap[locId] ?? locId;
          hints.add('${charMap[charId]?.basic.name ?? charId}也在$locName，但你的注意力在别处。');
          break;
        }
      }
    }
    return hints;
  }

  Map<String, double> _parseCustomActionAffection(String narrative) {
    final result = <String, double>{};
    final re = RegExp(r'\[affection:(\w+):([+\-][\d.]+)\]');
    for (final m in re.allMatches(narrative)) {
      result[m.group(1)!] = double.tryParse(m.group(2)!) ?? 0;
    }
    return result;
  }

  NarrativeCompressor? get narrativeCompressor => _narrativeCompressor;
  set narrativeCompressor(NarrativeCompressor? v) => _narrativeCompressor = v;

  // ─── State setters (for save/load) ───

  void setIsLoading(bool v) => _isLoading = v;
  void setDay(String v) => _currentDay = v;
  void setSeason(String v) => _currentSeason = v;
  void setWeather(String v) => _currentWeather = v;
  void setPhase(String v) => _currentPhase = v;
  void setNarrativeHistory(String v) { _narrativeHistory = v; }
  void setNarrativeSegments(List<String> v) { _narrativeSegments = List.from(v); }
  void setSegmentEventTypes(List<String> v) { _segmentEventTypes = List.from(v); }
  void setAffectionStates(Map<String, double> v) { _affectionStates = Map<String, double>.from(v); }
  void setChatHistories(Map<String, List<ChatMessage>> v) { _chatHistories = Map<String, List<ChatMessage>>.from(v); }
  void setCurrentAct(String v) => _currentAct = v;
  void setTriggeredBeats(Map<String, bool> v) { _triggeredBeats = Map<String, bool>.from(v); }
  void setTensionLevel(double v) => _tensionLevel = v;
  void setEndingProgress(Map<String, double> v) { _endingProgress = Map<String, double>.from(v); }
  void discoverChar(String id) { if (discoveredChars.add(id)) _notify(); }

  bool checkAutoDiscover() {
    bool changed = false;
    final day = int.tryParse(_currentDay) ?? 1;
    for (final c in script?.characters ?? <Character>[]) {
      if (discoveredChars.contains(c.basic.id)) continue;
      final cond = c.discoveryCondition;
      if (cond.isEmpty) continue;
      bool met = false;
      if (cond.startsWith('day:')) {
        final threshold = int.tryParse(cond.substring(4)) ?? 999;
        met = day >= threshold;
      } else if (cond.startsWith('event:')) {
        final eventId = cond.substring(6);
        met = _triggeredBeats[eventId] == true || _triggeredBeats['event:$eventId'] == true || _recentEvents.any((e) => e['event_id'] == eventId);
      } else if (cond.startsWith('affection:')) {
        final threshold = double.tryParse(cond.substring(10)) ?? 999;
        met = getAffection(c.basic.id) >= threshold;
      }
      if (met && discoveredChars.add(c.basic.id)) {
        changed = true;
      }
    }
    if (changed) _notify();
    return changed;
  }
  void setEventCounter(int v) => _eventCounter = v;
  void setRecentEvents(List<Map<String, dynamic>> v) { _recentEvents = List<Map<String, dynamic>>.from(v); }
  void setPlayerStats(Map<String, double> v) { _playerStats = Map<String, double>.from(v); }
  void setPlayerGrades(Map<String, double> v) { _playerGrades = Map<String, double>.from(v); }

  // ─── Core gameplay ───

  Future<void> advance(String mode, {required String userName, required String userGender, required String userHeight, required String userBirthday, required String userAppearance, required String userPersonality, required String userBio, required Map<String, String> charRemarkNames}) async {
    if (_isLoading || worldEngine == null) return;
    _isLoading = true; _pendingChoices = []; _notify();

    _rhythmTick();
    if (script?.plot != null) _checkBeatTriggers();
    _checkCharacterInitiative(userName, charRemarkNames);

    try {
      worldEngine!.setNarrativeHistory(_narrativeHistory);

      final day = int.tryParse(_currentDay) ?? 1;
      eventScheduler?.onAdvance(day);

      final advanceConfig = worldEngine!.getAdvanceModeConfig(mode);
      final eventPool = advanceConfig?.eventsPool ?? [];
      EventTemplate? eventTemplate;
      if (eventPool.isNotEmpty && eventScheduler != null && script?.gameEvents != null) {
        final chaos = (script!.gameEvents!.tensionField['chaos'] as double?) ?? 0.3;
        eventTemplate = eventScheduler!.selectEvent(
          poolNames: eventPool, events: script!.gameEvents!,
          affection: affectionEngine!, relationship: relationshipEngine,
          chaosFactor: chaos, currentDay: day,
        );
      }

      final timeResult = worldEngine!.advanceTime(mode);

      final worldTick = worldEngine!.tickWorld(playerAffections: _affectionStates);
      final collisionLines = worldEngine!.buildCollisionInfo(worldTick);
      final infoGapLines = worldEngine!.buildInfoKnowledgeLines(worldTick);
      final coolingHints = _buildCoolingHints(day);
      final missedHints = _buildMissedConnectionHints(worldTick);

      final worldDynamics = <String>[];
      if (collisionLines.isNotEmpty) worldDynamics.addAll(collisionLines);
      if (infoGapLines.isNotEmpty) worldDynamics.addAll(infoGapLines);
      if (coolingHints.isNotEmpty) worldDynamics.addAll(coolingHints);
      if (missedHints.isNotEmpty) worldDynamics.addAll(missedHints);

      final isQuietDay = eventTemplate == null && worldDynamics.isEmpty;

      String narrative;
      List<String>? participants;
      if (eventTemplate != null) {
        eventScheduler?.recordEvent(eventTemplate);

        final allCharIds = script!.characters.where((c) => c.fullCharacter).map((c) => c.basic.id).toList();

        participants = eventScheduler!.pickParticipants(
          event: eventTemplate, allCharIds: allCharIds,
          affection: affectionEngine!, relationship: relationshipEngine,
        );

        if (participants.isNotEmpty) {
          worldEngine!.interCharRel.onPlayerEvent(participants, _affectionStates, '共同参与事件: ${eventTemplate.name}');
        }

        _eventCounter++;
        _recentEvents.add({'event_id': eventTemplate.id, 'name': eventTemplate.name, 'day': _currentDay, 'severity': eventTemplate.severity});
        _tickTensionAfterEvent(eventTemplate.severity);
        _advanceButterfly();
        if (eventTemplate.duration == 'long') {
          _longEventStepsRemaining = eventTemplate.maxSteps < 1 ? 1 : (eventTemplate.maxSteps > 5 ? 5 : eventTemplate.maxSteps);
          _inLongEvent = true;
        } else {
          _longEventStepsRemaining = 2;
          _inLongEvent = true;
        }
      }

      // ── 节奏层 + 生成层：RhythmDirective → generateWorldNarrative（每次推进都运行）──
      final playerCard = buildPlayerCardForAi(userName, userGender, userHeight, userBirthday, userAppearance, userPersonality, userBio);

      if (rhythmScheduler != null) {
        final directive = rhythmScheduler!.resolve(
          mode: mode,
          currentDay: day,
          totalDays: script!.interaction.totalDays,
          worldReport: worldTick,
          affection: affectionEngine!,
          allCharIds: script!.characters.where((c) => c.fullCharacter).map((c) => c.basic.id).toList(),
          nearMilestone: false,
          milestoneDay: null,
          milestoneName: null,
          script: script!,
          currentPhase: _currentPhase,
          currentWeather: _currentWeather,
        );
        final allParticipantIds = {...?participants, ...directive.participantIds}.toList();
        participants = allParticipantIds;
        final participantStr = StringBuffer();
        for (final pid in allParticipantIds) {
          final char = getCharacter(pid);
          if (char != null) {
            participantStr.writeln('${char.basic.name}(${pid}): 好感${getAffection(pid).toStringAsFixed(1)} ${relationshipEngine?.getRelationshipType(pid) ?? ""}');
          }
        }
        final charProfiles = worldDynamics.isNotEmpty
            ? script!.characters.where((c) => c.fullCharacter).map((c) => deepSeekClient!.buildCharProfile(c)).toList()
            : <String>[];
        final rankingCtx = worldDynamics.isNotEmpty ? (rankingService?.buildRankingContext(day) ?? '') : '';
        final tensionCtx = rhythmScheduler!.tension.snapshot();
        final thisLocation = _currentSceneLocationName(participants, worldTick);
        final freqHooks = worldEngine!.buildFrequencyHooks('player', thisLocation);
        worldEngine!.recordPlayerLocation(thisLocation);
        _currentLocation = thisLocation;
        narrative = await deepSeekClient!.generateWorldNarrative(
          mode: mode,
          directive: directive,
          currentDay: day,
          totalDays: script!.interaction.totalDays,
          season: _currentSeason,
          weather: _currentWeather,
          phase: _currentPhase,
          fullNarrativeHistory: _narrativeHistory,
          playerCard: playerCard,
          rankingContext: rankingCtx,
          charProfiles: charProfiles,
          worldDynamicsLines: worldDynamics,
          frequencyHooks: freqHooks,
          locationName: _currentSceneLocationName(participants, worldTick),
          locationDesc: '',
          participantDetails: participantStr.toString(),
          focus: directive.primaryFocus.toString().split('.').last,
          tensionSnapshot: tensionCtx,
          charMemory: charMemory,
          isQuietDay: isQuietDay,
        );
      } else {
        narrative = '[世界引擎推进中...]';
      }

      _appendToNarrative('\n\n$narrative');
      _narrativeSegments.add(narrative);
      _segmentEventTypes.add(eventTemplate?.severity ?? 'daily');
      _lastEventType = eventTemplate?.severity ?? 'daily';
      _lastNarrativeSegment = narrative;
      _currentDay = timeResult.dayAfter.toString();
      _currentPhase = worldEngine!.currentPhase;
      _currentWeather = worldEngine!.currentWeather;
      _currentSeason = worldEngine!.currentSeason;
      _daysSkipped = timeResult.daysSkipped;

      final int dayNum = timeResult.dayAfter;
      if (participants != null && participants.isNotEmpty) {
        final eventName = eventTemplate?.name ?? '日常事件';
        for (final pid in participants) {
          charMemory?.recordEvent(pid, dayNum, eventName, getAffection(pid));
          discoverChar(pid);
        }
      }
      _recordInteractions(participants ?? []);
    } catch (e) {
      final fallbackChar = script!.characters.firstWhere((c) => c.fullCharacter, orElse: () => script!.characters.first);
      final err = NarrativeValidator.fallbackNarrative('daily', script!.fallbackNarratives, {
        'char_name': fallbackChar.basic.name,
        'location': '这里',
        'weather': _currentWeather,
        'phase': _currentPhase,
        'season': _currentSeason,
      });
      _appendToNarrative('\n\n$err');
      _narrativeSegments.add(err);
      _segmentEventTypes.add(_lastEventType);
      _lastNarrativeSegment = err;
    } finally {
      _isLoading = false; _notify();
    }
    final dayNum = int.tryParse(_currentDay) ?? 0;
    if (dayNum > 0) _checkAndProcessExam(dayNum);
    _generateChoices();
    _checkInvitation();
    checkAutoDiscover();
    await _checkCharInitiativeMessages(userName, charRemarkNames);
  }

  Future<void> customAction(String action, {required String userName, required String userGender, required String userHeight, required String userBirthday, required String userAppearance, required String userPersonality, required String userBio}) async {
    if (_isLoading || deepSeekClient == null || script == null) return;
    if (_inLongEvent && _longEventStepsRemaining > 0) {
      _longEventStepsRemaining--;
      if (_longEventStepsRemaining == 0) _inLongEvent = false;
    }
    _isLoading = true; _pendingChoices = []; _notify();

    final validator = ActionValidator(
      rules: script!.actionRules,
      affectionStates: _affectionStates,
      characters: script!.characters,
    );
    final validation = validator.validate(action);
    if (!validation.valid) {
      final rejection = validation.rejectionNarrative ?? '角色没有回应你的行动。';
      _appendToNarrative('\n\n$rejection');
      _narrativeSegments.add(rejection);
      _segmentEventTypes.add('boundary');
      _lastNarrativeSegment = rejection;
      if (validation.targetCharId != null && validation.affectionPenalty != 0) {
        modifyAffectionByEvent(validation.targetCharId!, validation.affectionPenalty);
      }
      _isLoading = false; _notify();
      _generateChoices();
      return;
    }

    String narrative;
    try {
      final playerCard = buildPlayerCardForAi(userName, userGender, userHeight, userBirthday, userAppearance, userPersonality, userBio);
      narrative = await deepSeekClient!.generateCustomActionConsequence(
        action: action, script: script!,
        narrativeHistory: _narrativeHistory, playerCard: playerCard,
        timeContext: worldEngine?.getTimeContext() ?? {},
        characters: script!.characters, affectionStates: _affectionStates,
        charMemory: charMemory,
      );
      if (!NarrativeValidator.isValidNarrative(narrative)) {
        try {
          narrative = await deepSeekClient!.generateCustomActionConsequence(
            action: action, script: script!,
            narrativeHistory: _narrativeHistory, playerCard: playerCard,
            timeContext: worldEngine?.getTimeContext() ?? {},
            characters: script!.characters, affectionStates: _affectionStates,
            charMemory: charMemory,
          );
        } catch (_) {}
        if (!NarrativeValidator.isValidNarrative(narrative)) {
          narrative = NarrativeValidator.fallbackNarrative('custom_action', script!.fallbackNarratives, {
            'char_name': script!.characters.firstWhere((c) => c.fullCharacter, orElse: () => script!.characters.first).basic.name,
            'location': '这里',
            'weather': _currentWeather,
            'phase': _currentPhase,
            'season': _currentSeason,
          });
        }
      }
    } catch (e) {
      narrative = NarrativeValidator.fallbackNarrative('custom_action', script!.fallbackNarratives, {
        'char_name': script!.characters.firstWhere((c) => c.fullCharacter, orElse: () => script!.characters.first).basic.name,
        'location': '这里',
        'weather': _currentWeather,
        'phase': _currentPhase,
        'season': _currentSeason,
      });
    }
    narrative = _extractSceneShift(narrative);
    _appendToNarrative('\n\n$narrative');
    _narrativeSegments.add(narrative);
    _segmentEventTypes.add('custom_action');
    _lastNarrativeSegment = narrative;
    final affectionDeltas = _parseCustomActionAffection(narrative);
    for (final e in affectionDeltas.entries) {
      modifyAffectionByEvent(e.key, e.value);
    }
    _recordInteractions(affectionDeltas.keys);
    if (validation.targetCharId != null && validation.targetCharId!.isNotEmpty) {
      _recordInteraction(validation.targetCharId!);
    }
    _isLoading = false; _notify();
    _generateChoices();
  }

  Future<void> pickChoice(int index, {required String userName, required String userGender, required String userHeight, required String userBirthday, required String userAppearance, required String userPersonality, required String userBio}) async {
    if (_isLoading || index < 0 || index >= _pendingChoices.length) return;
    final choice = _pendingChoices[index];
    final text = choice['text'] as String;
    final delta = (choice['delta'] as num?)?.toDouble() ?? 0.0;
    final target = choice['target'] as String?;
    _pendingChoices = [];
    _isLoading = true; _notify();
    try {
      var narrative = await deepSeekClient!.generateChoiceResponse(
        choice: text, script: script!,
        narrativeHistory: _narrativeHistory,
        timeContext: worldEngine?.getTimeContext() ?? {},
        isContinuation: _inLongEvent && _longEventStepsRemaining > 0,
        charMemory: charMemory,
        targetCharId: target ?? '',
        affectionStates: _affectionStates,
      );
      narrative = _extractSceneShift(narrative);
      _appendToNarrative('\n\n你选择了：$text\n\n$narrative');
      _narrativeSegments.add('你选择了：$text\n\n$narrative');
      _segmentEventTypes.add('choice');
      _lastNarrativeSegment = narrative;
      if (target != null && target.isNotEmpty) {
        modifyAffectionByEvent(target, delta);
        charMemory?.recordCore(target, int.tryParse(_currentDay) ?? 0, text, affection: getAffection(target));
        _recordInteraction(target);
      } else {
        for (final char in script!.characters.where((c) => c.fullCharacter)) {
          modifyAffectionByEvent(char.basic.id, delta * 0.5);
        }
      }
      if (_inLongEvent && _longEventStepsRemaining > 0) {
        _longEventStepsRemaining--;
        if (_longEventStepsRemaining > 0) { _generateChoices(); } else { _inLongEvent = false; }
      }
    } catch (e) {
      final err = '[行动失败: ${e.toString().length > 50 ? e.toString().substring(0, 50) : e.toString()}]';
      _appendToNarrative('\n\n$err');
      _narrativeSegments.add(err);
      _inLongEvent = false; _longEventStepsRemaining = 0;
    }
    _isLoading = false; _notify();
  }

  Future<void> _generateChoices() async {
    if (deepSeekClient == null || script == null || _narrativeHistory.isEmpty) return;
    try {
      _pendingChoices = await deepSeekClient!.generateChoices(
        script: script!,
        narrativeHistory: _narrativeHistory,
        isLongEvent: _inLongEvent,
        affectionStates: _affectionStates,
        currentLocation: _activeSceneLocationName.isNotEmpty ? _activeSceneLocationName : _currentLocation,
        currentPhase: _currentPhase,
        sceneChars: _sceneInteractionChars.isNotEmpty ? _sceneInteractionChars : [],
      );
      _notify();
    } catch (_) {}
  }

  // ─── Chat ───

  void sendMessage(String charId, String message, {required String userName, required String userDisplayName, required Map<String, String> charRemarkNames}) {
    if (isChatLoading(charId)) return;
    final char = getCharacter(charId);
    if (char == null) return;
    final senderName = _resolveDisplayName(charId, char.basic.name, charRemarkNames);
    final playerMsg = ChatMessage(senderId: 'player', senderName: userDisplayName, content: message);
    _chatHistories.putIfAbsent(charId, () => []);
    _chatHistories[charId]!.add(playerMsg);
    _notify();
    _generateAiReply(charId, senderName, char, userName, charRemarkNames);
  }

  Future<void> _generateAiReply(String charId, String senderName, Character char, String userName, Map<String, String> charRemarkNames) async {
    if (deepSeekClient == null) {
      final charMsg = ChatMessage(senderId: charId, senderName: senderName, content: '(AI 未连接，请先在设置中配置 API Key)');
      _chatHistories[charId]!.add(charMsg);
      _notify();
      return;
    }
    ChatMessage? charMsg;
    try {
      _loadingChatIds.add(charId);
      _notify();
      final history = _chatHistories[charId]!;
      // 当前玩家消息是 history 的最后一条（sendMessage 刚加入的）
      final currentPlayerMsg = history.last;
      final currentMessage = currentPlayerMsg.content;
      final chatHistory = <Map<String, String>>[];
      final start = history.length > 30 ? history.length - 30 : 0;
      // chatHistory 不含当前 playerMsg（最后一条），作为历史上下文
      for (int i = start; i < history.length - 1; i++) {
        final msg = history[i];
        chatHistory.add({'role': msg.senderId == 'player' ? 'user' : 'assistant', 'content': msg.content});
      }

      final worldContext = '第${_currentDay}天 ${_currentSeason}·${_currentWeather}·${_currentPhase}';
      final affection = getAffection(charId);

      if (history.length < 2) {
        _loadingChatIds.remove(charId);
        return;
      }

      // 双路记忆注入：基础记忆 + 按当前消息关键词召回的相关记忆
      final charNames = script?.characters.where((c) => c.fullCharacter).map((c) => c.basic.name).toList() ?? <String>[];
      final baseMemory = charMemory?.buildMemoryContext(charId) ?? '';
      final recalledMemory = charMemory?.buildRecalledContext(charId, currentMessage, charNames: charNames) ?? '';
      final memoryContext = recalledMemory.isNotEmpty ? '$recalledMemory\n\n$baseMemory' : baseMemory;

      final stream = deepSeekClient!.generateChatReplyStreaming(
        userMessage: currentMessage, character: char,
        affection: affection, chatHistory: chatHistory, playerName: userName,
        worldContext: worldContext, script: script,
        narrativeHistory: _narrativeHistory,
        memoryContext: memoryContext,
        rankingContext: rankingService?.buildRankingContext(int.tryParse(_currentDay) ?? 0) ?? '',
        locationContext: _currentLocation,
      );

      // 流式接收，首个 token 到达后才创建消息（UI 在此之前显示 typing indicator）
      await for (final token in stream) {
        if (charMsg == null) {
          charMsg = ChatMessage(senderId: charId, senderName: senderName, content: token);
          _chatHistories[charId]!.add(charMsg);
        } else {
          charMsg.content += token;
        }
        _notify();
      }

      _loadingChatIds.remove(charId);
      if (charMsg == null) {
        // 没收到任何 token，加一条 fallback
        charMsg = ChatMessage(senderId: charId, senderName: senderName, content: '(对方沉默了……)');
        _chatHistories[charId]!.add(charMsg);
        _notify();
      }
      // 拆分 ===MSG=== 为多条独立消息
      final replyContent = charMsg.content;
      if (replyContent.contains('===MSG===')) {
        final parts = replyContent.split('===MSG===').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        if (parts.length > 1) {
          charMsg.content = parts.first;
          for (int i = 1; i < parts.length; i++) {
            _chatHistories[charId]!.add(ChatMessage(senderId: charId, senderName: senderName, content: parts[i]));
          }
          _notify();
        }
      }

      final day = int.tryParse(_currentDay) ?? 0;
      charMemory?.recordChat(charId, day, currentMessage, replyContent, affection);

      try {
        final delta = await deepSeekClient!.analyzeAffectionDelta(
          playerMessage: currentMessage, aiReply: replyContent,
          character: char, currentAffection: affection,
        );
        modifyAffectionByChat(charId, delta);
      } catch (_) {
        modifyAffectionByChat(charId, 0.01);
      }
      _recordInteraction(charId);
      _notify();
      onChatCompleted?.call();
    } catch (e) {
      _loadingChatIds.remove(charId);
      final reply = NarrativeValidator.fallbackNarrative('chat_reply', script!.fallbackNarratives, {
        'char_name': char.basic.name,
        'location': '这里',
        'weather': _currentWeather,
        'phase': _currentPhase,
        'season': _currentSeason,
      });
      if (charMsg != null) {
        charMsg.content = reply;
      } else {
        _chatHistories[charId]!.add(ChatMessage(senderId: charId, senderName: senderName, content: reply));
      }
      modifyAffectionByChat(charId, -0.01);
      _notify();
      onChatCompleted?.call();
    }
  }

  String _resolveDisplayName(String charId, String fallback, Map<String, String> remarkNames) {
    final remark = remarkNames[charId];
    if (remark != null && remark.isNotEmpty) return remark;
    return fallback;
  }

  /// 会话结束：把当前会话的所有 segments 压缩成摘要，存入 charMemory
  /// 如果会话内没有 segments（比如只是进场景看了一眼就走了），跳过
  Future<void> _finalizeSessionSummary({required String locationContextName}) async {
    if (deepSeekClient == null || charMemory == null) return;
    // 收集当前会话的 segments
    final sessStart = _currentSessionStartIndex.clamp(0, _narrativeSegments.length);
    if (sessStart >= _narrativeSegments.length) return;
    final sessionSegs = _narrativeSegments.sublist(sessStart);
    if (sessionSegs.isEmpty || sessionSegs.length < 2) return; // 太少的会话不压缩

    final day = int.tryParse(_currentDay) ?? 1;
    final playerName = '主角';
    try {
      final summary = await deepSeekClient!.summarizeSession(
        sessionSegments: sessionSegs,
        day: day,
        locationContext: locationContextName.isNotEmpty ? locationContextName : '未知地点',
        playerName: playerName,
      );
      if (summary.isEmpty) return;
      // 判断是否关键事件：摘要里包含关系变化词或强情绪词
      final isCritical = ['告白', '表白', '分手', '破冰', '冲突', '吵架', '亲吻', '拥抱', '误会', '冷战', '背叛', '原谅']
          .any((w) => summary.contains(w));
      // 涉及的角色：会话内在场角色
      final involvedChars = _sceneInteractionChars.isNotEmpty
          ? _sceneInteractionChars
          : _extractCharIdsFromText(summary);
      if (involvedChars.isEmpty) return;
      final affections = <String, double>{};
      for (final cid in involvedChars) {
        affections[cid] = getAffection(cid);
      }
      charMemory!.recordSessionSummaryMulti(involvedChars, day, summary, affections, isCritical: isCritical);
    } catch (_) {
      // 压缩失败不影响游戏流程
    }
  }

  /// 从文本里提取可能涉及的角色 ID（简单匹配角色名）
  List<String> _extractCharIdsFromText(String text) {
    if (script == null) return [];
    final ids = <String>[];
    for (final c in script!.characters.where((c) => c.fullCharacter)) {
      if (text.contains(c.basic.name)) ids.add(c.basic.id);
    }
    return ids;
  }

  // ─── Scene events ───

  Future<Map<String, dynamic>> triggerSceneEvent(String locationId, String charId, {required String userName, required String userGender, required String userHeight, required String userBirthday, required String userAppearance, required String userPersonality, required String userBio}) async {
    if (deepSeekClient == null || script == null) return {'narrative': '', 'delta': 0.0};
    final scenes = script!.events?.sceneLocations ?? [];
    SceneLocation? found;
    for (final s in scenes) { if (s.id == locationId) { found = s; break; } }
    if (found == null) return {'narrative': '', 'delta': 0.0};
    final loc = found;
    final char = getCharacter(charId);
    if (char == null) return {'narrative': '', 'delta': 0.0};
    try {
      final narrative = await deepSeekClient!.generateSceneEventNarrative(
        location: loc, character: char, affection: getAffection(charId),
        script: script!, narrativeHistory: _narrativeHistory,
        charMemory: charMemory,
      );
      if (narrative.isNotEmpty && !narrative.startsWith('(')) {
        _appendToNarrative('\n\n[场景·${loc.name}] $narrative');
        _narrativeSegments.add('[场景·${loc.name}] $narrative');
        _segmentEventTypes.add('scene_event');
        _lastNarrativeSegment = narrative;
        _currentLocation = loc.name;
        final deltas = _parseCustomActionAffection(narrative);
        double totalDelta = 0;
        for (final e in deltas.entries) {
          modifyAffectionByEvent(e.key, e.value);
          totalDelta += e.value;
        }
        if (deltas.isEmpty) {
          final naturalDelta = affectionEngine != null
              ? affectionEngine!.modifyAffectionByEvent(charId, 0.3)
              : (_affectionStates[charId] ?? 50.0) + 0.3;
          _affectionStates[charId] = naturalDelta;
          relationshipEngine?.syncFromAffection(charId);
          totalDelta = 0.3;
        }
        charMemory?.recordEvent(charId, int.tryParse(_currentDay) ?? 1, '[场景·${loc.name}] $narrative', getAffection(charId));
        _checkBeatTriggers();
        _notify();
        return {'narrative': narrative, 'delta': totalDelta};
      }
      return {'narrative': narrative, 'delta': 0.0};
    } catch (e) {
      return <String, dynamic>{'narrative': '(场景事件触发失败: ${e.toString().length > 40 ? e.toString().substring(0, 40) : e.toString()})', 'delta': 0.0};
    }
  }

  // ═══════════════════════════════════════
  // 场景交互
  // ═══════════════════════════════════════

  bool _sceneInteractionActive = false;
  bool get sceneInteractionActive => _sceneInteractionActive;
  String _activeSceneLocationId = '';
  String get activeSceneLocationId => _activeSceneLocationId;
  String _activeSceneLocationName = '';
  String get activeSceneLocationName => _activeSceneLocationName;
  List<String> _sceneInteractionChars = [];
  List<String> get sceneInteractionChars => _sceneInteractionChars;
  String _sceneInteractionNarrative = '';
  String get sceneInteractionNarrative => _sceneInteractionNarrative;

  // ─── 存档用 setter ───
  void setSceneInteractionActive(bool v) => _sceneInteractionActive = v;
  void setActiveSceneLocationId(String v) => _activeSceneLocationId = v;
  void setActiveSceneLocationName(String v) => _activeSceneLocationName = v;
  void setSceneInteractionChars(List<String> v) => _sceneInteractionChars = List.from(v);
  void setSceneInteractionNarrative(String v) => _sceneInteractionNarrative = v;
  void setCurrentLocation(String v) => _currentLocation = v;
  String get currentLocation => _currentLocation;

  // 关键交互状态暴露给存档
  void setLastInteractionDays(Map<String, int> v) => _lastInteractionDay = Map.from(v);
  List<Map<String, dynamic>> get pendingChoicesSnapshot => List.from(_pendingChoices);
  void setPendingChoices(List<Map<String, dynamic>> v) => _pendingChoices = List.from(v);
  Map<String, String> get pendingInvitationSnapshot => Map.from(_pendingInvitation);
  void setPendingInvitation(Map<String, String> v) => _pendingInvitation = Map.from(v);
  Map<String, DateTime?> get initiativeCooldownsSnapshot => Map.from(_initiativeCooldowns);
  void setInitiativeCooldowns(Map<String, DateTime?> v) => _initiativeCooldowns = Map.from(v);
  List<Map<String, dynamic>> get activeForeshadowSnapshot => List.from(_activeForeshadow);
  void setActiveForeshadow(List<Map<String, dynamic>> v) => _activeForeshadow = List.from(v);
  List<Map<String, dynamic>> get butterflySeedsSnapshot => List.from(_butterflySeeds);
  void setButterflySeeds(List<Map<String, dynamic>> v) => _butterflySeeds = List.from(v);
  int get longEventStepsRemaining => _longEventStepsRemaining;
  void setLongEventStepsRemaining(int v) => _longEventStepsRemaining = v;
  bool get inLongEventSnapshot => _inLongEvent;
  void setInLongEvent(bool v) => _inLongEvent = v;

  /// WorldEngine 序列化快照
  Map<String, dynamic>? get worldEngineData => worldEngine?.toJson();
  void restoreWorldEngine(Map<String, dynamic> json) {
    worldEngine?.loadFromJson(json);
  }

  Future<Map<String, dynamic>> enterScene(String locationId, {required String userName, required String userGender, required String userHeight, required String userBirthday, required String userAppearance, required String userPersonality, required String userBio}) async {
    if (deepSeekClient == null || script == null || worldEngine == null) {
      return {'atmosphere': '', 'chars': <String>[], 'choices': <Map<String, dynamic>>[]};
    }
    final scenes = script!.events?.sceneLocations ?? [];
    SceneLocation? found;
    for (final s in scenes) { if (s.id == locationId) { found = s; break; } }
    if (found == null) {
      return {'atmosphere': '', 'chars': <String>[], 'choices': <Map<String, dynamic>>[]};
    }
    final loc = found;

    _sceneInteractionActive = true;
    _activeSceneLocationId = locationId;
    _activeSceneLocationName = loc.name;
    _sceneInteractionNarrative = '';
    // 开启新会话：标记会话起点，之后的 segments 受保护不被压缩
    _currentSessionStartIndex = _narrativeSegments.length;
    _currentSessionSegments = [];

    final chars = worldEngine!.getCharactersAtLocation(locationId);
    _sceneInteractionChars = chars.map((c) => c.basic.id).toList();

    final playerCard = buildPlayerCardForAi(userName, userGender, userHeight, userBirthday, userAppearance, userPersonality, userBio);

    _isLoading = true; _notify();
    try {
      final atmosphere = await deepSeekClient!.generateSceneAtmosphere(
        location: loc,
        presentChars: chars,
        currentDay: int.tryParse(_currentDay) ?? 1,
        season: _currentSeason,
        weather: _currentWeather,
        phase: _currentPhase,
        script: script!,
        playerCard: playerCard,
        charMemory: charMemory,
      );
      _sceneInteractionNarrative = atmosphere;
      await _generateChoices();
      _isLoading = false; _notify();
      return {
        'atmosphere': atmosphere,
        'chars': _sceneInteractionChars,
        'choices': List<Map<String, dynamic>>.from(_pendingChoices),
      };
    } catch (e) {
      _isLoading = false; _notify();
      return {
        'atmosphere': '（${loc.name}。${_currentWeather}的${_currentPhase}，一切如常。）',
        'chars': _sceneInteractionChars,
        'choices': <Map<String, dynamic>>[],
      };
    }
  }

  Future<Map<String, dynamic>> actInScene(String action, {required String userName, required String userGender, required String userHeight, required String userBirthday, required String userAppearance, required String userPersonality, required String userBio, bool isFreeText = false}) async {
    if (deepSeekClient == null || !_sceneInteractionActive) {
      return {'narrative': '', 'delta': 0.0, 'choices': <Map<String, dynamic>>[]};
    }

    final savedChoices = List<Map<String, dynamic>>.from(_pendingChoices);
    final choiceLabel = isFreeText
        ? action
        : (savedChoices.isNotEmpty
            ? (savedChoices[int.tryParse(action) ?? 0]['text'] as String? ?? action)
            : action);

    _isLoading = true; _pendingChoices = []; _notify();

    try {
      final playerCard = buildPlayerCardForAi(userName, userGender, userHeight, userBirthday, userAppearance, userPersonality, userBio);

      String narrative;
      if (isFreeText) {
        narrative = await deepSeekClient!.generateCustomActionConsequence(
          action: choiceLabel, script: script!,
          narrativeHistory: _sceneInteractionNarrative, playerCard: playerCard,
          timeContext: {
            'day': int.tryParse(_currentDay) ?? 1,
            'season': _currentSeason, 'weather': _currentWeather, 'phase': _currentPhase,
          },
          characters: script!.characters.where((c) => c.fullCharacter).toList(),
          affectionStates: _affectionStates,
          charMemory: charMemory,
          targetCharId: _sceneInteractionChars.isNotEmpty ? _sceneInteractionChars.first : '',
        );
      } else {
        narrative = await deepSeekClient!.generateChoiceResponse(
          choice: choiceLabel, script: script!,
          narrativeHistory: _sceneInteractionNarrative,
          timeContext: {
            'day': int.tryParse(_currentDay) ?? 1,
            'season': _currentSeason, 'weather': _currentWeather, 'phase': _currentPhase,
          },
          isContinuation: false,
          charMemory: charMemory,
          targetCharId: _sceneInteractionChars.isNotEmpty ? _sceneInteractionChars.first : '',
          affectionStates: _affectionStates,
        );
      }

      narrative = _extractSceneShift(narrative);
      _sceneInteractionNarrative += '\n\n$narrative';
      _appendToNarrative('\n\n[场景·$_activeSceneLocationName] $narrative');
      _narrativeSegments.add('[场景·$_activeSceneLocationName] $narrative');
      _segmentEventTypes.add('scene_event');
      _lastNarrativeSegment = narrative;

      final deltas = _parseCustomActionAffection(narrative);
      double totalDelta = 0;
      for (final e in deltas.entries) {
        modifyAffectionByEvent(e.key, e.value);
        totalDelta += e.value;
      }
      if (deltas.isEmpty && _sceneInteractionChars.isNotEmpty) {
        for (final pid in _sceneInteractionChars) {
          final naturalDelta = affectionEngine != null
              ? affectionEngine!.modifyAffectionByEvent(pid, 0.2)
              : (_affectionStates[pid] ?? 50.0) + 0.2;
          _affectionStates[pid] = naturalDelta;
          relationshipEngine?.syncFromAffection(pid);
        }
        totalDelta = 0.2;
      }

      for (final pid in _sceneInteractionChars) {
        charMemory?.recordEvent(pid, int.tryParse(_currentDay) ?? 1, '[场景·$_activeSceneLocationName] $narrative', getAffection(pid));
      }
      _recordInteractions(_sceneInteractionChars);

      await _generateChoices();
      _isLoading = false; _notify();
      return {
        'narrative': narrative,
        'delta': totalDelta,
        'choices': List<Map<String, dynamic>>.from(_pendingChoices),
      };
    } catch (e) {
      _isLoading = false; _notify();
      return {'narrative': '', 'delta': 0.0, 'choices': <Map<String, dynamic>>[]};
    }
  }

  Future<void> leaveScene() async {
    if (worldEngine == null) return;
    if (!_sceneInteractionActive) return;

    // 场景互动结束后生成信息碎片（修罗场前置）
    _generateInfoFragmentFromScene();

    // 会话结束：压缩本次场景互动的叙事，存入 charMemory 作为长期记忆
    await _finalizeSessionSummary(locationContextName: _activeSceneLocationName);

    worldEngine?.advancePhase();
    _currentDay = worldEngine!.currentDay.toString();
    _currentPhase = worldEngine!.currentPhase;
    _currentWeather = worldEngine!.currentWeather;
    _currentSeason = worldEngine!.currentSeason;
    _sceneInteractionActive = false;
    _activeSceneLocationId = '';
    _activeSceneLocationName = '';
    _sceneInteractionChars = [];
    _sceneInteractionNarrative = '';
    _currentSessionSegments = [];
    _currentSessionStartIndex = 0;
    _notify();
  }

  /// 场景互动结束后，如果发生了值得传播的事件，生成信息碎片
  void _generateInfoFragmentFromScene() {
    if (worldEngine == null || script == null) return;
    if (_sceneInteractionChars.isEmpty || _sceneInteractionNarrative.isEmpty) return;

    final narrative = _sceneInteractionNarrative;
    // 判断是否包含亲密/冲突等可传播内容
    final sensitiveKeywords = ['亲密', '拥抱', '亲吻', '牵手', '靠近', '暧昧', '脸红', '心跳', '耳语', '抚摸', '吻', '床', '酒店', '过夜'];
    final conflictKeywords = ['争吵', '吵架', '打', '骂', '冲突', '怒', '摔', '哭'];
    final isSensitive = sensitiveKeywords.any((k) => narrative.contains(k));
    final isConflict = conflictKeywords.any((k) => narrative.contains(k));

    if (!isSensitive && !isConflict) return;

    final witnessCharId = _sceneInteractionChars.first;
    final locationName = _activeSceneLocationName;
    final content = isSensitive
        ? '玩家与${getCharacter(witnessCharId)?.basic.name ?? witnessCharId}在$locationName有亲密互动'
        : '玩家与${getCharacter(witnessCharId)?.basic.name ?? witnessCharId}在$locationName发生冲突';

    final encryption = isSensitive
        ? (['gossip', 'speculation', 'honest']..shuffle(_rng)).first
        : (['cold', 'gossip', 'honest']..shuffle(_rng)).first;

    worldEngine!.infoProp.createFragment(
      sourceEventId: 'scene_${_currentDay}_$witnessCharId',
      witnessCharId: witnessCharId,
      content: content,
      encryption: encryption,
      spreadRadius: 3,
    );

    // 通知角色关系系统
    if (_sceneInteractionChars.length >= 2) {
      worldEngine!.interCharRel.onPlayerEvent(
        _sceneInteractionChars,
        _affectionStates,
        isSensitive ? '亲密互动' : '冲突',
      );
    }
  }

  // ─── Tension ───

  void _rhythmTick() {
    if (rhythmScheduler == null) {
      final inc = (_rng.nextInt(30)) / 10.0;
      _tensionLevel = (_tensionLevel + inc).clamp(0.0, 100.0);
      _syncTensionToScript();
      return;
    }
    final t = rhythmScheduler!.tension;
    t.decayRelational(0.5);
    t.decayNarrative(0.5);
    t.decayEmotional(0.5);
    _tensionLevel = t.composite;
    _syncTensionToScript();
  }

  void _tickTensionAfterEvent(String eventSeverity) {
    if (rhythmScheduler == null) {
      final inc = eventSeverity == 'high' ? 5.0 : (eventSeverity == 'medium' ? 3.0 : 1.0);
      _tensionLevel = (_tensionLevel + inc).clamp(0.0, 100.0);
      _syncTensionToScript();
      return;
    }
    final t = rhythmScheduler!.tension;
    final nd = eventSeverity == 'high' ? 15.0 : (eventSeverity == 'medium' ? 8.0 : 3.0);
    t.tickNarrative(nd);
    _tensionLevel = t.composite;
    _syncTensionToScript();
  }

  void _syncTensionToScript() {
    final nt = script?.plot?.narrativeTension;
    nt?.setLevel(_tensionLevel);
  }

  String _currentSceneLocationName(List<String>? participants, WorldTickReport tick) {
    final dc = tick.dramaticCollision;
    if (dc != null) return dc['location']?.toString() ?? '';
    if (participants != null && participants.isNotEmpty) {
      final char = getCharacter(participants.first);
      if (char != null) return char.basic.name + '附近';
    }
    return '';
  }

  // ─── Beat triggers ───

  void _checkBeatTriggers() {
    final plot = script?.plot;
    if (plot == null) return;
    for (final beat in plot.beats) {
      if (_triggeredBeats[beat.id] == true && beat.once) continue;
      if (_checkBeatCondition(beat)) {
        _triggeredBeats[beat.id] = true;
        _applyBeatOutcome(beat);
      }
    }
  }

  bool _checkBeatCondition(PlotBeat beat) {
    final d = int.tryParse(_currentDay) ?? 1;
    final tMin = beat.trigger.time['min'] ?? 0;
    final tMax = beat.trigger.time['max'] ?? 999;
    if (d < tMin || d > tMax) return false;
    final affConds = beat.trigger.affection;
    if (affConds.isNotEmpty) {
      for (final entry in affConds.entries) {
        final aff = getAffection(entry.key);
        if (entry.value is Map) {
          final lo = entry.value['ge'] ?? 0;
          final hi = entry.value['le'] ?? 100;
          if (aff < lo || aff > hi) return false;
        }
      }
    }
    for (final pb in beat.trigger.preBeats) {
      if (_triggeredBeats[pb] != true) return false;
    }
    return true;
  }

  void _applyBeatOutcome(PlotBeat beat) {
    final affChanges = beat.outcome.affectionChanges;
    for (final entry in affChanges.entries) {
      if (entry.value is num) modifyAffectionByEvent(entry.key, (entry.value as num).toDouble());
    }
    if (beat.outcome.advanceAct) _advanceAct();
    if (beat.aiHint.isNotEmpty && beat.alwaysMemory) {
      _activeForeshadow.add({'beat_id': beat.id, 'hint': beat.aiHint, 'planted_day': _currentDay});
    }
  }

  void _advanceAct() {
    final plot = script?.plot;
    if (plot == null) return;
    final idx = plot.acts.indexWhere((a) => a.id == _currentAct);
    if (idx >= 0 && idx < plot.acts.length - 1) {
      _currentAct = plot.acts[idx + 1].id;
    }
  }

  // ─── Character initiative ───

  void _checkCharacterInitiative(String userName, Map<String, String> charRemarkNames) {
    final triggers = script?.dialogue?.messageFromChar ?? [];
    final now = DateTime.now();
    for (final trigger in triggers) {
      if (trigger.once && _initiativeCooldowns.containsKey(trigger.id)) continue;
      final lastTime = _initiativeCooldowns[trigger.id];
      if (lastTime != null && now.difference(lastTime).inHours < trigger.cooldownDays * 24) continue;
      final cond = trigger.condition;
      if (cond.isNotEmpty) {
        final affMatch = RegExp(r'affection\s*>\s*(\d+)').firstMatch(cond);
        if (affMatch != null) {
          final required = double.tryParse(affMatch.group(1)!) ?? 0;
          if (getAffection(trigger.charId) < required) continue;
        }
      }
      _initiativeCooldowns[trigger.id] = now;
      _sendCharInitiativeMessage(trigger.charId, 'care', trigger.aiHint, userName, charRemarkNames);
    }
  }

  /// 检查角色主动消息：drama事件触发 + 日常主动触发
  Future<void> _checkCharInitiativeMessages(String userName, Map<String, String> charRemarkNames) async {
    if (deepSeekClient == null || script == null || worldEngine == null) return;

    // 1. drama事件触发：信息传播/角色间关系drama
    final tickReport = worldEngine!.lastTickReport;
    if (tickReport != null && tickReport.hasDrama) {
      String? dramaCharId;
      String dramaContext = '';

      // 优先处理信息传播（B听说玩家和A亲密）
      if (tickReport.infoSpreads.isNotEmpty) {
        for (final spread in tickReport.infoSpreads) {
          final aff = getAffection(spread.toCharId);
          if (aff < 30) continue; // 好感太低不会主动来质问
          dramaCharId = spread.toCharId;
          dramaContext = '你听说了关于玩家的事：${spread.distortedContent.isNotEmpty ? spread.distortedContent : "有人在议论你和TA的关系"}';
          break;
        }
      }

      // 其次处理角色间嫉妒drama
      if (dramaCharId == null && tickReport.interCharDrama.isNotEmpty) {
        // 找一个好感>50的角色来质问
        for (final c in script!.characters.where((c) => c.fullCharacter)) {
          final aff = getAffection(c.basic.id);
          if (aff > 50 && _rng.nextInt(100) < 50) {
            dramaCharId = c.basic.id;
            dramaContext = '你感觉最近${c.basic.name}的态度有些不对劲，似乎听到了什么风声';
            break;
          }
        }
      }

      if (dramaCharId != null) {
        await _sendCharInitiativeMessage(dramaCharId, 'drama', dramaContext, userName, charRemarkNames);
        return; // 每次推进最多1条drama消息
      }
    }

    // 2. 日常主动触发：长时间没联系的角色有概率主动发消息
    if (_rng.nextInt(100) < 20) { // 20%概率
      final currentDay = int.tryParse(_currentDay) ?? 1;
      final candidates = script!.characters.where((c) {
        final aff = getAffection(c.basic.id);
        if (aff < 40) return false; // 好感<40不会主动找你
        final lastDay = _lastInteractionDay[c.basic.id] ?? 0;
        return currentDay - lastDay >= 2; // 至少2天没联系
      }).toList();

      if (candidates.isNotEmpty) {
        candidates.shuffle(_rng);
        final char = candidates.first;
        await _sendCharInitiativeMessage(char.basic.id, 'care', '', userName, charRemarkNames);
      }
    }
  }

  String get playerDisplayName => script?.player.name ?? '玩家';

  Future<void> _sendCharInitiativeMessage(String charId, String trigger, String triggerContext, String userName, Map<String, String> charRemarkNames) async {
    final char = getCharacter(charId);
    if (char == null || deepSeekClient == null) return;
    try {
      final worldContext = '第${_currentDay}天 ${_currentSeason}·${_currentWeather}·${_currentPhase}';
      final chatHistory = (_chatHistories[charId] ?? [])
          .map((m) => {'role': m.senderId == 'player' ? 'user' : 'assistant', 'content': m.content})
          .toList();

      final msg = await deepSeekClient!.generateInitiativeMessage(
        character: char,
        affection: getAffection(charId),
        chatHistory: chatHistory,
        playerName: userName,
        worldContext: worldContext,
        trigger: trigger,
        triggerContext: triggerContext,
        script: script,
        narrativeHistory: _narrativeHistory,
        memoryContext: charMemory?.buildMemoryContext(charId) ?? '',
      );

      _chatHistories.putIfAbsent(charId, () => []);
      final displayName = _resolveDisplayName(charId, char.basic.name, charRemarkNames);
      _chatHistories[charId]!.add(ChatMessage(senderId: charId, senderName: displayName, content: msg));
      modifyAffectionByChat(charId, 0.02);
      _notify();
    } catch (_) {}
  }

  void _checkInvitation() {
    _pendingInvitation = {};
    if (script == null) return;
    final chars = script!.characters.where((c) => c.fullCharacter).toList();
    for (final c in chars) {
      final aff = getAffection(c.basic.id);
      if (aff < 65) continue;
      final chance = (aff - 60) * 0.01;
      final rng = _rng.nextInt(1000);
      if (rng / 1000.0 < chance) {
        final locs = script!.events?.sceneLocations ?? [];
        if (locs.isNotEmpty) {
          _pendingInvitation[c.basic.id] = locs[rng % locs.length].id;
          break;
        }
      }
    }
  }

  void clearInvitation(String charId) {
    _pendingInvitation.remove(charId);
    _notify();
  }

  // ─── Butterfly ───

  void _advanceButterfly() {
    final bt = script?.gameEvents?.butterflySystem;
    if (bt == null) return;
    if (_butterflySeeds.length < bt.maxSeeds) {
      final rng = _rng.nextInt(1000);
      if (rng / 1000.0 < bt.bloomChance) {
        _butterflySeeds.add({
          'planted_day': _currentDay,
          'seed': bt.seeds.isNotEmpty ? bt.seeds[rng % bt.seeds.length] : {},
        });
      }
    }
  }
}
