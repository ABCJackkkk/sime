import 'package:love_sim/models/script.dart';
import 'package:love_sim/services/deepseek_client.dart';

class InitiativeService {
  final GameScript? script;
  final DeepSeekClient? deepSeekClient;

  final Map<String, DateTime> _cooldowns = {};
  final Map<String, String> _pendingInvitation = {};

  InitiativeService({this.script, this.deepSeekClient});

  Map<String, String> get pendingInvitation => Map.unmodifiable(_pendingInvitation);

  bool hasPendingInvitationFor(String charId) => _pendingInvitation.containsKey(charId);

  void clearInvitation(String charId) {
    _pendingInvitation.remove(charId);
  }

  List<InitiativeTrigger> check({
    required int currentDay,
    required String currentSeason,
    required String currentWeather,
    required String currentPhase,
    required Map<String, double> affectionStates,
  }) {
    final triggers = <InitiativeTrigger>[];
    final msgTriggers = script?.dialogue?.messageFromChar ?? [];
    final now = DateTime.now();

    for (final trigger in msgTriggers) {
      if (trigger.once && _cooldowns.containsKey(trigger.id)) continue;
      final lastTime = _cooldowns[trigger.id];
      if (lastTime != null && now.difference(lastTime).inHours < trigger.cooldownDays * 24) continue;
      final cond = trigger.condition;
      if (cond.isNotEmpty) {
        final affMatch = RegExp(r'affection\s*>\s*(\d+)').firstMatch(cond);
        if (affMatch != null) {
          final required = double.tryParse(affMatch.group(1)!) ?? 0;
          if ((affectionStates[trigger.charId] ?? 0) < required) continue;
        }
      }
      _cooldowns[trigger.id] = now;
      triggers.add(InitiativeTrigger(
        id: trigger.id,
        charId: trigger.charId,
        aiHint: trigger.aiHint,
      ));
    }

    return triggers;
  }

  void checkInvitation({
    required Map<String, double> affectionStates,
    required List<SceneLocation>? locations,
  }) {
    _pendingInvitation.clear();
    if (script == null) return;
    final rng = DateTime.now().millisecond;
    final chars = script!.characters.where((c) => c.fullCharacter).toList();
    for (final c in chars) {
      final aff = affectionStates[c.basic.id] ?? 0;
      if (aff < 65) continue;
      final chance = (aff - 60) * 0.01;
      if (rng / 1000.0 < chance) {
        final locs = locations ?? [];
        if (locs.isNotEmpty) {
          _pendingInvitation[c.basic.id] = locs[rng % locs.length].id;
          break;
        }
      }
    }
  }

  String buildWorldContext(int currentDay, String currentSeason, String currentWeather, String currentPhase) {
    return '第${currentDay}天 ${currentSeason}·${currentWeather}·${currentPhase}';
  }
}

class InitiativeTrigger {
  final String id;
  final String charId;
  final String aiHint;

  InitiativeTrigger({required this.id, required this.charId, required this.aiHint});
}
