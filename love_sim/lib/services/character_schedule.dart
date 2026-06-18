import 'package:love_sim/models/script.dart';

class ScheduleState {
  final String charId;
  final String locationId;
  final String activity;
  final bool isScheduled;
  ScheduleState({required this.charId,required this.locationId,required this.activity,this.isScheduled=true});
}

class ScheduleCollision {
  final String locationId;
  final List<String> charIds;
  final String phase;
  ScheduleCollision({required this.locationId,required this.charIds,required this.phase});
}

class CharacterScheduleService {

  String _dayType(int day) => (day % 7 == 0 || day % 7 == 6) ? 'weekend' : 'weekday';

  List<CharacterScheduleSlot> _getSlotsForDay(CharacterSchedule schedule, int day) {
    return _dayType(day) == 'weekend' && schedule.weekend.isNotEmpty ? schedule.weekend : schedule.weekday;
  }

  bool _slotMatches(CharacterScheduleSlot slot, String phase, int day, String season, String weather) {
    if (slot.phase != phase) return false;
    for (final cond in slot.conditions) {
      if (cond == 'weekday' && _dayType(day) != 'weekday') return false;
      if (cond == 'weekend' && _dayType(day) != 'weekend') return false;
      if (cond.startsWith('season:') && cond.substring(7) != season) return false;
      if (cond == 'not_rain' && (weather == '小雨' || weather == '大雨')) return false;
    }
    return true;
  }

  ScheduleState? getCharacterLocation(Character character, int day, String phase, String season, String weather) {
    final schedule = character.schedule;
    if (schedule == null) return null;

    final slots = _getSlotsForDay(schedule, day);
    final matching = slots.where((s) => _slotMatches(s, phase, day, season, weather)).toList();

    if (matching.isEmpty) return null;

    matching.sort((a, b) => b.priority.compareTo(a.priority));
    final pick = matching.first;
    return ScheduleState(charId: character.basic.id, locationId: pick.locationId, activity: pick.activity);
  }

  List<ScheduleState> getAllLocations(List<Character> characters, int day, String phase, String season, String weather) {
    final results = <ScheduleState>[];
    for (final c in characters.where((c) => c.fullCharacter)) {
      final s = getCharacterLocation(c, day, phase, season, weather);
      if (s != null) results.add(s);
    }
    return results;
  }

  List<ScheduleCollision> detectCollisions(List<ScheduleState> states) {
    final byLocation = <String, List<ScheduleState>>{};
    for (final s in states) {
      byLocation.putIfAbsent(s.locationId, () => []).add(s);
    }
    final collisions = <ScheduleCollision>[];
    for (final entry in byLocation.entries) {
      if (entry.value.length >= 2) {
        collisions.add(ScheduleCollision(
          locationId: entry.key,
          charIds: entry.value.map((s) => s.charId).toList(),
          phase: entry.value.first.isScheduled ? 'scheduled' : 'ad_hoc',
        ));
      }
    }
    return collisions;
  }

  ScheduleCollision? findCollision(List<Character> characters, int day, String phase, String season, String weather, {String? currentLocationId}) {
    final states = getAllLocations(characters, day, phase, season, weather);
    if (currentLocationId != null) {
      for (final s in states) {
        if (s.locationId == currentLocationId) {
          return ScheduleCollision(locationId: currentLocationId, charIds: [s.charId], phase: phase);
        }
      }
    }
    final collisions = detectCollisions(states);
    if (collisions.isNotEmpty) {
      collisions.sort((a, b) {
        final countDiff = b.charIds.length.compareTo(a.charIds.length);
        if (countDiff != 0) return countDiff;
        return a.locationId.compareTo(b.locationId);
      });
      return collisions.first;
    }
    return null;
  }

  Map<String, dynamic>? pickDramaticCollision(List<Character> characters, int day, String phase, String season, String weather, Map<String, double> affections, {List<SceneLocation>? sceneLocations}) {
    final states = getAllLocations(characters, day, phase, season, weather);
    final byLocation = <String, List<ScheduleState>>{};
    for (final s in states) {
      byLocation.putIfAbsent(s.locationId, () => []).add(s);
    }

    final locProfiles = <String, LocationNarrativeProfile>{};
    if (sceneLocations != null) {
      for (final loc in sceneLocations) {
        if (loc.narrativeProfile != null) {
          locProfiles[loc.id] = loc.narrativeProfile!;
        }
      }
    }

    ScheduleCollision? best;
    double bestScore = -1;

    for (final entry in byLocation.entries) {
      if (entry.value.length < 2) continue;
      double score = 0;
      final ids = entry.value.map((s) => s.charId).toList();
      for (int i = 0; i < ids.length; i++) {
        for (int j = i + 1; j < ids.length; j++) {
          final a1 = affections[ids[i]] ?? 50;
          final a2 = affections[ids[j]] ?? 50;
          score += (a1 * a2) / 100.0;
        }
      }
      final profile = locProfiles[entry.key];
      if (profile != null) {
        final avgAffinity = profile.eventAffinity.isEmpty
            ? 0.0
            : profile.eventAffinity.values.reduce((a, b) => a + b) / profile.eventAffinity.length;
        score *= (1.0 + avgAffinity);
      }
      if (score > bestScore) {
        bestScore = score;
        best = ScheduleCollision(locationId: entry.key, charIds: ids, phase: phase);
      }
    }

    if (best == null) return null;
    final profile = locProfiles[best.locationId];
    return {
      'location_id': best.locationId,
      'char_ids': best.charIds,
      'phase': phase,
      'drama_score': bestScore,
      if (profile != null)
        'narrative_keywords': profile.narrativeKeywords,
    };
  }
}
