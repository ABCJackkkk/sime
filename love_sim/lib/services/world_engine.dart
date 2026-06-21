import 'dart:math';
import 'package:love_sim/models/script.dart';
import 'package:love_sim/services/deepseek_client.dart';
import 'package:love_sim/services/character_schedule.dart';
import 'package:love_sim/services/inter_character_relationship.dart';
import 'package:love_sim/services/information_propagation.dart';
import 'package:love_sim/services/calendar_service.dart';

class WorldTickReport {
  final List<ScheduleCollision> collisions;
  final Map<String, dynamic>? dramaticCollision;
  final String interCharDrama;
  final List<InfoSpreadEvent> infoSpreads;
  final String knowledgeSummary;
  WorldTickReport({
    this.collisions = const [],
    this.dramaticCollision,
    this.interCharDrama = '',
    this.infoSpreads = const [],
    this.knowledgeSummary = '',
  });
  bool get hasDrama => dramaticCollision != null || interCharDrama.isNotEmpty || infoSpreads.isNotEmpty;
}

class AdvanceResult {
  final String narrative;
  final int dayBefore;
  final int dayAfter;
  final int daysSkipped;
  final Map<String, dynamic>? milestone;

  AdvanceResult({
    required this.narrative,
    required this.dayBefore,
    required this.dayAfter,
    this.daysSkipped = 0,
    this.milestone,
  });

  bool get hitMilestone => milestone != null;
}

class WorldEngine {
  final GameScript script;
  final DeepSeekClient client;
  final CalendarService calendar = CalendarService();
  String _narrativeHistory = '';

  WorldEngine({required this.script, required this.client});

  // ═══════════════════════════════════════
  // 时间状态
  // ═══════════════════════════════════════

  int _currentDay = 1;
  int _phaseIndex = 0;
  String _currentWeather = '晴';
  String _currentSeason = '春';
  int _seasonDayCounter = 0;

  int get currentDay => _currentDay;
  set currentDay(int v) {
    _currentDay = v;
    calendar.currentDay = v;
    _seasonDayCounter = 0;
  }

  String get currentPhase => _phases[_phaseIndex];
  int get phaseIndex => _phaseIndex;
  String get currentWeather => _currentWeather;
  String get currentSeason => _currentSeason;
  String get narrativeHistory => _narrativeHistory;

  bool get isWeekend => calendar.isWeekend(_currentDay);
  String get weekdayName => calendar.weekdayName(_currentDay);
  bool get isSpecialDay => calendar.getSpecialDay(_currentDay) != null;
  Map<String, dynamic>? get currentSpecialDay => calendar.getSpecialDay(_currentDay);

  CharacterScheduleService scheduleService = CharacterScheduleService();
  InterCharRelationshipService interCharRel = InterCharRelationshipService();
  InformationPropagationService infoProp = InformationPropagationService();
  WorldTickReport? lastTickReport;

  void initWorldServices() {
    interCharRel.initFromScript(script.characters);
  }

  // ═══════════════════════════════════════
  // 时段系统
  // ═══════════════════════════════════════

  List<String> get _phases => calendar.getPhaseNames(_currentDay);

  /// 时段是否可行动（夜晚最后时段是睡眠，不可行动）
  bool get canAct {
    if (_phases.isEmpty) return false;
    // 夜晚的最后一个时段只能休息
    if (currentPhase == '夜晚' && _phaseIndex == _phases.length - 1) return true;
    return true;
  }

  /// 推进到下一时段。如果当天结束，推进到下一天
  bool advancePhase() {
    _phaseIndex++;
    if (_phaseIndex >= _phases.length) {
      _phaseIndex = 0;
      _advanceDay();
      return true; // 跨天了
    }
    return false;
  }

  /// 获取剩余的时段数
  int get remainingPhases => _phases.length - _phaseIndex - 1;

  /// 获取所有已过的时段
  List<String> get passedPhases {
    if (_phaseIndex == 0) return [];
    return _phases.sublist(0, _phaseIndex);
  }

  /// 获取今天的时段列表
  List<String> get todayPhases => List.unmodifiable(_phases);

  /// 获取当前时段的时间上下文（给 AI）
  Map<String, dynamic> getTimeContext() {
    return {
      'day': _currentDay,
      'weekday': weekdayName,
      'is_weekend': isWeekend,
      'season': _currentSeason,
      'weather': _currentWeather,
      'phase': currentPhase,
      'is_special_day': isSpecialDay,
      'special_day': currentSpecialDay,
    };
  }

  // ═══════════════════════════════════════
  // 角色位置查询
  // ═══════════════════════════════════════

  /// 获取所有角色在当前时段的位置
  Map<String, String> getCharacterLocations() {
    final locations = <String, String>{};
    for (final char in script.characters.where((c) => c.fullCharacter)) {
      final state = scheduleService.getCharacterLocation(
        char, _currentDay, currentPhase, _currentSeason, _currentWeather,
      );
      locations[char.basic.id] = state?.locationId ?? '';
    }
    return locations;
  }

  /// 获取指定场景中当前在场的角色
  List<Character> getCharactersAtLocation(String locationId) {
    final locations = getCharacterLocations();
    return script.characters.where((c) {
      return c.fullCharacter && locations[c.basic.id] == locationId;
    }).toList();
  }

  // ═══════════════════════════════════════
  // 配置读取
  // ═══════════════════════════════════════

  int get totalDays {
    final tc = script.gameInteraction?.timeConfig;
    if (tc != null && tc['total_days'] is int) return tc['total_days'] as int;
    return script.interaction.totalDays;
  }

  List<Map<String, dynamic>> get _seasons {
    final s = script.gameInteraction?.seasons;
    if (s != null && s.isNotEmpty) return s;
    return [{'name': '春', 'weather': ['晴', '晴', '多云', '阴', '小雨'], 'mood': ''}];
  }

  Map<String, dynamic>? _currentSeasonMap() {
    for (final s in _seasons) {
      if (s['name'] == _currentSeason) return s;
    }
    return _seasons.isNotEmpty ? _seasons.first : null;
  }

  List<String> get _weatherPool {
    final sm = _currentSeasonMap();
    if (sm != null && sm['weather'] is List) return List<String>.from(sm['weather']);
    return const ['晴', '晴', '多云', '阴', '小雨'];
  }

  int _seasonDuration() {
    final sm = _currentSeasonMap();
    if (sm != null) {
      if (sm['days'] is int) return sm['days'] as int;
      if (sm['duration'] is int) return sm['duration'] as int;
    }
    return 15;
  }

  // ═══════════════════════════════════════
  // 初始化
  // ═══════════════════════════════════════

  void initFromScript() {
    _currentDay = script.world.memory.currentTime.day;
    _currentSeason = _seasonName(script.world.memory.currentTime.season);
    _currentWeather = script.world.memory.currentTime.weather;
    _phaseIndex = 0;
    _narrativeHistory = script.world.memory.worldSummary;
    _seasonDayCounter = 0;
    _syncWeatherToSeason();
    calendar.initFromScript(script); calendar.currentDay = _currentDay;
  }

  void setNarrativeHistory(String history) {
    _narrativeHistory = history;
  }

  Map<String, dynamic>? getNextMilestone() => calendar.getSpecialDay(_currentDay);
  bool isNearMilestone(int day) => calendar.daysUntilNextSpecialDay(_currentDay) <= 3;

  InteractionAdvanceMode? getAdvanceModeConfig(String mode) {
    return script.gameInteraction?.advanceModes[mode];
  }

  // ═══════════════════════════════════════
  // 推进主入口（保留旧接口兼容性）
  // ═══════════════════════════════════════

  Future<AdvanceResult> advance(String mode) async {
    final cfg = getAdvanceModeConfig(mode);
    final dayBefore = _currentDay;
    String narrative;

    if (cfg != null && cfg.canTriggerMilestone == true) {
      // 重要推进：跳到下一个 milestone
      final ms = calendar.getSpecialDay(_currentDay);
      if (ms != null) {
        final targetDay = ms['day'] as int;
        final skip = targetDay - _currentDay;
        _skipDays(skip);
      }
    } else {
      // 日常推进：跳过 2-4 天
      int skipDays = 2;
      final dist = calendar.daysUntilNextSpecialDay(_currentDay);
      if (dist <= 3 && dist > 0) skipDays = dist - 1;
      final remaining = totalDays - _currentDay;
      if (skipDays > remaining) skipDays = remaining;
      if (skipDays > 0) _skipDays(skipDays);
    }

    narrative = await client.generateNarrative(
      prompt: '', mode: mode, context: getTimeContext(),
      script: script, narrativeHistory: _narrativeHistory,
    );

    _narrativeHistory += '\n\n$narrative';
    _narrativeHistory = _narrativeHistory.trim();

    return AdvanceResult(
      narrative: narrative, dayBefore: dayBefore, dayAfter: _currentDay,
      daysSkipped: _currentDay - dayBefore,
    );
  }

  // ═══════════════════════════════════════
  // 底层时间推进
  // ═══════════════════════════════════════

  void _skipDays(int days) {
    for (int i = 0; i < days; i++) {
      _advanceDay();
    }
    _phaseIndex = 0;
  }

  void _advanceDay() {
    _currentDay++;
    calendar.currentDay = _currentDay;
    _seasonDayCounter++;
    _updateWeather();
    if (_seasonDayCounter >= _seasonDuration()) _advanceSeason();
    if (_currentDay > totalDays) _currentDay = totalDays;
  }

  void _advanceSeason() {
    _seasonDayCounter = 0;
    final seasons = _seasons;
    for (int i = 0; i < seasons.length; i++) {
      if (seasons[i]['name'] == _currentSeason) {
        _currentSeason = i < seasons.length - 1
            ? (seasons[i + 1]['name'] ?? _currentSeason)
            : (seasons.first['name'] ?? _currentSeason);
        _syncWeatherToSeason();
        return;
      }
    }
    if (seasons.isNotEmpty) {
      _currentSeason = seasons.first['name'] ?? _currentSeason;
      _syncWeatherToSeason();
    }
  }

  void _syncWeatherToSeason() {
    final pool = _weatherPool;
    if (pool.contains(_currentWeather)) return;
    if (pool.isNotEmpty) _currentWeather = pool.first;
  }

  void _updateWeather() {
    final pool = _weatherPool;
    if (pool.isEmpty || pool.length == 1) {
      _currentWeather = pool.isNotEmpty ? pool.first : '晴';
      return;
    }
    final weatherSchedule = _buildWeatherSchedule(pool);
    _currentWeather = weatherSchedule[_currentDay % weatherSchedule.length];
  }

  List<String> _buildWeatherSchedule(List<String> pool) {
    final seq = <String>[];
    for (int i = 0; i < 30; i++) {
      for (final w in pool) {
        if (w == '晴' || w == '多云') { seq.add(w); seq.add(w); }
        else { seq.add(w); }
      }
    }
    return seq;
  }

  String _seasonName(String s) {
    switch (s) {
      case 'spring': return '春';
      case 'summer': return '夏';
      case 'autumn': return '秋';
      case 'winter': return '冬';
      default: return s.isNotEmpty ? s : '春';
    }
  }

  // ═══════════════════════════════════════
  // 世界运转（保留）
  // ═══════════════════════════════════════

  WorldTickReport tickWorld({Map<String, double> playerAffections = const {}}) {
    final states = scheduleService.getAllLocations(
      script.characters, _currentDay, currentPhase, _currentSeason, _currentWeather,
    );
    final collisions = scheduleService.detectCollisions(states);
    final dramatic = scheduleService.pickDramaticCollision(
      script.characters, _currentDay, currentPhase, _currentSeason, _currentWeather,
      playerAffections, sceneLocations: script.events?.sceneLocations,
    );
    final drama = interCharRel.detectDrama();
    final spreads = infoProp.propagate(script.characters, interCharRel);
    final knowledge = infoProp.buildKnowledgeReport(playerAffections);
    String knowledgeSummary = '';
    if (knowledge.isNotEmpty) {
      final buf = StringBuffer();
      buf.writeln('【角色知情状态】');
      for (final e in knowledge.entries) {
        buf.writeln('${e.key} 知道: ${e.value}');
      }
      knowledgeSummary = buf.toString();
    }
    final report = WorldTickReport(
      collisions: collisions, dramaticCollision: dramatic,
      interCharDrama: drama, infoSpreads: spreads, knowledgeSummary: knowledgeSummary,
    );
    lastTickReport = report;
    return report;
  }

  String buildWorldReport(WorldTickReport report) {
    final buf = StringBuffer();
    if (report.dramaticCollision != null) {
      final dc = report.dramaticCollision!;
      buf.writeln('【日程撞车·修罗场】');
      buf.writeln('地点: ${dc['location_id']}');
      buf.writeln('在场角色: ${(dc['char_ids'] as List).join('、')}');
      buf.writeln('戏剧张力: ${dc['drama_score']}');
    }
    if (report.interCharDrama.isNotEmpty) {
      buf.writeln('【角色间关系动态】${report.interCharDrama}');
    }
    for (final spread in report.infoSpreads) {
      buf.writeln('【信息扩散】${spread.fromCharId}→${spread.toCharId}: ${spread.distortedContent} [${spread.encryptionStyle}]');
    }
    return buf.toString();
  }

  List<String> buildCollisionInfo(WorldTickReport report) {
    final lines = <String>[];
    for (final c in report.collisions) {
      final ids = c.charIds.join('、');
      lines.add('${c.locationId}: $ids 在此相遇');
    }
    if (report.dramaticCollision != null) {
      final dc = report.dramaticCollision!;
      lines.add('修罗场: ${dc['char_a']}与${dc['char_b']}在${dc['location_id']}（${dc['type']}）');
    }
    if (report.interCharDrama.isNotEmpty) {
      lines.add(report.interCharDrama);
    }
    return lines;
  }

  List<String> buildInfoKnowledgeLines(WorldTickReport report) {
    final lines = <String>[];
    for (final spread in report.infoSpreads) {
      lines.add('${spread.fromCharId}→${spread.toCharId}: ${spread.distortedContent} [${spread.encryptionStyle}]');
    }
    if (report.knowledgeSummary.isNotEmpty) {
      lines.add(report.knowledgeSummary);
    }
    return lines;
  }
}
