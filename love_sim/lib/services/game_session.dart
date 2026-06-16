import 'dart:math';
import 'package:love_sim/models/script.dart';
import 'package:love_sim/services/deepseek_client.dart';
import 'package:love_sim/services/world_engine.dart';
import 'package:love_sim/services/affection_engine.dart';
import 'package:love_sim/services/relationship_engine.dart';
import 'package:love_sim/services/event_scheduler.dart';
import 'package:love_sim/services/narrative_compressor.dart';
import 'package:love_sim/services/character_memory_service.dart';
import 'package:love_sim/services/ranking_service.dart';
import 'package:love_sim/services/save_service.dart';

class GameSession {
  void Function()? onChanged;

  GameScript? script;
  DeepSeekClient? deepSeekClient;
  WorldEngine? worldEngine;
  AffectionEngine? affectionEngine;
  RelationshipEngine? relationshipEngine;
  EventScheduler? eventScheduler;
  CharacterMemoryService? charMemory;
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

  List<Map<String, dynamic>> _pendingChoices = [];
  List<Map<String, dynamic>> get pendingChoices => _pendingChoices;

  int _longEventStepsRemaining = 0;
  bool _inLongEvent = false;
  String _lastNarrativeSegment = '';
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  bool get inLongEvent => _inLongEvent;
  String get lastNarrativeSegment => _lastNarrativeSegment;

  Map<String, double> _playerStats = {};
  Map<String, double> get playerStats => _playerStats;

  Map<String, double> _playerGrades = {};
  Map<String, double> get playerGrades => _playerGrades;

  Map<String, double> _affectionStates = {};
  Map<String, double> get affectionStates => _affectionStates;

  Map<String, List<ChatMessage>> _chatHistories = {};
  Map<String, List<ChatMessage>> get chatHistories => _chatHistories;

  List<String> _inventoryItemIds = [];
  List<String> get inventoryItemIds => _inventoryItemIds;

  Map<String, int> _currencies = {'gold': 100};
  Map<String, int> get currencies => _currencies;

  Map<String, List<String>> _sceneChars = {};
  List<String> getSceneChars(String locationId) => _sceneChars[locationId] ?? [];

  final Set<String> _loadingChatIds = {};
  bool isChatLoading(String charId) => _loadingChatIds.contains(charId);

  String _currentAct = 'act_1';
  String get currentAct => _currentAct;

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

  void addItem(String itemId) {
    if (!_inventoryItemIds.contains(itemId)) { _inventoryItemIds.add(itemId); onChanged?.call(); }
  }

  bool hasItem(String itemId) => _inventoryItemIds.contains(itemId);

  void _appendToNarrative(String text) {
    _narrativeHistory += text;
    _narrativeHistory = _narrativeHistory.trim();
    if (_narrativeCompressor != null && _narrativeCompressor!.needsCompression(_narrativeHistory)) {
      final result = _narrativeCompressor!.compressSegments(_narrativeSegments);
      _narrativeHistory = result.history;
      _narrativeSegments = result.segments;
      if (result.replacedCount > 0) {
        onChanged?.call();
      }
    }
  }

  void _notify() => onChanged?.call();

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
    _narrativeHistory = s.world.memory.worldSummary;
    _narrativeSegments = _narrativeHistory.isNotEmpty ? [_narrativeHistory] : [];
    _pendingChoices = [];
    _lastNarrativeSegment = _narrativeHistory;
    _currencies['gold'] = 50;
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
    _rng.nextInt(1000);
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
  void setAffectionStates(Map<String, double> v) { _affectionStates = Map<String, double>.from(v); }
  void setChatHistories(Map<String, List<ChatMessage>> v) { _chatHistories = Map<String, List<ChatMessage>>.from(v); }
  void setInventoryItemIds(List<String> v) { _inventoryItemIds = List.from(v); }
  void setCurrencies(Map<String, int> v) { _currencies = Map<String, int>.from(v); }
  void setCurrentAct(String v) => _currentAct = v;
  void setTriggeredBeats(Map<String, bool> v) { _triggeredBeats = Map<String, bool>.from(v); }
  void setTensionLevel(double v) => _tensionLevel = v;
  void setEndingProgress(Map<String, double> v) { _endingProgress = Map<String, double>.from(v); }
  void setEventCounter(int v) => _eventCounter = v;
  void setRecentEvents(List<Map<String, dynamic>> v) { _recentEvents = List<Map<String, dynamic>>.from(v); }
  void setPlayerStats(Map<String, double> v) { _playerStats = Map<String, double>.from(v); }
  void setPlayerGrades(Map<String, double> v) { _playerGrades = Map<String, double>.from(v); }

  // ─── Core gameplay ───

  Future<void> advance(String mode, {required String userName, required String userGender, required String userHeight, required String userBirthday, required String userAppearance, required String userPersonality, required String userBio, required Map<String, String> charRemarkNames}) async {
    if (_isLoading || worldEngine == null) return;
    _isLoading = true; _pendingChoices = []; _notify();

    _tickTension();
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

      final result = await worldEngine!.advance(mode);

      String narrative;
      List<String>? participants;
      if (eventTemplate != null) {
        eventScheduler?.recordEvent(eventTemplate);

        final allCharIds = script!.characters.where((c) => c.fullCharacter).map((c) => c.basic.id).toList();
        final isFreeform = eventTemplate.aiRule == 'freeform';

        Map<String, dynamic>? freeformContext;
        if (isFreeform) {
          final locations = script!.events?.sceneLocations ?? [];
          freeformContext = eventScheduler!.pickFreeformContext(
            events: script!.gameEvents!, allCharIds: allCharIds,
            affection: affectionEngine!, relationship: relationshipEngine,
            currentPhase: worldEngine!.currentPhase, currentWeather: worldEngine!.currentWeather,
            locations: locations,
          );
        }

        String enrichedHint = eventTemplate.aiHint;
        participants = eventScheduler!.pickParticipants(
          event: eventTemplate, allCharIds: allCharIds,
          affection: affectionEngine!, relationship: relationshipEngine,
        );
        if (participants.isNotEmpty) {
          final names = participants.map((id) => getCharacter(id)?.basic.name ?? id).join('、');
          enrichedHint = '$enrichedHint\n【在场角色】$names';
        }

        final worldTick = worldEngine!.tickWorld(playerAffections: _affectionStates);
        String worldReport = '';
        if (worldTick.hasDrama) {
          worldReport = worldEngine!.buildWorldReport(worldTick);
        }
        if (participants.isNotEmpty) {
          worldEngine!.interCharRel.onPlayerEvent(participants, _affectionStates, '共同参与事件: ${eventTemplate.name}');
        }

        final playerCard = buildPlayerCardForAi(userName, userGender, userHeight, userBirthday, userAppearance, userPersonality, userBio);
        narrative = await deepSeekClient!.generateEventNarrative(
          eventType: eventTemplate.id.isNotEmpty ? eventTemplate.name : eventTemplate.id,
          aiHint: enrichedHint, script: script!,
          narrativeHistory: _narrativeHistory, timeContext: worldEngine!.getTimeContext(),
          playerCard: playerCard, freeformContext: freeformContext, worldReport: worldReport,
        );
        _eventCounter++;
        _recentEvents.add({'event_id': eventTemplate.id, 'name': eventTemplate.name, 'day': _currentDay, 'severity': eventTemplate.severity});
        _tickTensionAfterEvent(eventTemplate.severity);
        _advanceButterfly();
        if (eventTemplate.duration == 'long') {
          _longEventStepsRemaining = eventTemplate.maxSteps < 1 ? 1 : (eventTemplate.maxSteps > 5 ? 5 : eventTemplate.maxSteps);
          _inLongEvent = true;
        } else {
          _inLongEvent = false; _longEventStepsRemaining = 0;
        }
      } else {
        narrative = result.narrative;
      }

      _appendToNarrative('\n\n$narrative');
      _narrativeSegments.add(narrative);
      _lastNarrativeSegment = narrative;
      _currentDay = result.dayAfter.toString();
      _currentPhase = worldEngine!.currentPhase;
      _currentWeather = worldEngine!.currentWeather;
      _currentSeason = worldEngine!.currentSeason;
      _daysSkipped = result.daysSkipped;

      final int dayNum = result.dayAfter;
      if (participants != null && participants.isNotEmpty) {
        final eventName = eventTemplate?.name ?? '日常事件';
        for (final pid in participants) {
          charMemory?.recordEvent(pid, dayNum, eventName, getAffection(pid));
        }
      }
    } catch (e) {
      final err = '[剧情推进失败: ${e.toString().length > 60 ? e.toString().substring(0, 60) : e.toString()}]';
      _appendToNarrative('\n\n$err');
      _narrativeSegments.add(err);
      _lastNarrativeSegment = err;
    }
    _isLoading = false; _notify();
    final dayNum = int.tryParse(_currentDay) ?? 0;
    if (dayNum > 0) _checkAndProcessExam(dayNum);
    _generateChoices();
    _checkInvitation();
  }

  Future<void> customAction(String action, {required String userName, required String userGender, required String userHeight, required String userBirthday, required String userAppearance, required String userPersonality, required String userBio}) async {
    if (_isLoading || deepSeekClient == null || script == null) return;
    _isLoading = true; _pendingChoices = []; _notify();
    try {
      final playerCard = buildPlayerCardForAi(userName, userGender, userHeight, userBirthday, userAppearance, userPersonality, userBio);
      final narrative = await deepSeekClient!.generateCustomActionConsequence(
        action: action, script: script!,
        narrativeHistory: _narrativeHistory, playerCard: playerCard,
        timeContext: worldEngine?.getTimeContext() ?? {},
        characters: script!.characters, affectionStates: _affectionStates,
      );
      _appendToNarrative('\n\n$narrative');
      _narrativeSegments.add(narrative);
      _lastNarrativeSegment = narrative;
      final affectionDeltas = _parseCustomActionAffection(narrative);
      for (final e in affectionDeltas.entries) {
        if (affectionEngine != null) affectionEngine!.modifyAffectionByEvent(e.key, e.value);
        _affectionStates[e.key] = (_affectionStates[e.key] ?? 50.0) + e.value;
      }
    } catch (e) {
      final err = '[行动失败: ${e.toString().length > 60 ? e.toString().substring(0, 60) : e.toString()}]';
      _appendToNarrative('\n\n$err');
      _narrativeSegments.add(err);
      _lastNarrativeSegment = err;
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
      final narrative = await deepSeekClient!.generateChoiceResponse(
        choice: text, script: script!,
        narrativeHistory: _narrativeHistory,
        timeContext: worldEngine?.getTimeContext() ?? {},
        isContinuation: _inLongEvent && _longEventStepsRemaining > 0,
      );
      _appendToNarrative('\n\n你选择了：$text\n\n$narrative');
      _narrativeSegments.add('你选择了：$text\n\n$narrative');
      _lastNarrativeSegment = narrative;
      if (target != null && target.isNotEmpty) {
        modifyAffectionByEvent(target, delta);
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
        script: script!, narrativeHistory: _narrativeHistory, isLongEvent: _inLongEvent,
      );
      _notify();
    } catch (_) {}
  }

  // ─── Chat ───

  void sendMessage(String charId, String message, {required String userName, required String userDisplayName, required Map<String, String> charRemarkNames}) {
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
    try {
      _loadingChatIds.add(charId);
      _notify();
      final history = _chatHistories[charId]!;
      final chatHistory = <Map<String, String>>[];
      final start = history.length > 20 ? history.length - 20 : 0;
      for (int i = start; i < history.length - 1; i++) {
        final msg = history[i];
        chatHistory.add({'role': msg.senderId == 'player' ? 'user' : 'assistant', 'content': msg.content});
      }

      final worldContext = '第${_currentDay}天 ${_currentSeason}·${_currentWeather}·${_currentPhase}';
      final affection = getAffection(charId);

      final charMsg = ChatMessage(senderId: charId, senderName: senderName, content: '');
      _chatHistories[charId]!.add(charMsg);
      _notify();

      final stream = deepSeekClient!.generateChatReplyStreaming(
        userMessage: history[history.length - 2].content, character: char,
        affection: affection, chatHistory: chatHistory, playerName: userName,
        worldContext: worldContext, script: script,
        narrativeHistory: _narrativeHistory,
        memoryContext: charMemory?.buildMemoryContext(charId) ?? '',
      );

      await for (final token in stream) {
        charMsg.content += token;
        _notify();
      }

      _loadingChatIds.remove(charId);
      final replyContent = charMsg.content;
      if (replyContent.isEmpty) charMsg.content = '(对方沉默了……)';

      final day = int.tryParse(_currentDay) ?? 0;
      final topic = history[history.length - 2].content;
      charMemory?.recordChat(charId, day, topic.length > 40 ? '${topic.substring(0, 40)}...' : topic, topic, affection);

      try {
        final delta = await deepSeekClient!.analyzeAffectionDelta(
          playerMessage: history[history.length - 2].content, aiReply: replyContent,
          character: char, currentAffection: affection,
        );
        modifyAffectionByChat(charId, delta);
      } catch (_) {
        modifyAffectionByChat(charId, 0.01);
      }
      _notify();
    } catch (e) {
      _loadingChatIds.remove(charId);
      final errorMsg = e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString();
      final charMsg = ChatMessage(senderId: charId, senderName: senderName, content: '(回复失败: $errorMsg)');
      _chatHistories[charId]!.add(charMsg);
      modifyAffectionByChat(charId, -0.01);
      _notify();
    }
  }

  void sendGift(String charId, ShopItem item, {required String userName, required Map<String, String> charRemarkNames}) {
    if (!_inventoryItemIds.contains(item.id)) return;
    _inventoryItemIds.remove(item.id);
    final char = getCharacter(charId);
    final senderName = _resolveDisplayName(charId, char?.basic.name ?? charId, charRemarkNames);
    final giftMsg = ChatMessage(senderId: 'player', senderName: userName, content: '🎁 送出了「${item.name}」');
    _chatHistories.putIfAbsent(charId, () => []);
    _chatHistories[charId]!.add(giftMsg);
    final delta = item.type == 'gift' ? (int.tryParse(item.value)?.toDouble() ?? 1.0) : 0.5;
    modifyAffectionByChat(charId, delta);
    _notify();

    Future.delayed(const Duration(milliseconds: 500), () {
      final reply = ChatMessage(senderId: charId, senderName: senderName, content: '谢谢你送的${item.name}！我很喜欢～');
      _chatHistories[charId]!.add(reply);
      _notify();
    });
  }

  String _resolveDisplayName(String charId, String fallback, Map<String, String> remarkNames) {
    final remark = remarkNames[charId];
    if (remark != null && remark.isNotEmpty) return remark;
    return fallback;
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
      );
      if (narrative.isNotEmpty && !narrative.startsWith('(')) {
        _appendToNarrative('\n\n[场景·${loc.name}] $narrative');
        _narrativeSegments.add('[场景·${loc.name}] $narrative');
        _lastNarrativeSegment = narrative;
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
        _notify();
        return {'narrative': narrative, 'delta': totalDelta};
      }
      return {'narrative': narrative, 'delta': 0.0};
    } catch (e) {
      return <String, dynamic>{'narrative': '(场景事件触发失败: ${e.toString().length > 40 ? e.toString().substring(0, 40) : e.toString()})', 'delta': 0.0};
    }
  }

  // ─── Tension ───

  void _tickTension() {
    final inc = (_rng.nextInt(30)) / 10.0;
    _tensionLevel = (_tensionLevel + inc).clamp(0.0, 100.0);
    _syncTensionToScript();
  }

  void _tickTensionAfterEvent(String eventSeverity) {
    final inc = eventSeverity == 'high' ? 5.0 : (eventSeverity == 'medium' ? 3.0 : 1.0);
    _tensionLevel = (_tensionLevel + inc).clamp(0.0, 100.0);
    _syncTensionToScript();
  }

  void _syncTensionToScript() {
    final nt = script?.plot?.narrativeTension;
    nt?.setLevel(_tensionLevel);
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
    for (final itemId in beat.outcome.unlockItems) { addItem(itemId); }
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
      _generateInitiativeMessage(trigger.charId, trigger.aiHint, userName, charRemarkNames);
    }
  }

  Future<void> _generateInitiativeMessage(String charId, String aiHint, String userName, Map<String, String> charRemarkNames) async {
    final char = getCharacter(charId);
    if (char == null || deepSeekClient == null) return;
    try {
      final worldContext = '第${_currentDay}天 ${_currentSeason}·${_currentWeather}·${_currentPhase}';
      final msg = await deepSeekClient!.generateChatReply(
        userMessage: '(对方主动发来消息)$aiHint',
        character: char, affection: getAffection(charId),
        chatHistory: [], playerName: userName, worldContext: worldContext,
        script: script, narrativeHistory: _narrativeHistory,
      );
      _chatHistories.putIfAbsent(charId, () => []);
      final displayName = _resolveDisplayName(charId, char.basic.name, charRemarkNames);
      _chatHistories[charId]!.add(ChatMessage(senderId: charId, senderName: displayName, content: msg));
      modifyAffectionByChat(charId, 0.02);
    } catch (_) {}
  }

  void _checkInvitation() {
    _pendingInvitation = {};
    if (script == null) return;
    final rng = _rng.nextInt(1000);
    final chars = script!.characters.where((c) => c.fullCharacter).toList();
    for (final c in chars) {
      final aff = getAffection(c.basic.id);
      if (aff < 65) continue;
      final chance = (aff - 60) * 0.01;
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
