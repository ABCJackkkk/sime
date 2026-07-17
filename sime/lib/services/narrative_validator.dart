import 'dart:math';
import 'package:sime/models/script.dart';

class NarrativeValidator {
  static bool isValidNarrative(String narrative) {
    if (narrative.isEmpty) return false;
    if (narrative.startsWith('[') && narrative.endsWith(']')) return false;
    if (narrative.startsWith('{') && narrative.endsWith('}')) return false;
    if (narrative.length < 5) return false;
    return true;
  }

  static String fallbackNarrative(
    String poolKey,
    FallbackNarratives? fallback,
    Map<String, String> placeholders,
  ) {
    final charName = placeholders['char_name'] ?? '角色';
    if (fallback == null) return '$charName没有回应。';

    final pool = fallback[poolKey];
    if (pool.isEmpty) return '$charName没有回应。';

    final rng = Random();
    var template = pool[rng.nextInt(pool.length)];

    for (final entry in placeholders.entries) {
      template = template.replaceAll('{${entry.key}}', entry.value);
    }

    return template;
  }
}
