import 'package:love_sim/models/script.dart';
import 'package:love_sim/services/game_session.dart';
import 'package:love_sim/services/world_engine.dart';
import 'package:love_sim/services/deepseek_client.dart';
import 'package:love_sim/services/character_memory_service.dart';
import 'package:love_sim/services/calendar_service.dart';
import 'package:love_sim/services/ranking_service.dart';

/// 时段行动服务 —— 场景预览、场景行动、角色互动
/// 与 GameSession 解耦，不修改 session 核心代码
class PhaseActionService {
  final GameSession session;
  PhaseActionService(this.session);

  GameScript? get script => session.script;
  WorldEngine? get worldEngine => session.worldEngine;
  DeepSeekClient? get deepSeekClient => session.deepSeekClient;
  CharacterMemoryService? get charMemory => session.charMemory;
  CalendarService? get calendar => worldEngine?.calendar;
  String get currentDay => session.currentDay.replaceAll(' ', '');
  String get currentPhase => session.currentPhase;
  String get currentWeather => session.currentWeather;
  String get currentSeason => session.currentSeason;

  void _syncSessionTime() {
    if (worldEngine == null) return;
    session.setDay(worldEngine!.currentDay.toString());
    session.setPhase(worldEngine!.currentPhase);
    session.setWeather(worldEngine!.currentWeather);
    session.setSeason(worldEngine!.currentSeason);
    // 检查考试
    _checkExam(worldEngine!.currentDay);
  }

  void _checkExam(int day) {
    final rs = session.rankingService;
    final dl = script?.dataLayer;
    if (rs == null || dl == null) return;
    if (!rs.shouldTriggerExam(day, dl.ranking, dl.memory)) return;
    // 考试触发——更新 playerStats/playerGrades
    rs.processExam(day, '考试', dl.ranking, dl.stats, dl.grades,
      session.playerStats, session.playerGrades,
      script?.characters ?? [], session.affectionStates,
      gradeFormulas: dl.gradeFormulas, naturalGrowthRate: dl.naturalGrowthRate,
    );
    dl.memory.lastRankingDay = day;
  }

  bool isDiscovered(String charId) {
    final disc = (session as dynamic).discoveredChars;
    return disc == null || disc.contains(charId);
  }

  /// 预览场景（不消耗时段）
  Future<Map<String, dynamic>> previewLocation(String locationId) async {
    if (worldEngine == null || deepSeekClient == null || script == null) return {};
    final loc = script!.world.locations.firstWhere((l) => l['id'] == locationId, orElse: () => {'name': locationId, 'desc': ''});
    final chars = worldEngine!.getCharactersAtLocation(locationId);
    final charNames = chars.map((c) => c.basic.name).join('、');
    final narrative = await deepSeekClient!.generateNarrative(
      prompt: '玩家来到了${loc['name']}。${charNames.isNotEmpty ? "在场角色：$charNames。" : "这里没有人。"}仅描述场景氛围和在场的人，不要推进剧情。100-200字。',
      mode: 'scene', context: worldEngine!.getTimeContext(), script: script!, narrativeHistory: session.narrativeHistory,
    );
    return {
      'location_id': locationId, 'location_name': loc['name'],
      'narrative': narrative, 'characters': chars.map((c) => {'id': c.basic.id, 'name': c.basic.name}).toList(),
    };
  }

  /// 在场景中行动（消耗时段）
  Future<String> actAtLocation(String locationId, String action) async {
    if (worldEngine == null || deepSeekClient == null || script == null) return '';
    session.isLoading = true; session.onChanged?.call();
    try {
      final loc = script!.world.locations.firstWhere((l) => l['id'] == locationId, orElse: () => {'name': locationId});
      final chars = worldEngine!.getCharactersAtLocation(locationId);
      final charNames = chars.map((c) => c.basic.name).join('、');
      worldEngine!.advancePhase();
      _syncSessionTime();
      final narrative = await deepSeekClient!.generateNarrative(
        prompt: '在${loc['name']}，${charNames.isNotEmpty ? "$charNames 在场。" : ""}玩家$action。',
        mode: 'scene', context: worldEngine!.getTimeContext(), script: script!, narrativeHistory: session.narrativeHistory,
      );
      return narrative;
    } finally { session.isLoading = false; session.onChanged?.call(); }
  }

  /// 与角色互动（消耗时段）
  Future<String> interactWithChar(String charId, String action) async {
    if (worldEngine == null || deepSeekClient == null || script == null) return '';
    session.isLoading = true; session.onChanged?.call();
    try {
      final char = script!.characters.firstWhere((c) => c.basic.id == charId, orElse: () => script!.characters.first);
      worldEngine!.advancePhase();
      _syncSessionTime();
      final narrative = await deepSeekClient!.generateNarrative(
        prompt: '玩家对${char.basic.name}$action。', mode: 'interact', context: worldEngine!.getTimeContext(), script: script!, narrativeHistory: session.narrativeHistory,
      );
      session.modifyAffectionByChat(charId, 0.5);
      return narrative;
    } finally { session.isLoading = false; session.onChanged?.call(); }
  }

  /// 度过当前时段
  Future<String> passPhase() async {
    if (worldEngine == null || deepSeekClient == null || script == null) return '';
    session.isLoading = true; session.onChanged?.call();
    try {
      worldEngine!.advancePhase();
      _syncSessionTime();
      final narrative = await deepSeekClient!.generateNarrative(
        prompt: '', mode: 'phase_pass', context: worldEngine!.getTimeContext(), script: script!, narrativeHistory: session.narrativeHistory,
      );
      return narrative;
    } finally { session.isLoading = false; session.onChanged?.call(); }
  }

  List<Map<String, dynamic>> getAvailableInteractions(String locationId) {
    if (worldEngine == null || script == null) return [];
    return worldEngine!.getCharactersAtLocation(locationId).map((c) => {
      'id': c.basic.id, 'name': c.basic.name, 'affection': session.getAffection(c.basic.id),
    }).toList();
  }


  /// 获取当前时段可用的训练动作（从剧本 JSON 读取）
  List<Map<String, dynamic>> getAvailableTraining() {
    final actions = <Map<String, dynamic>>[];
    final training = script?.dataLayer?.training;
    if (training == null) return actions;
    final phase = worldEngine?.currentPhase ?? '';
    final raw = training['actions'] as List? ?? [];
    for (final a in raw) {
      if (a is Map) {
        final phases = List<String>.from(a['phases'] ?? []);
        if (phases.contains(phase)) actions.add(Map<String, dynamic>.from(a));
      }
    }
    return actions;
  }

  /// 执行训练（消耗 1 时段）
  Future<Map<String, dynamic>> doTraining(String trainingId) async {
    if (worldEngine == null || deepSeekClient == null || script == null) return {};
    session.isLoading = true; session.onChanged?.call();
    try {
      final training = script?.dataLayer?.training;
      Map? action;
      for (final a in (training?['actions'] as List? ?? [])) {
        if (a is Map && a['id'] == trainingId) { action = Map<String, dynamic>.from(a); break; }
      }
      if (action == null) return {};

      worldEngine!.advancePhase();
      _syncSessionTime();

      final gains = <String, double>{};
      final stats = session.playerStats;
      final grades = session.playerGrades;
      final targetStat = action['target_stat']?.toString() ?? '';
      final gain = (action['gain'] as num?)?.toDouble() ?? 2;
      if (targetStat.isNotEmpty) {
        stats[targetStat] = (stats[targetStat] ?? 0) + gain;
        gains[targetStat] = gain;
      }
      final targetStat2 = action['target_stat2']?.toString() ?? '';
      final gain2 = (action['gain2'] as num?)?.toDouble();
      if (targetStat2.isNotEmpty && gain2 != null) {
        stats[targetStat2] = (stats[targetStat2] ?? 0) + gain2;
        gains[targetStat2] = gain2;
      }
      final targetGrade = action['target_grade']?.toString() ?? '';
      final gradeGain = (action['grade_gain'] as num?)?.toDouble() ?? 1;
      if (targetGrade.isNotEmpty) {
        grades[targetGrade] = (grades[targetGrade] ?? 0) + gradeGain;
        gains[targetGrade] = gradeGain;
      }

      final name = action['name']?.toString() ?? '训练';
      final gainDesc = gains.entries.map((e) => e.key + "+" + e.value.toStringAsFixed(0)).join(", ");
      final narrative = await deepSeekClient!.generateNarrative(
        prompt: '玩家进行了$name。进度：$gainDesc。50-100字简述。',
        mode: 'scene', context: worldEngine!.getTimeContext(), script: script!, narrativeHistory: session.narrativeHistory,
      );
      session.appendNarrative(narrative);
      return {'narrative': narrative, 'gains': gains};
    } finally { session.isLoading = false; session.onChanged?.call(); }
  }

    /// 跳过 N 天，跳到目标天子时 + AI 简述 + 数据推进
  Future<String> skipDays(int days) async {
    if (worldEngine == null || deepSeekClient == null || script == null) return '';
    session.isLoading = true; session.onChanged?.call();
    try {
      final dayBefore = worldEngine!.currentDay;
      final events = <String>[];

      for (int d = 0; d < days; d++) {
        final phasesPerDay = calendar?.getPhaseNames(worldEngine!.currentDay).length ?? 12;
        for (int p = 0; p < phasesPerDay; p++) {
          worldEngine!.advancePhase();
        }
        final sd = calendar?.getSpecialDay(worldEngine!.currentDay);
        if (sd != null) {
          events.add('第${worldEngine!.currentDay}天 ${sd['name']}（${sd['type']}）：${sd['description'] ?? ''}');
        }
      }

      // 强制时间同步
      session.setDay(worldEngine!.currentDay.toString());
      session.setPhase(worldEngine!.currentPhase);
      session.setWeather(worldEngine!.currentWeather);
      session.setSeason(worldEngine!.currentSeason);

      final examResult = _processExamsInRange(dayBefore, worldEngine!.currentDay);
      if (examResult.isNotEmpty) events.add(examResult);

      // 自然好感变化
      for (final char in script!.characters.where((c) => c.fullCharacter)) {
        final currentAff = session.getAffection(char.basic.id);
        final drift = (days * 0.02).clamp(0, 5);
        session.modifyAffectionByChat(char.basic.id, _driftDirection(currentAff) * drift);
      }

      final ctx = worldEngine!.getTimeContext();
      final bulletEvents = events.map((e) => '• $e').join('\n');
      final daysDesc = days > 365 ? '${(days/365).toStringAsFixed(1)}年' : '${days}天';
      final narrative = await deepSeekClient!.generateNarrative(
        prompt: '玩家跳过了$daysDesc（从第${dayBefore}天到第${worldEngine!.currentDay}天）。\n\n这段时间内发生的重要事件：\n$bulletEvents\n\n请以回忆的口吻，简述这段时光的主要变化：季节轮回、重要事件、关键转折、与角色的关系变化。300-500字，第二人称"你"。不要说"跳过了X天"，要像在回忆这段时光。',
        mode: 'skip_days', context: ctx, script: script!, narrativeHistory: session.narrativeHistory,
      );
      session.appendNarrative(narrative);
      return narrative;
    } finally {
      // 再次确保时间同步
      session.setDay(worldEngine?.currentDay.toString() ?? '1');
      session.setPhase(worldEngine?.currentPhase ?? '');
      session.setWeather(worldEngine?.currentWeather ?? '');
      session.setSeason(worldEngine?.currentSeason ?? '');
      session.isLoading = false;
      session.onChanged?.call();
    }
  }

  double _driftDirection(double aff) => aff > 70 ? -1.0 : (aff < 30 ? 1.0 : 0.0);

  String _processExamsInRange(int fromDay, int toDay) {
    final rs = session.rankingService;
    final dl = script?.dataLayer;
    if (rs == null || dl == null) return '';
    final events = <String>[];
    for (int d = fromDay + 1; d <= toDay; d++) {
      if (rs.shouldTriggerExam(d, dl.ranking, dl.memory)) {
        final result = rs.processExam(d, '考试', dl.ranking, dl.stats, dl.grades,
          session.playerStats, session.playerGrades,
          script?.characters ?? [], session.affectionStates,
          gradeFormulas: dl.gradeFormulas, naturalGrowthRate: dl.naturalGrowthRate,
        );
        dl.memory.lastRankingDay = d;
        if (result.playerRank > 0) {
          events.add('第${d}天考试：排名第${result.playerRank}');
        }
      }
    }
    return events.join('；');
  }
}
