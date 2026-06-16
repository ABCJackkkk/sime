class EpisodicEntry {
  final int day;
  final String summary;
  final double affectionAtTime;
  final String type;
  final List<String> tags;
  EpisodicEntry({required this.day, required this.summary, this.affectionAtTime = 50, this.type = 'event', List<String>? tags})
    : tags = tags ?? [];
  Map<String, dynamic> toJson() => {'day': day, 'summary': summary, 'affection': affectionAtTime, 'type': type, 'tags': tags};
  factory EpisodicEntry.fromJson(Map<String, dynamic> json) => EpisodicEntry(
    day: json['day'] ?? 0, summary: json['summary'] ?? '', affectionAtTime: (json['affection'] as num?)?.toDouble() ?? 50,
    type: json['type'] ?? 'event', tags: List<String>.from(json['tags'] ?? []),
  );
}

class CharacterMemoryService {
  static const int _maxEntries = 20;
  final Map<String, List<EpisodicEntry>> _memories = {};

  void record(String charId, int day, String summary, {double affection = 50, String type = 'event', List<String>? tags}) {
    _memories.putIfAbsent(charId, () => []);
    final entry = EpisodicEntry(day: day, summary: summary, affectionAtTime: affection, type: type, tags: tags);
    _memories[charId]!.add(entry);
    if (_memories[charId]!.length > _maxEntries) {
      _memories[charId]!.removeAt(0);
    }
  }

  void recordChat(String charId, int day, String topic, String playerLine, double affection) {
    record(charId, day, topic.length > 60 ? '${topic.substring(0, 57)}...' : topic,
      affection: affection, type: 'chat', tags: ['对话']);
  }

  void recordEvent(String charId, int day, String eventName, double affection) {
    record(charId, day, eventName, affection: affection, type: 'event', tags: ['事件']);
  }

  void recordRelationChange(String charId, int day, String from, String to, double affection) {
    record(charId, day, '$from → $to', affection: affection, type: 'relation', tags: ['关系变化']);
  }

  List<EpisodicEntry> getMemories(String charId) => List.unmodifiable(_memories[charId] ?? []);

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
    final recent = entries.length > maxEntries ? entries.sublist(entries.length - maxEntries) : entries;
    final buf = StringBuffer();
    buf.writeln('【$charId 的记忆——她/他记得这些关于你的事】');
    for (final e in recent) {
      buf.writeln('第${e.day}天: ${e.summary}');
    }
    if (entries.length > maxEntries) {
      buf.writeln('……以及${entries.length - maxEntries}件更早的事');
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
      _memories[entry.key] = (entry.value as List<dynamic>)
        .map((e) => EpisodicEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    }
  }
}
