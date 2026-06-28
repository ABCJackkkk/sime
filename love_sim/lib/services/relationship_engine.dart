import 'package:love_sim/services/affection_engine.dart';

enum RelationshipState {
  none(0, '死敌'),
  stranger(10, '仇视'),
  acquaintance(30, '厌恶'),
  friend(50, '陌生'),
  closeFriend(70, '好友'),
  crush(80, '暧昧'),
  lover(90, '恋人'),
  partner(100, '唯一');

  final double minAffection;
  final String label;
  const RelationshipState(this.minAffection, this.label);

  static RelationshipState fromAffection(double affection, RelationshipState? current) {
    if (affection >= 90) return RelationshipState.partner;
    if (affection >= 80) return (current == RelationshipState.lover || current == RelationshipState.partner) ? RelationshipState.lover : RelationshipState.crush;
    if (affection >= 70) return current == RelationshipState.lover || current == RelationshipState.partner ? current! : RelationshipState.crush;
    if (affection >= 60) return RelationshipState.closeFriend;
    if (affection >= 40) return RelationshipState.friend;
    if (affection >= 20) return RelationshipState.acquaintance;
    if (affection >= 10) return RelationshipState.stranger;
    return RelationshipState.none;
  }
}

class Relationship {
  final String charId;
  RelationshipState state;
  bool isConfirmed;
  final List<String> knownBy;
  DateTime? confirmedAt;

  Relationship({
    required this.charId,
    this.state = RelationshipState.none,
    this.isConfirmed = false,
    List<String>? knownBy,
    this.confirmedAt,
  }) : knownBy = knownBy ?? [];
}

class RelationChangeEvent {
  final String charId;
  final RelationshipState from;
  final RelationshipState to;
  final String reason;
  final DateTime timestamp;
  RelationChangeEvent({required this.charId, required this.from, required this.to, required this.reason}) : timestamp = DateTime.now();
}

class RelationshipEngine {
  final AffectionEngine _affection;
  final Map<String, Relationship> _relationships = {};
  final List<RelationChangeEvent> _history = [];

  RelationshipEngine(this._affection);

  Map<String, Relationship> get all => Map.unmodifiable(_relationships);

  Relationship? get(String charId) => _relationships[charId];

  RelationshipState? getState(String charId) => _relationships[charId]?.state;
  String getRelationshipType(String charId) => _relationships[charId]?.state.label ?? '无';

  bool isLoverOrPartner(String charId) {
    final s = _relationships[charId]?.state;
    return s == RelationshipState.lover || s == RelationshipState.partner;
  }

  List<String> get loverIds => _relationships.entries.where((e) => isLoverOrPartner(e.key)).map((e) => e.key).toList();

  List<String> get crushIds => _relationships.entries.where((e) => e.value.state == RelationshipState.crush).map((e) => e.key).toList();

  bool hasMultiLovers() => loverIds.length >= 2;

  bool characterKnowsAbout(String knowerId, String otherId) {
    final r = _relationships[otherId];
    if (r == null || !r.isConfirmed) return false;
    return r.knownBy.contains(knowerId);
  }

  List<String> whoKnowsAbout(String charId) {
    final r = _relationships[charId];
    if (r == null || !r.isConfirmed) return [];
    return List.unmodifiable(r.knownBy);
  }

  List<RelationChangeEvent> get history => List.unmodifiable(_history);

  void init(String charId, double affection) {
    _relationships[charId] = Relationship(charId: charId, state: RelationshipState.fromAffection(affection, null));
  }

  void syncFromAffection(String charId) {
    final aff = _affection.getAffection(charId);
    final rel = _relationships[charId];
    if (rel == null) {
      init(charId, aff);
      return;
    }

    RelationshipState newState;
    if (rel.isConfirmed && (rel.state == RelationshipState.lover || rel.state == RelationshipState.partner)) {
      newState = aff >= 100 ? RelationshipState.partner : rel.state;
      if (aff < 70) {
        newState = RelationshipState.fromAffection(aff, null);
        rel.isConfirmed = false;
        _history.add(RelationChangeEvent(charId: charId, from: rel.state, to: newState, reason: '好感度跌破底线，关系自行破裂'));
      }
    } else {
      newState = RelationshipState.fromAffection(aff, rel.state);
    }

    if (newState != rel.state) {
      _history.add(RelationChangeEvent(charId: charId, from: rel.state, to: newState, reason: '好感度变化触发关系状态更新'));
      rel.state = newState;
    }
  }

  RelationChangeEvent? confirmLover(String charId) {
    final rel = _relationships[charId];
    if (rel == null) return null;
    final oldState = rel.state;
    rel.state = RelationshipState.lover;
    rel.isConfirmed = true;
    rel.confirmedAt = DateTime.now();
    final event = RelationChangeEvent(charId: charId, from: oldState, to: RelationshipState.lover, reason: '告白/确立关系事件触发');
    _history.add(event);
    return event;
  }

  RelationChangeEvent? upgradeToPartner(String charId) {
    final rel = _relationships[charId];
    if (rel == null || !rel.isConfirmed) return null;
    final oldState = rel.state;
    rel.state = RelationshipState.partner;
    final event = RelationChangeEvent(charId: charId, from: oldState, to: RelationshipState.partner, reason: '关系升级至伴侣');
    _history.add(event);
    return event;
  }

  void markKnownBy(String knowerId, String targetId) {
    final rel = _relationships[targetId];
    if (rel == null || !rel.isConfirmed) return;
    if (!rel.knownBy.contains(knowerId)) {
      rel.knownBy.add(knowerId);
    }
  }

  String buildRelationContextForPrompt() {
    final buf = StringBuffer();
    final lovers = loverIds;
    final crushes = crushIds;

    if (lovers.isEmpty && crushes.isEmpty) return '';

    buf.writeln('【关系状态】');
    for (final id in lovers) {
      final r = _relationships[id]!;
      final knownBy = r.knownBy.isNotEmpty ? '（已知者: ${r.knownBy.join('、')}）' : '（秘密关系）';
      buf.writeln('与$id: ${r.state.label}$knownBy');
    }
    for (final id in crushes) {
      final r = _relationships[id]!;
      buf.writeln('与$id: ${r.state.label}（未确立）');
    }

    if (lovers.length >= 2) {
      buf.writeln('⚠ 多恋人关系活跃中。存在修罗场风险——当恋人们互相得知对方存在时将触发冲突事件。');
    }

    buf.writeln();
    return buf.toString();
  }

  Map<String, dynamic> toJson() {
    final rels = <String, Map<String, dynamic>>{};
    for (final entry in _relationships.entries) {
      rels[entry.key] = {
        'state': entry.value.state.name,
        'is_confirmed': entry.value.isConfirmed,
        'known_by': entry.value.knownBy,
        'confirmed_at': entry.value.confirmedAt?.toIso8601String(),
      };
    }
    return {'relationships': rels, 'history': _history.map((e) => {'char_id': e.charId, 'from': e.from.name, 'to': e.to.name, 'reason': e.reason}).toList()};
  }

  void fromJson(Map<String, dynamic> json) {
    _relationships.clear();
    _history.clear();
    final rels = json['relationships'] as Map<String, dynamic>? ?? {};
    for (final entry in rels.entries) {
      final d = entry.value as Map<String, dynamic>;
      _relationships[entry.key] = Relationship(
        charId: entry.key,
        state: RelationshipState.values.firstWhere((s) => s.name == d['state'], orElse: () => RelationshipState.none),
        isConfirmed: d['is_confirmed'] ?? false,
        knownBy: List<String>.from(d['known_by'] ?? []),
        confirmedAt: d['confirmed_at'] != null ? DateTime.tryParse(d['confirmed_at']) : null,
      );
    }
  }
}
