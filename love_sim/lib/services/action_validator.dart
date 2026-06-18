import 'package:love_sim/models/script.dart';

class ActionValidationResult {
  final bool valid;
  final String? rejectionNarrative;
  final String? targetCharId;
  final double affectionPenalty;

  ActionValidationResult({
    required this.valid,
    this.rejectionNarrative,
    this.targetCharId,
    this.affectionPenalty = 0.0,
  });

  static ActionValidationResult ok() => ActionValidationResult(valid: true);
}

class ActionValidator {
  final ActionRules? rules;
  final Map<String, double> affectionStates;
  final List<Character> characters;

  ActionValidator({
    this.rules,
    required this.affectionStates,
    required this.characters,
  });

  Character _resolveTarget(String action) {
    final fullChars = characters.where((c) => c.fullCharacter).toList();
    if (fullChars.isEmpty) return characters.first;
    final named = fullChars.where((c) => c.basic.name.isNotEmpty && action.contains(c.basic.name)).toList();
    if (named.length == 1) return named.first;
    if (named.length > 1) {
      named.sort((a, b) => b.basic.name.length.compareTo(a.basic.name.length));
      return named.first;
    }
    return fullChars.first;
  }

  ActionValidationResult validate(String action) {
    if (rules == null) return ActionValidationResult.ok();

    final target = _resolveTarget(action);
    final affection = affectionStates[target.basic.id] ?? 50.0;

    for (final check in rules!.boundaryChecks) {
      for (final keyword in check.keywords) {
        if (action.contains(keyword)) {
          if (affection < check.minAffection) {
            final narrative = check.rejectionNarrative
                .replaceAll('{char_name}', target.basic.name);
            return ActionValidationResult(
              valid: false,
              rejectionNarrative: narrative,
              targetCharId: target.basic.id,
              affectionPenalty: check.affectionPenalty,
            );
          }
        }
      }
    }

    if (rules!.topicTabooRejection.isNotEmpty) {
      for (final char in characters.where((c) => c.fullCharacter)) {
        final taboo = char.boundary?.topicTaboo ?? [];
        for (final word in taboo.where((t) => t.isNotEmpty)) {
          if (action.contains(word)) {
            final narrative = rules!.topicTabooRejection
                .replaceAll('{char_name}', char.basic.name);
            return ActionValidationResult(
              valid: false,
              rejectionNarrative: narrative,
              targetCharId: char.basic.id,
              affectionPenalty: rules!.topicTabooPenalty,
            );
          }
        }
      }
    }

    return ActionValidationResult.ok();
  }
}
