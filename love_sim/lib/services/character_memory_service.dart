class EpisodicEntry {
  final int day;
  final String summary;
  final double affectionAtTime;
  final String type;
  final List<String> tags;
  final String layer;
  EpisodicEntry({required this.day, required this.summary, this.affectionAtTime = 50, this.type = 'event', List<String>? tags, this.layer = 'episodic'}) : tags = tags ?? [];
  Map<String, dynamic> toJson() => {'day': day, 'summary': summary, 'affection': affectionAtTime, 'type': type, 'tags': tags, 'layer': layer};
  factory EpisodicEntry.fromJson(Map<String, dynamic> json) => EpisodicEntry(
    day: json['day'] ?? 0, summary: json['summary'] ?? '', affectionAtTime: (json['affection'] as num?)?.toDouble() ?? 50,
    type: json['type'] ?? 'event', tags: List<String>.from(json['tags'] ?? []),
    layer: json['layer'] ?? 'episodic',
  );
}

class CharacterMemoryService {
  static const int _coreCap = 8;
  static const int _episodicCap = 10;
  static const int _decayCap = 20;

  final Map<String, List<EpisodicEntry>> _memories = {};

  String _layerForSeverity(String severity) {
    switch (severity) {
      case 'critical':
      case 'heavy':
        return 'core';
      case 'medium':
        return 'episodic';
      default:
        return 'decay';
    }
  }

  void record(String charId, int day, String summary, {double affection = 50, String type = 'event', List<String>? tags, String severity = 'daily'}) {
    _memories.putIfAbsent(charId, () => []);
    final layer = _layerForSeverity(severity);
    final entry = EpisodicEntry(day: day, summary: summary, affectionAtTime: affection, type: type, tags: tags, layer: layer);
    _memories[charId]!.add(entry);
    _prune(charId);
  }

  void recordCore(String charId, int day, String summary, {double affection = 50}) {
    record(charId, day, summary, affection: affection, type: 'event', tags: ['核心记忆'], severity: 'critical');
  }

  void recordChat(String charId, int day, String topic, String playerLine, double affection) {
    final layer = affection >= 60 ? 'episodic' : 'decay';
    _memories.putIfAbsent(charId, () => []);
    final entry = EpisodicEntry(day: day, summary: topic.length > 60 ? '${topic.substring(0, 57)}...' : topic,
      affectionAtTime: affection, type: 'chat', tags: ['对话'], layer: layer);
    _memories[charId]!.add(entry);
    _prune(charId);
  }

  void recordEvent(String charId, int day, String eventName, double affection) {
    record(charId, day, eventName, affection: affection, type: 'event', tags: ['事件'], severity: 'medium');
  }

  void recordRelationChange(String charId, int day, String from, String to, double affection) {
    record(charId, day, '$from → $to', affection: affection, type: 'relation', tags: ['关系变化'], severity: 'medium');
  }

  void _prune(String charId) {
    final all = _memories[charId]!;
    final core = all.where((e) => e.layer == 'core').toList();
    final episodic = all.where((e) => e.layer == 'episodic').toList();
    final decay = all.where((e) => e.layer == 'decay').toList();

    while (core.length > _coreCap) { core.removeAt(0); }

    while (episodic.length > _episodicCap) {
      final oldest = episodic.removeAt(0);
      final downgraded = EpisodicEntry(day: oldest.day, summary: oldest.summary, affectionAtTime: oldest.affectionAtTime, type: oldest.type, tags: oldest.tags, layer: 'decay');
      decay.add(downgraded);
    }

    while (decay.length > _decayCap) { decay.removeAt(0); }

    _memories[charId] = [...core, ...episodic, ...decay];
  }

  List<EpisodicEntry> getMemories(String charId) => List.unmodifiable(_memories[charId] ?? []);

  List<EpisodicEntry> getCoreMemories(String charId) => (_memories[charId] ?? []).where((e) => e.layer == 'core').toList();

  List<EpisodicEntry> getEpisodicMemories(String charId) => (_memories[charId] ?? []).where((e) => e.layer == 'episodic').toList();

  List<EpisodicEntry> getDecayMemories(String charId) => (_memories[charId] ?? []).where((e) => e.layer == 'decay').toList();

  EpisodicEntry? getMostRecent(String charId) {
    final list = _memories[charId];
    if (list == null || list.isEmpty) return null;
    return list.last;
  }

  List<EpisodicEntry> searchByTag(String charId, String tag) {
    return (_memories[charId] ?? []).where((e) => e.tags.contains(tag)).toList();
  }

  String buildMemoryContext(String charId, {int maxEntries = 8}) {
    final entries = _memories[charId];
    if (entries == null || entries.isEmpty) return '';

    final core = entries.where((e) => e.layer == 'core').toList();
    final episodic = entries.where((e) => e.layer == 'episodic').toList();
    final decay = entries.where((e) => e.layer == 'decay').toList();

    final buf = StringBuffer();

    if (core.isNotEmpty) {
      buf.writeln('【她的记忆锚点】');
      for (final e in core) {
        buf.writeln('第${e.day}天: ${e.summary}');
      }
      buf.writeln();
    }

    if (episodic.isNotEmpty) {
      buf.writeln('【你们之间的重要时刻】');
      for (final e in episodic) {
        buf.writeln('第${e.day}天: ${e.summary}');
      }
      buf.writeln();
    }

    if (decay.isNotEmpty) {
      buf.writeln('【最近的日常】');
      final shown = decay.length > maxEntries ? decay.sublist(decay.length - maxEntries) : decay;
      for (final e in shown) {
        buf.writeln('第${e.day}天: ${e.summary}');
      }
      if (decay.length > maxEntries) {
        buf.writeln('……以及${decay.length - maxEntries}件日常琐事');
      }
    }

    return buf.toString();
  }

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    for (final entry in _memories.entries) {
      result[entry.key] = entry.value.map((e) => e.toJson()).toList();
    }
    return result;
  }

  void fromJson(Map<String, dynamic> json) {
    _memories.clear();
    for (final entry in json.entries) {
      _memories[entry.key] = (entry.value as List<dynamic>).map((e) => EpisodicEntry.fromJson(e as Map<String, dynamic>)).toList();
    }
  }
}
