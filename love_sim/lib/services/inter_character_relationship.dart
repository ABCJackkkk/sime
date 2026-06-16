import 'dart:math';
import 'package:love_sim/models/script.dart';

class InterCharState {
  final String label;
  final double minAffinity;
  final double maxAffinity;
  const InterCharState(this.label, this.minAffinity, this.maxAffinity);
}

class InterCharRelationshipService {
  static const _states = [
    InterCharState('死对头', -100, -60),
    InterCharState('厌恶', -60, -30),
    InterCharState('疏离', -30, -10),
    InterCharState('无感', -10, 10),
    InterCharState('认识', 10, 30),
    InterCharState('友善', 30, 60),
    InterCharState('好友', 60, 85),
    InterCharState('挚友', 85, 100),
  ];

  final Map<String, InterCharAttitude> _attitudes = {};
  final Map<String, List<String>> _interactionLog = {};
  final Random _rng = Random();

  InterCharAttitude? get(String fromId, String toId) {
    return _attitudes[_pairKey(fromId, toId)];
  }

  List<InterCharAttitude> getAllFor(String charId) {
    return _attitudes.values.where((a) => a.fromCharId == charId || a.toCharId == charId).toList();
  }

  List<InterCharAttitude> getAll() => _attitudes.values.toList();

  String _pairKey(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}__${sorted[1]}';
  }

  InterCharAttitude? _getOrCreate(String fromId, String toId) {
    final key = _pairKey(fromId, toId);
    if (_attitudes.containsKey(key)) return _attitudes[key]!;
    final att = InterCharAttitude(fromCharId: fromId, toCharId: toId, label: '无感');
    _attitudes[key] = att;
    return att;
  }

  void initFromScript(List<Character> characters) {
    final ids = characters.where((c) => c.fullCharacter).map((c) => c.basic.id).toList();
    for (int i = 0; i < ids.length; i++) {
      for (int j = i + 1; j < ids.length; j++) {
        _getOrCreate(ids[i], ids[j]);
      }
    }
  }

  void recordInteraction(String charA, String charB, String note) {
    final att = _getOrCreate(charA, charB)!;
    att.lastUpdated = DateTime.now();
    att.lastInteractionNote = note;
    att.history.isNotEmpty ? att.history += '; $note' : att.history += note;
  }

  void shiftAffinity(String charA, String charB, double delta, {String reason = ''}) {
    final att = _getOrCreate(charA, charB)!;
    att.affinity = (att.affinity + delta).clamp(-100, 100);
    att.label = _labelFor(att.affinity);
    att.lastUpdated = DateTime.now();
    if (reason.isNotEmpty) att.lastInteractionNote = reason;
  }

  void onPlayerEvent(List<String> involvedChars, Map<String, double> playerAffections, String note) {
    for (int i = 0; i < involvedChars.length; i++) {
      for (int j = i + 1; j < involvedChars.length; j++) {
        final a = involvedChars[i];
        final b = involvedChars[j];
        final affA = playerAffections[a] ?? 50;
        final affB = playerAffections[b] ?? 50;
        double delta = 0;
        if (affA > 70 && affB > 70) delta = _rng.nextDouble() * 6 - 4;
        else if (affA > 60 && affB > 60) delta = _rng.nextDouble() * 3 - 1;
        else delta = _rng.nextDouble() * 2 - 0.5;
        shiftAffinity(a, b, delta, reason: note);
      }
    }
  }

  void onWitness(String witnessId, String charA, String charB, double affectionA, double affectionB) {
    const jealousyThreshold = 70;
    if (affectionB > jealousyThreshold) {
      shiftAffinity(witnessId, charB, -_rng.nextDouble() * 5, reason: '目睹$charA与$charB亲密互动');
    }
    if (affectionA > jealousyThreshold) {
      shiftAffinity(witnessId, charA, -_rng.nextDouble() * 5, reason: '目睹$charA与$charB亲密互动');
    }
  }

  String _labelFor(double affinity) {
    for (final s in _states) {
      if (affinity >= s.minAffinity && affinity < s.maxAffinity) return s.label;
    }
    if (affinity >= 100) return _states.last.label;
    return _states.first.label;
  }

  String buildContextForPrompt() {
    final buf = StringBuffer();
    buf.writeln('【角色间关系】');
    for (final att in _attitudes.values) {
      buf.writeln('${att.fromCharId} ↔ ${att.toCharId}: ${att.label} (亲和${att.affinity.toStringAsFixed(0)})');
    }
    return buf.toString();
  }

  String detectDrama() {
    final jealousies = <String>[];
    for (final att in _attitudes.values) {
      if (att.affinity < -30) jealousies.add('${att.fromCharId}对${att.toCharId}${att.label}');
    }
    if (jealousies.isNotEmpty) return jealousies.join('；');
    final friends = <String>[];
    for (final att in _attitudes.values) {
      if (att.affinity > 60) friends.add('${att.fromCharId}与${att.toCharId}${att.label}');
    }
    return friends.isEmpty ? '' : friends.join('；');
  }

  Map<String,dynamic> toJson() => {
    'attitudes': _attitudes.values.map((a) => a.toJson()).toList(),
    'interaction_log': _interactionLog,
  };

  void fromJson(Map<String,dynamic> json) {
    _attitudes.clear();
    for (final aJson in (json['attitudes'] as List<dynamic>? ?? [])) {
      final att = InterCharAttitude.fromJson(aJson);
      _attitudes[_pairKey(att.fromCharId, att.toCharId)] = att;
    }
  }
}
