import 'dart:math';
import 'package:sime/models/script.dart';
import 'package:sime/services/affection_engine.dart';
import 'package:sime/services/relationship_engine.dart';

class EventScheduler {
  final Random _rng = Random();
  final List<String> _recentEventIds = [];
  final Map<String, int> _typeCountToday = {};
  final int _maxRecent = 10;
  int _highEmotionCooldown = 0;
  int _lastEventDay = 0;

  // 角色出场追踪
  final List<String> _recentCharParticipants = [];
  final int _maxCharRecent = 8;

  final Map<String, int> _poolHistory = {};
  static const _directorBoost = 1.8;

  bool get hasHighEmotionCooldown => _highEmotionCooldown > 0;

  void onAdvance(int currentDay) {
    if (currentDay != _lastEventDay) {
      _typeCountToday.clear();
      _lastEventDay = currentDay;
    }
    if (_highEmotionCooldown > 0) _highEmotionCooldown--;
  }

  void recordEvent(EventTemplate event, {String poolName = ''}) {
    _recentEventIds.add(event.id);
    if (_recentEventIds.length > _maxRecent) _recentEventIds.removeAt(0);
    final type = _eventTypeFromPool(event);
    _typeCountToday[type] = (_typeCountToday[type] ?? 0) + 1;
    if (poolName.isNotEmpty) {
      _poolHistory[poolName] = (_poolHistory[poolName] ?? 0) + 1;
    }
    if (_isHighEmotion(event.severity)) {
      _highEmotionCooldown = 2;
    }
  }

  EventTemplate? selectEvent({
    required List<String> poolNames,
    required GameEvents events,
    required AffectionEngine affection,
    required RelationshipEngine? relationship,
    required double chaosFactor,
    required int currentDay,
  }) {
    final candidates = <EventTemplate>[];
    final weights = <double>[];

    for (final poolName in poolNames) {
      final pool = _resolvePool(events, poolName);
      for (final tpl in pool) {
        if (!_passesVarietyRule(tpl)) continue;
        if (!_passesPacingRule(tpl)) continue;
        if (!_passesConditionCheck(tpl, affection, relationship)) continue;
        candidates.add(tpl);
        double weight = tpl.weight;
        if (relationship != null) {
          if (poolName == 'love_triangle' && relationship.hasMultiLovers()) weight *= 3.0;
          if (poolName == 'love_triangle' && relationship.crushIds.length >= 2) weight *= 1.5;
        }
        if (poolName == 'boundary') weight *= 2.0;

        final poolCount = _poolHistory[poolName] ?? 0;
        final maxCount = _poolHistory.values.isEmpty ? 1 : _poolHistory.values.reduce((a, b) => a > b ? a : b);
        if (maxCount - poolCount >= 2) weight *= _directorBoost;

        weight *= (1.0 + chaosFactor * 0.5);
        weights.add(weight);
      }
    }

    if (candidates.isEmpty) return null;

    final totalWeight = weights.fold<double>(0, (s, w) => s + w);
    double roll = _rng.nextDouble() * totalWeight;
    for (int i = 0; i < candidates.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return candidates[i];
    }
    return candidates.last;
  }

  List<EventTemplate> _resolvePool(GameEvents events, String name) {
    switch (name) {
      case 'plot': return events.plotEvents;
      case 'boundary': return events.boundaryEvents;
      case 'daily': return events.dailyEvents;
      case 'sweet': case 'sweet_minor': return events.sweetMinor;
      case 'sweet_major': return events.sweetMajor;
      case 'love_triangle': return events.loveTriangle;
      case 'reversal': return events.reversal;
      case 'echo': return events.echo;
      case 'misunderstanding': return events.misunderstanding;
      case 'ensemble': return events.ensemble;
      case 'world_shift': return events.worldShift;
      case 'forced_choice': return [];
      case 'resource': return events.resource;
      case 'dialogue_trigger': return events.dialogueTrigger;
      default: return [];
    }
  }

  bool _passesVarietyRule(EventTemplate event) {
    final idCount = _recentEventIds.where((id) => id == event.id).length;
    if (idCount >= 3) return false;
    if (_recentEventIds.length >= 3 && _recentEventIds.sublist(_recentEventIds.length - 3).every((id) => id == event.id)) {
      return false;
    }
    final type = _eventTypeFromPool(event);
    final todayCount = _typeCountToday[type] ?? 0;
    if (todayCount >= 2) return false;
    return true;
  }

  bool _passesPacingRule(EventTemplate event) {
    if (_highEmotionCooldown > 0 && _isHighEmotion(event.severity)) return false;
    return true;
  }

  bool _passesConditionCheck(EventTemplate event, AffectionEngine affection, RelationshipEngine? relationship) {
    if (event.requiredChars.isNotEmpty) {
      for (final charId in event.requiredChars) {
        if (affection.getAffection(charId) < 50) return false;
      }
    }
    if (relationship != null && event.id.contains('triangle')) {
      final lovers = relationship.loverIds;
      final crushes = relationship.crushIds;
      if (lovers.length + crushes.length < 2) return false;
    }
    return true;
  }

  String _eventTypeFromPool(EventTemplate event) {
    if (event.id.startsWith('plot') || event.id.startsWith('forced') || event.id.startsWith('world')) return 'major';
    if (event.id.startsWith('boundary')) return 'boundary';
    if (event.id.startsWith('sweet')) return 'sweet';
    if (event.id.startsWith('triangle')) return 'triangle';
    return 'daily';
  }

  bool _isHighEmotion(String severity) {
    return severity == 'major';
  }

  /// 动态选择事件参与者。优先选择好感度高、最近未出场的角色。
  /// 对于 ensemble/love_triangle 事件尝试选择 2-3 个角色。
  List<String> pickParticipants({
    required EventTemplate event,
    required List<String> allCharIds,
    required AffectionEngine affection,
    required RelationshipEngine? relationship,
  }) {
    // 如果事件硬编码了角色，直接用
    if (event.requiredChars.isNotEmpty) {
      _recordCharParticipants(event.requiredChars);
      return event.requiredChars;
    }

    // 计算每个角色的出场分数
    final scores = <String, double>{};
    for (final charId in allCharIds) {
      scores[charId] = _charParticipationScore(charId, affection, relationship);
    }

    final sorted = allCharIds.toList()..sort((a, b) => scores[b]!.compareTo(scores[a]!));

    // 判断事件类型决定选几个角色
    final isEnsemble = event.id.contains('ensemble') || event.id.contains('triangle');
    final isSweet = event.id.contains('sweet');

    List<String> selected;
    if (isEnsemble && relationship != null) {
      // 修罗场/群像：优先选有关系的角色
      final lovers = relationship.loverIds;
      final crushes = relationship.crushIds;
      final related = <String>{...lovers, ...crushes};
      related.retainAll(allCharIds);
      final inOrder = related.toList()..sort((a, b) => scores[b]!.compareTo(scores[a]!));
      selected = inOrder.take(3).toList();
      if (selected.isEmpty) selected = sorted.take(2).toList();
    } else if (isSweet) {
      // 甜蜜事件：选好感度最高的 1-2 个
      selected = sorted.take(2).toList();
    } else {
      // 日常：选 1 个
      selected = sorted.take(1).toList();
    }

    _recordCharParticipants(selected);
    return selected;
  }

  double _charParticipationScore(String charId, AffectionEngine affection, RelationshipEngine? relationship) {
    final aff = affection.getAffection(charId);
    if (aff < 50) return -999;
    double score = aff * 0.5; // 好感度权重 50%

    // 最近未出场加分
    final lastIdx = _recentCharParticipants.indexOf(charId);
    if (lastIdx < 0) {
      score += 30; // 从未出场过，大加分
    } else {
      score += (lastIdx) * 3.0; // 越早出场，加分越多
    }

    // 关系状态加分
    if (relationship != null) {
      if (relationship.loverIds.contains(charId)) score += 20;
      if (relationship.crushIds.contains(charId)) score += 10;
    }

    return score;
  }

  void _recordCharParticipants(List<String> charIds) {
    for (final id in charIds) {
      _recentCharParticipants.remove(id);
    }
    _recentCharParticipants.addAll(charIds);
    while (_recentCharParticipants.length > _maxCharRecent) {
      _recentCharParticipants.removeAt(0);
    }
  }

  Map<String, dynamic> pickFreeformContext({
    required GameEvents events,
    required List<String> allCharIds,
    required AffectionEngine affection,
    required RelationshipEngine? relationship,
    required String currentPhase,
    required String currentWeather,
    required List<SceneLocation> locations,
  }) {
    final scenes = events.dailyScenes;
    if (scenes.isEmpty) {
      final event = EventTemplate(id: 'daily_auto', name: '日常', aiHint: '自由日常叙事', aiRule: 'freeform', severity: 'minor');
      final participants = pickParticipants(event: event, allCharIds: allCharIds, affection: affection, relationship: relationship);
      return _buildContextMap(locations, 'classroom_2b', currentPhase, currentWeather, '日常', participants, affection, relationship);
    }

    final candidateScenes = scenes.where((s) {
      if (s.phases.isNotEmpty && !s.phases.contains(currentPhase)) return false;
      final loc = locations.where((l) => l.id == s.locationId).firstOrNull;
      return loc != null && loc.id.isNotEmpty;
    }).toList();

    if (candidateScenes.isEmpty) {
      final fallback = scenes[_rng.nextInt(scenes.length)];
      final participants = pickParticipants(event: EventTemplate(aiRule: 'freeform'), allCharIds: allCharIds, affection: affection, relationship: relationship);
      return _buildContextMap(locations, fallback.locationId, currentPhase, currentWeather, fallback.moods.isNotEmpty ? fallback.moods.first : '日常', participants, affection, relationship);
    }

    final scene = candidateScenes[_rng.nextInt(candidateScenes.length)];
    final mood = scene.moods.isNotEmpty ? scene.moods[_rng.nextInt(scene.moods.length)] : '日常';

    final participants = pickParticipants(
      event: EventTemplate(aiRule: 'freeform'),
      allCharIds: allCharIds,
      affection: affection,
      relationship: relationship,
    );

    return _buildContextMap(locations, scene.locationId, currentPhase, currentWeather, mood, participants, affection, relationship);
  }

  Map<String, dynamic> _buildContextMap(
    List<SceneLocation> locations,
    String locationId,
    String phase,
    String weather,
    String mood,
    List<String> participants,
    AffectionEngine affection,
    RelationshipEngine? relationship,
  ) {
    final loc = locations.where((l) => l.id == locationId).firstOrNull;
    final locName = loc?.name ?? locationId;
    final locDesc = loc?.desc ?? '';

    final charDetails = <Map<String, dynamic>>[];
    for (final id in participants) {
      final aff = affection.getAffection(id);
      final tier = affection.getCurrentTier(id);
      String relLabel = '';
      if (relationship != null) {
        final relState = relationship.get(id);
        if (relState != null) relLabel = relState.state.label;
      }
      charDetails.add({
        'id': id,
        'affection': aff.toStringAsFixed(1),
        'tier': tier.label,
        'relation': relLabel,
      });
    }

    return {
      'location_name': locName,
      'location_desc': locDesc,
      'phase': phase,
      'weather': weather,
      'mood': mood,
      'participants': participants,
      'char_details': charDetails,
    };
  }

  Map<String, dynamic> toJson() => {
    'recent_event_ids': _recentEventIds,
    'type_count_today': _typeCountToday,
    'high_emotion_cooldown': _highEmotionCooldown,
    'last_event_day': _lastEventDay,
    'recent_char_participants': _recentCharParticipants,
    'pool_history': _poolHistory,
  };

  void fromJson(Map<String, dynamic> json) {
    _recentEventIds.clear();
    _recentEventIds.addAll(List<String>.from(json['recent_event_ids'] ?? []));
    _typeCountToday.clear();
    (json['type_count_today'] as Map<String, dynamic>?)?.forEach((k, v) => _typeCountToday[k] = v as int);
    _highEmotionCooldown = json['high_emotion_cooldown'] ?? 0;
    _lastEventDay = json['last_event_day'] ?? 0;
    _recentCharParticipants.clear();
    _recentCharParticipants.addAll(List<String>.from(json['recent_char_participants'] ?? []));
    _poolHistory.clear();
    (json['pool_history'] as Map<String, dynamic>?)?.forEach((k, v) => _poolHistory[k] = v as int);
  }
}
