import 'package:love_sim/models/script.dart';

class PlotState {
  String currentAct;
  final Map<String, bool> triggeredBeats;
  double tensionLevel;
  Map<String, double> endingProgress;
  List<Map<String, dynamic>> activeForeshadow;
  int dayEnteredAct;

  PlotState({
    this.currentAct = 'act_1',
    Map<String, bool>? triggeredBeats,
    this.tensionLevel = 20.0,
    Map<String, double>? endingProgress,
    List<Map<String, dynamic>>? activeForeshadow,
    this.dayEnteredAct = 1,
  })  : triggeredBeats = triggeredBeats ?? {},
        endingProgress = endingProgress ?? {},
        activeForeshadow = activeForeshadow ?? [];
}

class PlotService {
  final GameScript? script;
  PlotState state = PlotState();

  PlotService({this.script});

  void initFromScript() {
    final plotMemory = script?.plot?.memory;
    if (plotMemory != null) {
      state.currentAct = plotMemory.currentAct.isNotEmpty ? plotMemory.currentAct : 'act_1';
      state.dayEnteredAct = plotMemory.dayEnteredAct > 0 ? plotMemory.dayEnteredAct : 1;
      for (final beatId in plotMemory.triggeredBeats) {
        state.triggeredBeats[beatId] = true;
      }
      state.endingProgress = Map<String, double>.from(plotMemory.endingProgress);
      state.activeForeshadow = List<Map<String, dynamic>>.from(plotMemory.activeForeshadow);
    }
    state.tensionLevel = script?.plot?.narrativeTension.actualLevel ?? 20.0;
  }

  void tickTension() {
    final inc = (DateTime.now().millisecond % 30) / 10.0;
    state.tensionLevel = (state.tensionLevel + inc).clamp(0.0, 100.0);
    _syncTensionToScript();
  }

  void tickTensionAfterEvent(String eventSeverity) {
    final inc = eventSeverity == 'major' ? 5.0 : (eventSeverity == 'medium' ? 2.0 : 1.0);
    state.tensionLevel = (state.tensionLevel + inc).clamp(0.0, 100.0);
    _syncTensionToScript();
  }

  void _syncTensionToScript() {
    script?.plot?.narrativeTension.setLevel(state.tensionLevel);
  }

  List<PlotBeatOutcome> checkBeatTriggers(int currentDay, Map<String, double> affectionStates, List<String> inventoryItemIds) {
    final outcomes = <PlotBeatOutcome>[];
    final plot = script?.plot;
    if (plot == null) return outcomes;

    for (final beat in plot.beats) {
      if (state.triggeredBeats[beat.id] == true && beat.once) continue;
      if (_checkBeatCondition(beat, currentDay, affectionStates)) {
        state.triggeredBeats[beat.id] = true;
        final outcome = _applyBeatOutcome(beat, inventoryItemIds);
        outcomes.add(outcome);
      }
    }
    return outcomes;
  }

  bool _checkBeatCondition(PlotBeat beat, int currentDay, Map<String, double> affectionStates) {
    final tMin = beat.trigger.time['min'] ?? 0;
    final tMax = beat.trigger.time['max'] ?? 999;
    if (currentDay < tMin || currentDay > tMax) return false;
    final affConds = beat.trigger.affection;
    if (affConds.isNotEmpty) {
      for (final entry in affConds.entries) {
        final aff = affectionStates[entry.key] ?? 0;
        if (entry.value is Map) {
          final lo = entry.value['ge'] ?? 0;
          final hi = entry.value['le'] ?? 100;
          if (aff < lo || aff > hi) return false;
        }
      }
    }
    for (final pb in beat.trigger.preBeats) {
      if (state.triggeredBeats[pb] != true) return false;
    }
    return true;
  }

  PlotBeatOutcome _applyBeatOutcome(PlotBeat beat, List<String> inventoryItemIds) {
    final affChanges = <String, double>{};
    for (final entry in beat.outcome.affectionChanges.entries) {
      if (entry.value is num) affChanges[entry.key] = (entry.value as num).toDouble();
    }
    final unlockItems = <String>[...beat.outcome.unlockItems];
    if (beat.alwaysMemory && beat.aiHint.isNotEmpty) {
      state.activeForeshadow.add({
        'beat_id': beat.id, 'hint': beat.aiHint, 'planted_day': DateTime.now().millisecondsSinceEpoch,
      });
    }
    return PlotBeatOutcome(
      beatId: beat.id,
      affectionChanges: affChanges,
      unlockItems: unlockItems,
      advanceAct: beat.outcome.advanceAct,
    );
  }

  void advanceAct() {
    final plot = script?.plot;
    if (plot == null) return;
    final idx = plot.acts.indexWhere((a) => a.id == state.currentAct);
    if (idx >= 0 && idx < plot.acts.length - 1) {
      state.currentAct = plot.acts[idx + 1].id;
    }
  }
}

class PlotBeatOutcome {
  final String beatId;
  final Map<String, double> affectionChanges;
  final List<String> unlockItems;
  final bool advanceAct;

  PlotBeatOutcome({
    required this.beatId,
    required this.affectionChanges,
    required this.unlockItems,
    required this.advanceAct,
  });
}
