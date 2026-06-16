import 'package:love_sim/models/script.dart';
import 'package:love_sim/services/deepseek_client.dart';
import 'package:love_sim/services/character_schedule.dart';
import 'package:love_sim/services/inter_character_relationship.dart';
import 'package:love_sim/services/information_propagation.dart';

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

/// 推进结果
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
  String _narrativeHistory = '';

  WorldEngine({required this.script, required this.client});

  int _currentDay = 1;
  String _currentPhase = '上午';
  String _currentWeather = '晴';
  String _currentSeason = '春';
  int _seasonDayCounter = 0;

  CharacterScheduleService scheduleService = CharacterScheduleService();
  InterCharRelationshipService interCharRel = InterCharRelationshipService();
  InformationPropagationService infoProp = InformationPropagationService();

  void initWorldServices() {
    interCharRel.initFromScript(script.characters);
  }

  int get currentDay => _currentDay;
  set currentDay(int v) {
    _currentDay = v;
    _seasonDayCounter = 0;
  }
  String get currentPhase => _currentPhase;
  String get currentWeather => _currentWeather;
  String get currentSeason => _currentSeason;
  String get narrativeHistory => _narrativeHistory;

  // --- 配置读取 ---

  int get _totalDays {
    final tc = script.gameInteraction?.timeConfig;
    if (tc != null && tc['total_days'] is int) return tc['total_days'] as int;
    return script.interaction.totalDays;
  }

  List<Map<String, dynamic>> get _specialDays {
    final tc = script.gameInteraction?.timeConfig;
    if (tc != null && tc['special_days'] is List) {
      return List<Map<String, dynamic>>.from(tc['special_days']);
    }
    return [];
  }

  /// 找到下一个 milestone（day > currentDay 的最小 special_day）
  Map<String, dynamic>? _findNextMilestone() {
    Map<String, dynamic>? next;
    for (final sd in _specialDays) {
      final d = sd['day'] as int?;
      if (d == null || d <= _currentDay) continue;
      if (next == null || d < (next['day'] as int)) next = sd;
    }
    return next;
  }

  List<String> get _phases {
    final tc = script.gameInteraction?.timeConfig;
    if (tc != null && tc['phases'] is List) {
      return List<String>.from(tc['phases']);
    }
    return const ['清晨', '上午', '课间', '午休', '下午', '放学', '傍晚', '晚自习'];
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
    if (sm != null && sm['weather'] is List) {
      return List<String>.from(sm['weather']);
    }
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

  // Map<String, dynamic> get _weatherProbabilities {
  //   final ws = script.gameInteraction?.weatherSystem;
  //   if (ws != null && ws['probabilities'] is Map) {
  //     return Map<String, dynamic>.from(ws['probabilities']);
  //   }
  //   return {};
  // }

  // --- 初始化 ---

  void initFromScript() {
    _currentDay = script.world.memory.currentTime.day;
    _currentSeason = _seasonName(script.world.memory.currentTime.season);
    _currentWeather = script.world.memory.currentTime.weather;
    _currentPhase = script.world.memory.currentTime.phase;
    _narrativeHistory = script.world.memory.worldSummary;
    _seasonDayCounter = 0;
    _syncWeatherToSeason();
  }

  void setNarrativeHistory(String history) {
    _narrativeHistory = history;
  }

  Map<String, dynamic> getTimeContext() {
    return {
      'day': _currentDay,
      'season': _currentSeason,
      'weather': _currentWeather,
      'phase': _currentPhase,
    };
  }

  InteractionAdvanceMode? getAdvanceModeConfig(String mode) {
    return script.gameInteraction?.advanceModes[mode];
  }

  // --- 推进主入口 ---

  Future<AdvanceResult> advance(String mode) async {
    final cfg = getAdvanceModeConfig(mode);
    final dayBefore = _currentDay;

    String narrative;
    Map<String, dynamic>? milestone;

    if (cfg != null && cfg.canTriggerMilestone == true) {
      // 重要推进：跳到下一个 milestone
      milestone = _findNextMilestone();
      if (milestone != null) {
        final targetDay = milestone['day'] as int;
        final skip = targetDay - _currentDay;
        _skipDays(skip);
        narrative = await client.generateNarrative(
          prompt: '',
          mode: mode,
          context: getTimeContext(),
          script: script,
          narrativeHistory: _narrativeHistory,
        );
      } else {
        // 没有更多 milestone，跳到末尾
        final skip = _totalDays - _currentDay;
        if (skip > 0) _skipDays(skip);
        narrative = await client.generateNarrative(
          prompt: '',
          mode: mode,
          context: getTimeContext(),
          script: script,
          narrativeHistory: _narrativeHistory,
        );
      }
    } else {
      // 日常推进：跳过 2-4 天
      int skipDays;
      if (cfg != null && cfg.timeAdvance['skip_days'] is Map) {
        final sd = cfg.timeAdvance['skip_days'] as Map;
        skipDays = (sd['min'] as int?) ?? 2;
      } else {
        skipDays = 2;
      }

      // 如果距下一个 milestone 不足 3 天，跳到 milestone 前一天
      final nextMs = _findNextMilestone();
      if (nextMs != null) {
        final dist = (nextMs['day'] as int) - _currentDay;
        if (dist <= 3) {
          skipDays = dist - 1;
          if (skipDays < 0) skipDays = 0;
        }
      }

      // 不能超过 total_days
      final remaining = _totalDays - _currentDay;
      if (skipDays > remaining) skipDays = remaining;

      if (skipDays > 0) {
        _skipDays(skipDays);
        narrative = await client.generateNarrative(
          prompt: '',
          mode: mode,
          context: getTimeContext(),
          script: script,
          narrativeHistory: _narrativeHistory,
        );
      } else {
        narrative = '';
      }
    }

    _narrativeHistory += '\n\n$narrative';
    _narrativeHistory = _narrativeHistory.trim();

    return AdvanceResult(
      narrative: narrative,
      dayBefore: dayBefore,
      dayAfter: _currentDay,
      daysSkipped: _currentDay - dayBefore,
      milestone: milestone,
    );
  }

  // --- 时间推进核心 ---

  /// 跳过 N 天
  void _skipDays(int days) {
    for (int i = 0; i < days; i++) {
      _advanceDay();
    }
    _currentPhase = _phases.isNotEmpty ? _phases.first : '上午';
  }

  void _advanceDay() {
    _currentDay++;
    _seasonDayCounter++;
    _updateWeather();

    if (_seasonDayCounter >= _seasonDuration()) {
      _advanceSeason();
    }

    // 天数上限保护
    if (_currentDay > _totalDays) {
      _currentDay = _totalDays;
    }
  }

  void _advanceSeason() {
    _seasonDayCounter = 0;
    final seasons = _seasons;
    for (int i = 0; i < seasons.length; i++) {
      if (seasons[i]['name'] == _currentSeason) {
        if (i < seasons.length - 1) {
          _currentSeason = seasons[i + 1]['name'] ?? _currentSeason;
        } else {
          _currentSeason = seasons.first['name'] ?? _currentSeason;
        }
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
        if (w == '晴' || w == '多云') {
          seq.add(w);
          seq.add(w);
        } else if (w == '阴') {
          seq.add(w);
        } else {
          seq.add(w);
        }
      }
    }
    return seq;
  }

  // String _pickWeatherFromProbabilities(Map<String, dynamic> probs) {
  //   final sorted = probs.entries.toList()..sort((a, b) => ((b.value as num).toDouble()).compareTo((a.value as num).toDouble()));
  //   final weatherSchedule = <String>[];
  //   for (int i = 0; i < 50; i++) {
  //     for (final entry in sorted) {
  //       final count = ((entry.value as num).toDouble() * 10).round().clamp(1, 10);
  //       for (int j = 0; j < count; j++) {
  //         weatherSchedule.add(entry.key);
  //       }
  //     }
  //   }
  //   return weatherSchedule[_currentDay % weatherSchedule.length];
  // }

  String _seasonName(String s) {
    switch (s) {
      case 'spring': return '春';
      case 'summer': return '夏';
      case 'autumn': return '秋';
      case 'winter': return '冬';
      default: return s.isNotEmpty ? s : '春';
    }
  }

  WorldTickReport tickWorld({Map<String, double> playerAffections = const {}}) {
    final states = scheduleService.getAllLocations(script.characters, _currentDay, _currentPhase, _currentSeason, _currentWeather);
    final collisions = scheduleService.detectCollisions(states);
    final dramatic = scheduleService.pickDramaticCollision(script.characters, _currentDay, _currentPhase, _currentSeason, _currentWeather, playerAffections);
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
    return WorldTickReport(
      collisions: collisions, dramaticCollision: dramatic,
      interCharDrama: drama, infoSpreads: spreads, knowledgeSummary: knowledgeSummary,
    );
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
}