import 'package:love_sim/models/script.dart';

class _TierRange {
  final double low;
  final double high;
  const _TierRange(this.low, this.high);
}

class AffectionTier {
  final double lower;
  final double upper;
  final String range;
  final String description;

  const AffectionTier({
    required this.lower,
    required this.upper,
    required this.range,
    required this.description,
  });

  String get label {
    if (lower >= 100) return '永恒唯一';
    if (lower >= 90) return '爱';
    if (lower >= 80) return '喜欢';
    if (lower >= 70) return '欣赏';
    if (lower >= 60) return '有好感';
    if (lower >= 50) return '陌生人';
    if (lower >= 40) return '轻微厌恶';
    if (lower >= 30) return '厌恶';
    if (lower >= 20) return '憎恨';
    if (lower >= 10) return '仇恨';
    return '死敌';
  }
}

class AffectionEngine {
  final GameScript script;
  final InteractionAffection _affectionConfig;

  final Map<String, double> _states = {};
  final Map<String, double> _breakthroughFlags = {};
  final Map<String, bool> _eventsReported = {};
  String? _uniqueBondCharId;

  static const List<double> _defaultTierCaps = [20, 40, 60, 80, 90, 100];
  static const double _defaultFreeFall = 80.0;
  static const double _uniqueBondClamp = 98.0;

  late final List<double> _configTiers;
  late final double _freeFallThreshold;

  AffectionEngine({required this.script, InteractionAffection? affectionConfig})
      : _affectionConfig = affectionConfig ?? _resolveAffectionConfig(script) {
    final raw = _affectionConfig.tiers.isNotEmpty
        ? List<double>.from(_affectionConfig.tiers)
        : <double>[];
    raw.sort();
    _configTiers = raw;
    _freeFallThreshold = _parseFreeFallThreshold();
  }

  static InteractionAffection _resolveAffectionConfig(GameScript script) {
    final gi = script.gameInteraction;
    if (gi != null && gi.affection.min > 0) {
      return gi.affection;
    }
    return script.gameInteraction?.affection ?? InteractionAffection();
  }

  double _parseFreeFallThreshold() {
    for (final key in _affectionConfig.declineRules.keys) {
      final match = RegExp(r'below[_\s]*(\d+(?:\.\d+)?)').firstMatch(key);
      if (match != null) {
        final v = double.tryParse(match.group(1)!);
        if (v != null) return v;
      }
    }
    return _defaultFreeFall;
  }

  void init(String charId, double val) {
    _states[charId] = val.clamp(0.0, _affectionConfig.max);
    _breakthroughFlags.remove(charId);
    _eventsReported.remove(charId);
  }

  double getAffection(String charId) => _states[charId] ?? 50.0;

  String? get uniqueBondCharId => _uniqueBondCharId;

  bool hasUniqueBond() =>
      _affectionConfig.uniqueBond.isNotEmpty && _uniqueBondCharId != null;

  List<double> _getTierCaps(String charId) {
    if (_configTiers.isNotEmpty) return _configTiers;

    final char = _getChar(charId);
    if (char?.evolution != null &&
        char!.evolution!.affectionStages.isNotEmpty) {
      final caps = <double>[];
      for (final stage in char.evolution!.affectionStages) {
        final parts = stage.range.split('-');
        if (parts.length == 2) {
          final hi = double.tryParse(parts[1].trim());
          if (hi != null && hi > 0) caps.add(hi);
        } else {
          final v = double.tryParse(stage.range.trim());
          if (v != null && v > 0) caps.add(v);
        }
      }
      if (caps.isNotEmpty) {
        caps.sort();
        return caps;
      }
    }
    return _defaultTierCaps;
  }

  List<AffectionTier> getTiers(String charId) {
    final tiers = <AffectionTier>[];
    final caps = _getTierCaps(charId);
    double prev = 0;
    for (final cap in caps) {
      tiers.add(AffectionTier(
          lower: prev, upper: cap, range: '$prev-$cap', description: ''));
      prev = cap;
    }
    final char = _getChar(charId);
    if (char?.evolution != null) {
      for (int i = 0;
          i < tiers.length && i < char!.evolution!.affectionStages.length;
          i++) {
        tiers[i] = AffectionTier(
          lower: tiers[i].lower,
          upper: tiers[i].upper,
          range: tiers[i].range,
          description: char.evolution!.affectionStages[i].narrativeHint,
        );
      }
    }
    final capsForDesc = caps.map((c) => c.toStringAsFixed(0)).toList();
    for (int i = 0; i < tiers.length && i < capsForDesc.length; i++) {
      final key = capsForDesc[i];
      final desc = _affectionConfig.tiersDesc[key];
      if (desc != null && desc.isNotEmpty && tiers[i].description.isEmpty) {
        tiers[i] = AffectionTier(
          lower: tiers[i].lower,
          upper: tiers[i].upper,
          range: tiers[i].range,
          description: desc,
        );
      }
    }
    return tiers;
  }

  AffectionTier getCurrentTier(String charId) {
    final val = getAffection(charId);
    final tiers = getTiers(charId);
    for (final t in tiers) {
      if (val >= t.lower && val < t.upper) return t;
    }
    return tiers.isNotEmpty
        ? tiers.last
        : const AffectionTier(
            lower: 90, upper: 100, range: '90-100', description: '');
  }

  double getNextTierCap(String charId) {
    final val = getAffection(charId);
    final caps = _getTierCaps(charId);
    for (final cap in caps) {
      if (val < cap) return cap;
    }
    return _affectionConfig.max;
  }

  bool canBreakThrough(String charId) {
    final val = getAffection(charId);
    final cap = getNextTierCap(charId);
    return val >= cap * 0.97 && _breakthroughFlags[charId] == null;
  }

  bool needsBreakthrough(String charId) {
    final val = getAffection(charId);
    final cap = getNextTierCap(charId);
    if (cap >= _affectionConfig.max) return false;
    return val >= cap - 1.0 && _breakthroughFlags[charId] == null;
  }

  bool isEventReported(String charId) => _eventsReported[charId] ?? false;

  void markEventReported(String charId) {
    _eventsReported[charId] = true;
  }

  InteractionAffectionTier? getBreakthroughRule(String charId) {
    final cap = getNextTierCap(charId);
    final key = cap.toStringAsFixed(0);
    return _affectionConfig.tierBreakthrough[key];
  }

  double modifyAffectionByChat(String charId, double rawDelta) {
    final current = getAffection(charId);
    double delta = rawDelta;

    if (delta < 0 && current < _freeFallThreshold) {
      if (current + delta < 0) delta = -current;
      _states[charId] = (current + delta).clamp(0.0, _affectionConfig.max);
      return _states[charId]!;
    }

    delta = _applyDifficulty(current, delta);

    if (delta > 0) {
      final cap = getNextTierCap(charId);
      if (current + delta > cap) {
        delta = (cap - current - _affectionConfig.precision)
            .clamp(0.0, _affectionConfig.max);
        _breakthroughFlags[charId] = cap;
      }
    }

    if (delta < 0 && current >= _freeFallThreshold) {
      final tierLow = getCurrentTier(charId).lower;
      if (current + delta < tierLow) {
        delta = tierLow - current;
      }
    }

    final newVal =
        (current + delta).clamp(0.0, _affectionConfig.max);
    final clamped = _applyUniqueBond(charId, newVal, current);
    _states[charId] = clamped;
    _checkUniqueBondEffect(charId);

    return _states[charId]!;
  }

  double modifyAffectionByEvent(String charId, double rawDelta) {
    final current = getAffection(charId);
    double delta = rawDelta;

    delta = _applyDifficulty(current, delta);

    if (delta > 0) {
      final cap = getNextTierCap(charId);
      final didBreakThrough =
          (current + delta) >= cap && cap < _affectionConfig.max;
      _states[charId] =
          (current + delta).clamp(0.0, _affectionConfig.max);
      if (didBreakThrough) {
        _breakthroughFlags.remove(charId);
      }
    } else {
      if (current < _freeFallThreshold) {
        _states[charId] =
            (current + delta).clamp(0.0, _affectionConfig.max);
      } else {
        _states[charId] =
            (current + delta).clamp(_freeFallThreshold, _affectionConfig.max);
      }
    }

    final clamped = _applyUniqueBond(charId, _states[charId]!, current);
    _states[charId] = clamped;
    _checkUniqueBondEffect(charId);

    return _states[charId]!;
  }

  double _applyDifficulty(double current, double delta) {
    if (delta > 0) {
      final multiplier = _getGainMultiplier(current);
      return delta * multiplier;
    }
    if (delta < 0) {
      final multiplier = _getDeclineMultiplier(current);
      return delta * multiplier;
    }
    return 0.0;
  }

  double _getGainMultiplier(double affection) {
    final entries = _affectionConfig.gainMultiplier.entries.toList();
    for (final entry in entries) {
      final range = _parseRange(entry.key);
      if (range != null &&
          affection >= range.low &&
          affection < range.high) {
        return entry.value.multiplier;
      }
    }
    for (final entry in entries) {
      final range = _parseRange(entry.key);
      if (range != null &&
          affection >= range.low &&
          _approxEqual(affection, range.high) &&
          range.high >= _affectionConfig.max) {
        return entry.value.multiplier;
      }
    }
    return 1.0;
  }

  double _getDeclineMultiplier(double affection) {
    for (final entry in _affectionConfig.declineMultiplier.entries) {
      final range = _parseRange(entry.key);
      if (range != null &&
          affection >= range.low &&
          affection < range.high) {
        return entry.value.multiplier;
      }
    }
    for (final entry in _affectionConfig.declineMultiplier.entries) {
      final range = _parseRange(entry.key);
      if (range != null &&
          affection >= range.low &&
          _approxEqual(affection, range.high) &&
          range.high >= _affectionConfig.max) {
        return entry.value.multiplier;
      }
    }
    return 1.0;
  }

  bool _approxEqual(double a, double b) {
    return (a - b).abs() < _affectionConfig.precision;
  }

  _TierRange? _parseRange(String key) {
    final parts = key.split('-');
    if (parts.length == 2) {
      final low = double.tryParse(parts[0].trim());
      final high = double.tryParse(parts[1].trim());
      if (low != null && high != null) return _TierRange(low, high);
    }
    return null;
  }

  double _applyUniqueBond(String charId, double newVal, double current) {
    if (_affectionConfig.uniqueBond.isEmpty) return newVal;

    if (newVal >= _affectionConfig.max) {
      if (_uniqueBondCharId != null && _uniqueBondCharId != charId) {
        return _uniqueBondClamp;
      }
    } else if (_uniqueBondCharId != null &&
        _uniqueBondCharId != charId &&
        newVal > _uniqueBondClamp) {
      return _uniqueBondClamp;
    }

    return newVal;
  }

  void _checkUniqueBondEffect(String charId) {
    if (_affectionConfig.uniqueBond.isEmpty) return;
    final val = _states[charId] ?? 0;
    if (val >= _affectionConfig.max) {
      _uniqueBondCharId ??= charId;
    }
  }

  void breakUniqueBond() {
    _uniqueBondCharId = null;
  }

  Character? _getChar(String charId) {
    try {
      return script.characters.firstWhere((c) => c.basic.id == charId);
    } catch (_) {
      return null;
    }
  }
}
