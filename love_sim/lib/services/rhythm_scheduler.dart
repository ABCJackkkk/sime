import 'package:love_sim/models/script.dart';
import 'package:love_sim/services/world_engine.dart';
import 'package:love_sim/services/affection_engine.dart';
import 'package:love_sim/services/tension_vector.dart';

enum NarrativeWeight { light, medium, heavy, critical }

enum DramaticFocus {
  characterMoment,
  relationshipBeat,
  plotAdvancement,
  worldTexture,
  tensionEscalation,
  ensembleScene,
}

class RhythmDirective {
  final NarrativeWeight weight;
  final DramaticFocus primaryFocus;
  final DramaticFocus? secondaryFocus;
  final double tensionContribution;
  final List<String> participantIds;
  final String? locationId;
  final String? narrativeHint;

  const RhythmDirective({
    required this.weight,
    required this.primaryFocus,
    this.secondaryFocus,
    this.tensionContribution = 0.0,
    this.participantIds = const [],
    this.locationId,
    this.narrativeHint,
  });

  int get wordCount {
    switch (weight) {
      case NarrativeWeight.light:
        return 150;
      case NarrativeWeight.medium:
        return 300;
      case NarrativeWeight.heavy:
        return 500;
      case NarrativeWeight.critical:
        return 700;
    }
  }

  String get focusLabel {
    switch (primaryFocus) {
      case DramaticFocus.characterMoment:
        return '角色瞬间';
      case DramaticFocus.relationshipBeat:
        return '关系节拍';
      case DramaticFocus.plotAdvancement:
        return '主线推进';
      case DramaticFocus.worldTexture:
        return '世界质感';
      case DramaticFocus.tensionEscalation:
        return '张力升级';
      case DramaticFocus.ensembleScene:
        return '群像互动';
    }
  }
}

class RhythmScheduler {
  final TensionVector tension = TensionVector();

  RhythmDirective resolve({
    required String mode,
    required int currentDay,
    required int totalDays,
    required WorldTickReport? worldReport,
    required AffectionEngine affection,
    required List<String> allCharIds,
    required bool nearMilestone,
    required int? milestoneDay,
    required String? milestoneName,
    required GameScript script,
    required String currentPhase,
    required String currentWeather,
  }) {
    final beatHits = <_TriggerSource>[];

    _checkPlotBeat(beatHits, mode, currentDay, totalDays, script, affection, nearMilestone, milestoneDay, milestoneName);
    _checkAffectionBoundary(beatHits, affection, allCharIds);
    _checkWorldCollision(beatHits, worldReport, allCharIds);
    _checkInfoSpread(beatHits, worldReport, allCharIds);
    _checkDefaultDaily(beatHits, currentPhase, currentWeather);

    _detectReversal(beatHits);

    return _merge(beatHits);
  }

  void _checkPlotBeat(
    List<_TriggerSource> hits,
    String mode,
    int currentDay,
    int totalDays,
    GameScript script,
    AffectionEngine affection,
    bool nearMilestone,
    int? milestoneDay,
    String? milestoneName,
  ) {
    final progress = totalDays > 0 ? currentDay / totalDays : 0.0;

    if (nearMilestone) {
      hits.add(_TriggerSource(
        weight: NarrativeWeight.critical,
        focus: DramaticFocus.plotAdvancement,
        tensionContribution: 4.0,
        participantIds: _resolveTopChars(script, affection),
        hint: '临近关键事件${milestoneName != null ? "（第${milestoneDay}天${milestoneName}）" : ""}，请做氛围铺垫',
      ));
      return;
    }

    if (mode == 'major') {
      hits.add(_TriggerSource(
        weight: NarrativeWeight.heavy,
        focus: DramaticFocus.plotAdvancement,
        tensionContribution: 3.0,
        participantIds: _resolveTopChars(script, affection),
        hint: '重要推进，角色关系应有实质进展',
      ));
      return;
    }

    if (progress > 0.85) {
      hits.add(_TriggerSource(
        weight: NarrativeWeight.medium,
        focus: DramaticFocus.plotAdvancement,
        tensionContribution: 1.5,
        hint: '故事接近尾声，日常中埋下伏笔',
      ));
    }
  }

  void _checkAffectionBoundary(
    List<_TriggerSource> hits,
    AffectionEngine affection,
    List<String> allCharIds,
  ) {
    for (final charId in allCharIds) {
      final aff = affection.getAffection(charId);
      final tier = affection.getCurrentTier(charId);

      final gapToUpper = tier.upper - aff;
      if (gapToUpper <= 2.0 && gapToUpper > 0.1 && tier.upper < 100) {
        hits.add(_TriggerSource(
          weight: NarrativeWeight.heavy,
          focus: DramaticFocus.relationshipBeat,
          tensionContribution: 2.5,
          participantIds: [charId],
          hint: '好感度即将突破${tier.upper.toInt()}边界（当前$aff），这是关系转折的契机',
        ));
        return;
      }

      if (aff >= 58 && aff <= 62 && tier.upper >= 60) {
        hits.add(_TriggerSource(
          weight: NarrativeWeight.medium,
          focus: DramaticFocus.characterMoment,
          tensionContribution: 1.0,
          participantIds: [charId],
          hint: '好感度处于60附近（${aff.toInt()}），刚刚超出陌生人范围',
        ));
        return;
      }
    }
  }

  void _checkWorldCollision(
    List<_TriggerSource> hits,
    WorldTickReport? report,
    List<String> allCharIds,
  ) {
    if (report == null) return;

    final dc = report.dramaticCollision;
    if (dc != null) {
      final charA = dc['char_a'] as String? ?? '';
      final charB = dc['char_b'] as String? ?? '';
      final loc = dc['location'] as String? ?? '';
      final type = dc['type'] as String? ?? '';
      hits.add(_TriggerSource(
        weight: NarrativeWeight.medium,
        focus: DramaticFocus.ensembleScene,
        tensionContribution: 1.5,
        participantIds: [charA, charB].where((id) => id.isNotEmpty && allCharIds.contains(id)).toList(),
        locationId: loc.isNotEmpty ? loc : null,
        hint: type.isNotEmpty ? type : '${charA}和${charB}偶然相遇',
      ));
      return;
    }

    if (report.collisions.isNotEmpty) {
      final chars = <String>{};
      String? loc;
      for (final c in report.collisions) {
        chars.addAll(c.charIds);
        loc ??= c.locationId;
      }
      hits.add(_TriggerSource(
        weight: NarrativeWeight.medium,
        focus: DramaticFocus.characterMoment,
        tensionContribution: 0.8,
        participantIds: chars.where((id) => allCharIds.contains(id)).toList(),
        locationId: loc,
        hint: '几个角色在${loc ?? '某处'}不期而遇',
      ));
    }
  }

  void _checkInfoSpread(
    List<_TriggerSource> hits,
    WorldTickReport? report,
    List<String> allCharIds,
  ) {
    if (report == null || report.infoSpreads.isEmpty) return;

    final involved = <String>{};
    for (final s in report.infoSpreads) {
      if (s.toCharId.isNotEmpty) involved.add(s.toCharId);
      if (s.fromCharId.isNotEmpty) involved.add(s.fromCharId);
    }
    hits.add(_TriggerSource(
      weight: NarrativeWeight.medium,
      focus: DramaticFocus.tensionEscalation,
      tensionContribution: 1.2,
      participantIds: involved.where((id) => allCharIds.contains(id)).toList(),
      hint: report.knowledgeSummary.isNotEmpty
          ? report.knowledgeSummary
          : '校园里关于你的传言正在传播',
    ));
  }

  void _checkDefaultDaily(
    List<_TriggerSource> hits,
    String phase,
    String weather,
  ) {
    final mood = _weatherMood(weather);
    hits.add(_TriggerSource(
      weight: NarrativeWeight.light,
      focus: DramaticFocus.worldTexture,
      tensionContribution: 0.3,
      hint: '$phase的$mood日常',
    ));
  }

  void _detectReversal(List<_TriggerSource> hits) {
    if (tension.isReversalCandidate) {
      hits.add(_TriggerSource(
        weight: NarrativeWeight.critical,
        focus: DramaticFocus.tensionEscalation,
        tensionContribution: 6.0,
        hint: '反节奏爆发点——连续日常让情绪累积到临界，关系冷淡但内心不安已达${(tension.emotional * 100).toInt()}%',
      ));
    } else if (tension.isClimaxThreshold) {
      hits.add(_TriggerSource(
        weight: NarrativeWeight.critical,
        focus: DramaticFocus.tensionEscalation,
        tensionContribution: 5.0,
        hint: '双维临界爆发——关系紧张(${(tension.relational * 100).toInt()}%)和情节蓄势(${(tension.narrative * 100).toInt()}%)同时到达高位',
      ));
    }
  }

  RhythmDirective _merge(List<_TriggerSource> hits) {
    if (hits.isEmpty) {
      return const RhythmDirective(
        weight: NarrativeWeight.light,
        primaryFocus: DramaticFocus.worldTexture,
      );
    }

    hits.sort((a, b) => b.weight.index.compareTo(a.weight.index));

    final primary = hits.first;
    final secondary = hits.length > 1 ? hits[1] : null;

    final participants = <String>{};
    String? location;
    final hintLines = <String>[];
    double tension = 0;

    for (final hit in hits) {
      participants.addAll(hit.participantIds);
      location ??= hit.locationId;
      if (hit.hint != null) hintLines.add(hit.hint!);
      tension += hit.tensionContribution;
    }

    return RhythmDirective(
      weight: primary.weight,
      primaryFocus: primary.focus,
      secondaryFocus: secondary?.focus,
      tensionContribution: tension.clamp(0, 10),
      participantIds: participants.toList(),
      locationId: location,
      narrativeHint: hintLines.join('；'),
    );
  }

  List<String> _resolveTopChars(GameScript script, AffectionEngine affection) {
    final chars = script.characters.where((c) => c.fullCharacter).toList();
    if (chars.isEmpty) return [];
    chars.sort((a, b) {
      final affA = affection.getAffection(a.basic.id);
      final affB = affection.getAffection(b.basic.id);
      return affB.compareTo(affA);
    });
    return chars.take(2).map((c) => c.basic.id).toList();
  }

  String _weatherMood(String weather) {
    switch (weather) {
      case '晴':
        return '阳光明媚的';
      case '阴':
        return '阴沉沉的';
      case '雨':
        return '雨天的';
      case '雪':
        return '雪中的';
      default:
        return '';
    }
  }
}

class _TriggerSource {
  final NarrativeWeight weight;
  final DramaticFocus focus;
  final double tensionContribution;
  final List<String> participantIds;
  final String? locationId;
  final String? hint;

  _TriggerSource({
    required this.weight,
    required this.focus,
    this.tensionContribution = 0.0,
    this.participantIds = const [],
    this.locationId,
    this.hint,
  });
}
