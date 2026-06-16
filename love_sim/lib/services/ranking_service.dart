import 'dart:math';
import 'package:love_sim/models/script.dart';

class RankRecord {
  final int day;
  final String eventName;
  final int playerRank;
  final int totalStudents;
  final double playerTotalScore;
  final Map<String, double> playerGrades;
  final List<CharRankEntry> charRanks;
  final int prevRank;
  RankRecord({required this.day, required this.eventName, required this.playerRank, required this.totalStudents, required this.playerTotalScore, required this.playerGrades, required this.charRanks, this.prevRank = 0});
  Map<String, dynamic> toJson() => {'day': day, 'eventName': eventName, 'playerRank': playerRank, 'totalStudents': totalStudents, 'playerTotalScore': playerTotalScore, 'playerGrades': playerGrades, 'charRanks': charRanks.map((e) => e.toJson()).toList(), 'prevRank': prevRank};
  factory RankRecord.fromJson(Map<String, dynamic> json) => RankRecord(day: json['day'] ?? 0, eventName: json['eventName'] ?? '', playerRank: json['playerRank'] ?? 0, totalStudents: json['totalStudents'] ?? 750, playerTotalScore: (json['playerTotalScore'] as num?)?.toDouble() ?? 0, playerGrades: (json['playerGrades'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {}, charRanks: (json['charRanks'] as List<dynamic>?)?.map((e) => CharRankEntry.fromJson(e)).toList() ?? [], prevRank: json['prevRank'] ?? 0);
}

class CharRankEntry {
  final String charId;
  final String charName;
  final int rank;
  final double totalScore;
  CharRankEntry({required this.charId, required this.charName, required this.rank, required this.totalScore});
  Map<String, dynamic> toJson() => {'charId': charId, 'charName': charName, 'rank': rank, 'totalScore': totalScore};
  factory CharRankEntry.fromJson(Map<String, dynamic> json) => CharRankEntry(charId: json['charId'] ?? '', charName: json['charName'] ?? '', rank: json['rank'] ?? 0, totalScore: (json['totalScore'] as num?)?.toDouble() ?? 0);
}

class RankingService {
  final Random _rng = Random(42);

  final List<RankRecord> _rankHistory = [];
  final Map<String, CharacterStat> _charStats = {};
  final Map<String, CharacterGrade> _charGrades = {};

  List<RankRecord> get rankHistory => List.unmodifiable(_rankHistory);
  RankRecord? get latestRank => _rankHistory.isNotEmpty ? _rankHistory.last : null;

  void initCharacter(String charId, List<CharacterStat> stats, List<CharacterGrade> grades) {
    for (final s in stats) { _charStats['${charId}_${s.id}'] = s; }
    for (final g in grades) { _charGrades['${charId}_${g.id}'] = g; }
  }

  double getCharStat(String charId, String statId) => _charStats['${charId}_$statId']?.value ?? 50;
  double getCharGrade(String charId, String gradeId) => _charGrades['${charId}_$gradeId']?.value ?? 100;

  bool shouldTriggerExam(int day, RankingSystemDef ranking, DataLayerMemory memory) {
    for (final evt in ranking.events) {
      if (evt.intervalDays <= 0) continue;
      final lastDay = memory.lastRankingDay;
      if (lastDay == 0) {
        if (day >= evt.intervalDays) return true;
        continue;
      }
      final lastMultiple = (lastDay ~/ evt.intervalDays) * evt.intervalDays;
      final currentMultiple = (day ~/ evt.intervalDays) * evt.intervalDays;
      if (currentMultiple > lastMultiple && day >= currentMultiple && currentMultiple >= evt.intervalDays) return true;
    }
    return false;
  }

  RankRecord processExam(int day, String eventName, RankingSystemDef ranking, List<PlayerStatDefinition> statDefs, List<PlayerGradeDefinition> gradeDefs, Map<String, double> playerStats, Map<String, double> playerGrades, List<Character> characters, Map<String, double> affectionStates, {Map<String, GradeFormula> gradeFormulas = const {}, double naturalGrowthRate = 0.02}) {
    _applyNaturalGrowth(playerStats, statDefs, naturalGrowthRate);
    _applyNaturalGrowth(playerGrades, gradeDefs, naturalGrowthRate);
    for (final c in characters) {
      _applyCharLearningGrowth(c, day);
    }

    for (final g in gradeDefs) {
      final base = playerGrades[g.id] ?? g.initial;
      final formula = gradeFormulas[g.id];
      final statBonus = formula != null ? _computeStatBonus(playerStats, formula) : 0.0;
      final variance = _rng.nextDouble() * (formula?.variance ?? 10) * 2 - (formula?.variance ?? 10);
      final newScore = (base + statBonus + variance).clamp(g.min, g.max);
      playerGrades[g.id] = newScore;
    }

    final characterScores = <_StudentScore>[];
    for (final c in characters) {
      if (!c.fullCharacter) continue;
      final scores = <String, double>{};
      var total = 0.0;
      for (final g in gradeDefs) {
        final cg = _charGrades['${c.basic.id}_$g.id'];
        final baseScore = cg?.value ?? (g.initial * 0.7 + _rng.nextDouble() * g.initial * 0.6);
        final charVariance = _rng.nextDouble() * 15 - 7.5;
        final score = (baseScore + charVariance).clamp(g.min, g.max);
        scores[g.id] = score;
        total += score;
      }
      characterScores.add(_StudentScore(charId: c.basic.id, charName: c.basic.name, grades: scores, totalScore: total, isChar: true));
    }

    final playerTotal = _calcTotal(playerGrades);
    final totalStudentEntries = ranking.totalStudents.clamp(1, 9999);
    final npcScores = _generateNpcScores(day * 7 + totalStudentEntries, totalStudentEntries - 1 - characterScores.length, gradeDefs, playerTotal, characterScores);

    final allScores = <_StudentScore>[]
      ..add(_StudentScore(charId: 'player', charName: '你', grades: Map.from(playerGrades), totalScore: playerTotal, isChar: false))
      ..addAll(characterScores)
      ..addAll(npcScores);
    allScores.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    var playerRank = 0;
    final charRanks = <CharRankEntry>[];
    for (var i = 0; i < allScores.length; i++) {
      allScores[i].rank = i + 1;
      if (allScores[i].charId == 'player') playerRank = i + 1;
      if (allScores[i].isChar) {
        charRanks.add(CharRankEntry(charId: allScores[i].charId, charName: allScores[i].charName, rank: i + 1, totalScore: allScores[i].totalScore));
      }
    }

    final prevRank = _rankHistory.isNotEmpty ? _rankHistory.last.playerRank : 0;
    final record = RankRecord(day: day, eventName: eventName, playerRank: playerRank, totalStudents: totalStudentEntries, playerTotalScore: playerTotal, playerGrades: Map.from(playerGrades), charRanks: charRanks, prevRank: prevRank);

    _rankHistory.add(record);
    if (_rankHistory.length > 20) _rankHistory.removeAt(0);
    return record;
  }

  void _applyNaturalGrowth(Map<String, double> values, List<dynamic> defs, double rate) {
    for (final d in defs) {
      final current = values[d.id] ?? d.initial;
      final growth = (d.max - current) * rate + _rng.nextDouble() * 2;
      values[d.id] = (current + growth).clamp(d.min, d.max);
    }
  }

  void applyStatBoost(Map<String, double> playerStats, List<PlayerStatDefinition> statDefs, String statId, double amount) {
    final current = playerStats[statId];
    if (current == null) return;
    final def = statDefs.where((s) => s.id == statId).firstOrNull;
    final max = def?.max ?? 100;
    playerStats[statId] = (current + amount).clamp(0, max);
  }

  void applyGradeBoost(Map<String, double> playerGrades, List<PlayerGradeDefinition> gradeDefs, String gradeId, double amount) {
    final current = playerGrades[gradeId];
    if (current == null) return;
    final def = gradeDefs.where((g) => g.id == gradeId).firstOrNull;
    final max = def?.max ?? 150;
    playerGrades[gradeId] = (current + amount).clamp(0, max);
  }

  void _applyCharLearningGrowth(Character char, int day) {
    final growthFactor = 0.005 + (day / 3000).clamp(0.0, 0.025);
    for (final entry in _charGrades.entries) {
      if (!entry.key.startsWith('${char.basic.id}_')) continue;
      final gradeId = entry.key.substring(char.basic.id.length + 1);
      final grade = char.grades?.where((g) => g.id == gradeId).firstOrNull;
      final max = grade?.max ?? 150;
      final newVal = (entry.value.value + _rng.nextDouble() * 3 * growthFactor * max).clamp(0.0, max);
      _charGrades[entry.key] = CharacterGrade(id: gradeId, name: entry.value.name, value: newVal, max: max);
    }
  }

  double _computeStatBonus(Map<String, double> stats, GradeFormula formula) {
    var bonus = 0.0;
    formula.statBonuses.forEach((statId, coeff) {
      bonus += (stats[statId] ?? 50) * coeff;
    });
    return bonus;
  }

  double _calcTotal(Map<String, double> grades) {
    var total = 0.0;
    for (final v in grades.values) { total += v; }
    return total;
  }

  List<_StudentScore> _generateNpcScores(int seed, int count, List<PlayerGradeDefinition> gradeDefs, double playerScore, List<_StudentScore> charScores) {
    final rng = Random(seed);
    final maxTotal = gradeDefs.fold(0.0, (sum, g) => sum + g.max);
    final npcs = <_StudentScore>[];

    final existingScores = <double>[playerScore, ...charScores.map((c) => c.totalScore)];

    for (var i = 0; i < count; i++) {
      var total = rng.nextDouble() * maxTotal * 0.9 + maxTotal * 0.05;
      total = (existingScores.length > 10 ? _avoidDuplicateScores(total, existingScores, rng) : total).clamp(0, maxTotal);
      final grades = <String, double>{};
      for (final g in gradeDefs) {
        grades[g.id] = (rng.nextDouble() * g.max * 0.9 + g.max * 0.05).clamp(g.min, g.max);
      }
      npcs.add(_StudentScore(charId: 'npc_$i', charName: '', grades: grades, totalScore: total, isChar: false));
    }
    return npcs;
  }

  double _avoidDuplicateScores(double score, List<double> existing, Random rng) {
    for (final existingScore in existing) {
      if ((score - existingScore).abs() < 0.5) {
        return score + rng.nextDouble() * 3 - 1.5;
      }
    }
    return score;
  }

  Map<String, dynamic> toJson() => {
    'rankHistory': _rankHistory.map((r) => r.toJson()).toList(),
    'charGrades': _charGrades.map((k, v) => MapEntry(k, v.toJson())),
    'charStats': _charStats.map((k, v) => MapEntry(k, v.toJson())),
  };

  void fromJson(Map<String, dynamic> json) {
    _rankHistory.clear();
    (json['rankHistory'] as List<dynamic>?)?.forEach((e) => _rankHistory.add(RankRecord.fromJson(e)));
    _charStats.clear();
    (json['charStats'] as Map<String, dynamic>?)?.forEach((k, v) => _charStats[k] = CharacterStat.fromJson(v));
    _charGrades.clear();
    (json['charGrades'] as Map<String, dynamic>?)?.forEach((k, v) => _charGrades[k] = CharacterGrade.fromJson(v));
  }

  Map<String, List<CharacterGrade>> getCharGradeMap(String charId) {
    final grades = <CharacterGrade>[];
    for (final entry in _charGrades.entries) {
      if (entry.key.startsWith('${charId}_')) {
        grades.add(entry.value);
      }
    }
    return {charId: grades};
  }
}

class _StudentScore {
  final String charId;
  final String charName;
  final Map<String, double> grades;
  final double totalScore;
  final bool isChar;
  int rank = 0;
  _StudentScore({required this.charId, required this.charName, required this.grades, required this.totalScore, this.isChar = false});
}
