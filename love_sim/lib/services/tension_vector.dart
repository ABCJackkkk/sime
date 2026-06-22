class TensionVector {
  double relational;
  double narrative;
  double emotional;

  TensionVector({this.relational = 10.0, this.narrative = 10.0, this.emotional = 10.0});

  double get composite => (relational + narrative + emotional) / 3.0;

  bool get isClimaxThreshold => relational > 0.7 && narrative > 0.7;

  bool get isReversalCandidate => emotional > 0.6 && relational < 0.4;

  String snapshot() {
    final buf = StringBuffer('关系紧绷${(relational * 100).toInt()} 情节蓄势${(narrative * 100).toInt()} 内心不安${(emotional * 100).toInt()}');
    if (isClimaxThreshold) buf.write(' [双维临界——爆发预警]');
    if (isReversalCandidate) buf.write(' [反节奏风险——情绪累积但关系冷淡]');
    return buf.toString();
  }

  void tickRelational(double delta) { relational = (relational + delta).clamp(0, 100); }
  void tickNarrative(double delta) { narrative = (narrative + delta).clamp(0, 100); }
  void tickEmotional(double delta) { emotional = (emotional + delta).clamp(0, 100); }

  void decayRelational(double amount) { relational = (relational - amount).clamp(0, 100); }
  void decayNarrative(double amount) { narrative = (narrative - amount).clamp(0, 100); }
  void decayEmotional(double amount) { emotional = (emotional - amount).clamp(0, 100); }

  Map<String, dynamic> toJson() => {
    'relational': relational, 'narrative': narrative, 'emotional': emotional,
  };

  factory TensionVector.fromJson(Map<String, dynamic> json) => TensionVector(
    relational: (json['relational'] as num?)?.toDouble() ?? 10.0,
    narrative: (json['narrative'] as num?)?.toDouble() ?? 10.0,
    emotional: (json['emotional'] as num?)?.toDouble() ?? 10.0,
  );

  void loadFromJson(Map<String, dynamic> json) {
    relational = (json['relational'] as num?)?.toDouble() ?? 10.0;
    narrative = (json['narrative'] as num?)?.toDouble() ?? 10.0;
    emotional = (json['emotional'] as num?)?.toDouble() ?? 10.0;
  }
}
