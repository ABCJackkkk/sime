import 'dart:math';
import 'package:love_sim/models/script.dart';
import 'package:love_sim/services/inter_character_relationship.dart';

class InfoSpreadEvent {
  final String fragmentId;
  final String fromCharId;
  final String toCharId;
  final String distortedContent;
  final String encryptionStyle;
  InfoSpreadEvent({required this.fragmentId,required this.fromCharId,required this.toCharId,this.distortedContent='',this.encryptionStyle=''});
}

class InformationPropagationService {
  final Random _rng = Random();
  final List<InformationFragment> _fragments = [];
  int _fragmentCounter = 0;

  static const _defaultStyles = {
    'honest': {'trust': 1.0, 'desc': '如实转述，不加修饰'},
    'gossip': {'trust': 0.5, 'desc': '添油加醋，放大戏剧性'},
    'joke': {'trust': 0.7, 'desc': '用玩笑/阴阳怪气加密，真义埋藏在玩笑里'},
    'cold': {'trust': 0.8, 'desc': '轻描淡写，故意压低重要性'},
    'speculation': {'trust': 0.4, 'desc': '把自己的揣测包装成事实'},
  };

  Map<String, Map<String, dynamic>> _encryptionStyles = Map<String, Map<String, dynamic>>.from(_defaultStyles);

  void initFromConfig(InformationSystemConfig? config) {
    if (config == null || config.encryptionStyles.isEmpty) return;
    _encryptionStyles = {};
    for (final entry in config.encryptionStyles.entries) {
      _encryptionStyles[entry.key] = {
        'trust': entry.value.trust,
        'desc': entry.value.desc,
      };
    }
  }

  List<InformationFragment> get activeFragments => _fragments.where((f) => f.active).toList();
  List<InformationFragment> get allFragments => List.unmodifiable(_fragments);

  InformationFragment createFragment({
    required String sourceEventId,
    required String witnessCharId,
    required String content,
    String encryption = 'honest',
    int spreadRadius = 2,
    List<String>? initialKnownBy,
  }) {
    final id = 'info_${++_fragmentCounter}';
    final knownBy = initialKnownBy ?? [witnessCharId];
    final trust = _trustFromEncryption(encryption);
    final fragment = InformationFragment(
      id: id, sourceEventId: sourceEventId, witnessCharId: witnessCharId,
      content: content, encryption: encryption, spreadRadius: spreadRadius,
      knownBy: knownBy, trustworthiness: trust,
    );
    _fragments.add(fragment);
    return fragment;
  }

  double _trustFromEncryption(String style) {
    final s = _encryptionStyles[style];
    if (s != null) return (s['trust'] as num?)?.toDouble() ?? 0.8;
    return 0.8;
  }

  String _distort(String original, String encryption, double affinity) {
    final bias = affinity / 100;
    switch (encryption) {
      case 'honest': return original;
      case 'gossip': return _addEmbellishment(original);
      case 'joke': return _wrapAsJoke(original);
      case 'cold': return _minimize(original);
      case 'speculation': return _addSpeculation(original, bias);
      default: return original;
    }
  }

  String _addEmbellishment(String content) {
    final phrases = ['听说...', '老天，', '说出来你可能不信，', '这事儿真绝了，'];
    return '${phrases[_rng.nextInt(phrases.length)]}$content...简直难以置信！';
  }

  String _wrapAsJoke(String content) => '哈哈，你知道吗，$content（笑）。不过说真的。';

  String _minimize(String content) => '$content。也没什么大不了的。';

  String _addSpeculation(String content, double bias) {
    final spec = bias > 0 ? '感觉ta们之间不太对劲' : '这里面肯定有问题';
    return '$content。$spec。';
  }

  List<InfoSpreadEvent> propagate(List<Character> characters, InterCharRelationshipService? interRel) {
    final events = <InfoSpreadEvent>[];
    final activeNow = _fragments.where((f) => f.active && f.spreadCount < f.spreadRadius).toList();

    for (final fragment in activeNow) {
      final knowers = Set<String>.from(fragment.knownBy);
      final potentialTargets = characters.where((c) => !knowers.contains(c.basic.id)).toList();

      if (potentialTargets.isEmpty) {
        fragment.active = false;
        continue;
      }

      final target = potentialTargets[_rng.nextInt(potentialTargets.length)];
      final encryptStyle = fragment.encryption.isNotEmpty ? fragment.encryption : _pickRandomEncryption();
      final affinity = interRel?.get(fragment.witnessCharId, target.basic.id)?.affinity ?? 0;
      final distorted = _distort(fragment.content, encryptStyle, affinity);

      fragment.knownBy.add(target.basic.id);
      fragment.spreadCount++;
      fragment.trustworthiness *= 0.85;

      events.add(InfoSpreadEvent(
        fragmentId: fragment.id, fromCharId: fragment.witnessCharId,
        toCharId: target.basic.id, distortedContent: distorted,
        encryptionStyle: encryptStyle,
      ));
    }

    _fragments.removeWhere((f) => f.spreadCount >= f.spreadRadius || DateTime.now().difference(f.createdAt).inDays > 30);
    return events;
  }

  String _pickRandomEncryption() {
    final keys = _encryptionStyles.keys.toList();
    return keys[_rng.nextInt(keys.length)];
  }

  Map<String, String> buildKnowledgeReport(Map<String, double> playerAffections) {
    final report = <String, String>{};
    for (final f in _fragments.where((f) => f.active)) {
      for (final knower in f.knownBy) {
        final existing = report[knower] ?? '';
        final dist = _distort(f.content, f.encryption, playerAffections[knower] ?? 50);
        report[knower] = existing.isEmpty ? dist : '$existing\n  $dist';
      }
    }
    return report;
  }

  void reset() {
    _fragments.clear();
    _fragmentCounter = 0;
  }

  List<Map<String,dynamic>> toJsonList() => _fragments.map((f) => f.toJson()).toList();

  void fromJsonList(List<dynamic> jsonList) {
    _fragments.clear();
    for (final j in jsonList) {
      _fragments.add(InformationFragment.fromJson(j));
    }
  }
}
