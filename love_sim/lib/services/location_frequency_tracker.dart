import 'dart:convert';

class LocationFrequencyRecord {
  final int day;
  final String charId;
  final String locationId;

  LocationFrequencyRecord({
    required this.day,
    required this.charId,
    required this.locationId,
  });

  Map<String, dynamic> toJson() => {
        'day': day,
        'charId': charId,
        'locationId': locationId,
      };

  factory LocationFrequencyRecord.fromJson(Map<String, dynamic> json) {
    return LocationFrequencyRecord(
      day: json['day'] as int,
      charId: json['charId'] as String,
      locationId: json['locationId'] as String,
    );
  }
}

class LocationFrequencyTracker {
  final List<LocationFrequencyRecord> _history = [];
  final Set<String> _knownFrequentLocations = {};

  int get historyLength => _history.length;

  LocationFrequencyTracker();

  void record(String charId, String locationId, int day) {
    _history.add(LocationFrequencyRecord(
      charId: charId,
      locationId: locationId,
      day: day,
    ));
    if (_history.length > 200) {
      _history.removeAt(0);
    }
  }

  void setFrequentLocation(String charId, String locationId, int day) {
    final key = '${charId}_$locationId';
    if (_knownFrequentLocations.contains(key)) return;
    _knownFrequentLocations.add(key);
  }

  int recentFrequency(String charId, String locationId, int days) {
    final cutoff = _currentDay - days;
    final key = '${charId}_$locationId';
    if (!_knownFrequentLocations.contains(key)) return 0;
    int count = 0;
    for (final r in _history.reversed) {
      if (r.day <= cutoff) break;
      if (r.charId == charId && r.locationId == locationId) count++;
    }
    return count;
  }

  bool isPlayerVisitingTargetFrequentSpot(String playerId, String targetCharId, String currentLocation, int threshold) {
    final key = '${targetCharId}_$currentLocation';
    if (!_knownFrequentLocations.contains(key)) return false;
    final freq = recentFrequency(playerId, currentLocation, 7);
    return freq >= threshold;
  }

  String? targetCharTodayLocation(String targetCharId, int day) {
    for (final r in _history.reversed) {
      if (r.charId == targetCharId && r.day == day) {
        return r.locationId;
      }
    }
    return null;
  }

  bool isPatternBreak(String charId, int day, String primaryLocation) {
    final today = targetCharTodayLocation(charId, day);
    if (today == null) return false;
    if (today == primaryLocation) return false;
    final key = '${charId}_$primaryLocation';
    if (!_knownFrequentLocations.contains(key)) return false;
    return true;
  }

  int _currentDay = 0;
  void setDay(int day) => _currentDay = day;

  String buildHooks(String playerId, List<String> targetCharIds, Map<String, String> charFrequentLocations, int day, String currentPlayerLocation) {
    final buf = StringBuffer();
    for (final charId in targetCharIds) {
      final primaryLoc = charFrequentLocations[charId];
      if (primaryLoc != null && isPlayerVisitingTargetFrequentSpot(playerId, charId, currentPlayerLocation, 3)) {
        buf.writeln('日程频率：你本周内多次出现在${charId}常去的$currentPlayerLocation。');
      }
      if (primaryLoc != null && isPatternBreak(charId, day, primaryLoc)) {
        final today = targetCharTodayLocation(charId, day);
        buf.writeln('日程异常：${charId}今天没有去她的常去地点$primaryLoc，而是去了$today。');
      }
    }
    return buf.toString();
  }

  Map<String, dynamic> toJson() => {
        'history': _history.map((r) => r.toJson()).toList(),
        'knownFrequentLocations': _knownFrequentLocations.toList(),
      };

  factory LocationFrequencyTracker.fromJson(Map<String, dynamic> json) {
    final t = LocationFrequencyTracker();
    final historyList = json['history'] as List?;
    if (historyList != null) {
      for (final h in historyList) {
        t._history.add(LocationFrequencyRecord.fromJson(h as Map<String, dynamic>));
      }
    }
    final locs = json['knownFrequentLocations'] as List?;
    if (locs != null) {
      for (final l in locs) {
        t._knownFrequentLocations.add(l.toString());
      }
    }
    return t;
  }
}
