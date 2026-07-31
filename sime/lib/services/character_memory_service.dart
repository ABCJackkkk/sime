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

  void recordChat(String charId, int day, String playerLine, String aiReply, double affection) {
    final layer = affection >= 60 ? 'episodic' : 'decay';
    _memories.putIfAbsent(charId, () => []);
    // 摘要格式：玩家消息前 30 字 + AI 回复前 50 字
    final pShort = playerLine.length > 30 ? '${playerLine.substring(0, 27)}...' : playerLine;
    final aShort = aiReply.length > 50 ? '${aiReply.substring(0, 47)}...' : aiReply;
    final summary = '我：$pShort | 她：$aShort';
    final entry = EpisodicEntry(day: day, summary: summary,
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

  /// 记录一次会话的结构化摘要（场景互动/行动会话结束时调用）
  /// severity 由调用方判断：关键事件用 'critical'→core 层，普通互动用 'medium'→episodic 层
  void recordSessionSummary(String charId, int day, String summary, double affection, {bool isCritical = false}) {
    record(
      charId, day, summary,
      affection: affection,
      type: 'session',
      tags: isCritical ? ['会话摘要', '核心记忆'] : ['会话摘要'],
      severity: isCritical ? 'critical' : 'medium',
    );
  }

  /// 跨角色记录会话摘要：一次会话可能涉及多个角色，给每个在场角色都存一份
  void recordSessionSummaryMulti(List<String> charIds, int day, String summary, Map<String, double> affections, {bool isCritical = false}) {
    for (final cid in charIds) {
      final aff = affections[cid] ?? 50.0;
      recordSessionSummary(cid, day, summary, aff, isCritical: isCritical);
    }
  }

  /// 关键词召回：根据当前消息提取的关键词，从所有层级的记忆里召回相关条目
  /// 返回最多 maxResults 条，按相关度（匹配关键词数）排序
  List<EpisodicEntry> recallByKeywords(String charId, List<String> keywords, {int maxResults = 5}) {
    if (keywords.isEmpty) return [];
    final entries = _memories[charId];
    if (entries == null || entries.isEmpty) return [];
    final scored = <MapEntry<int, EpisodicEntry>>[];
    for (final e in entries) {
      int score = 0;
      final text = '${e.summary} ${e.tags.join(' ')}';
      for (final kw in keywords) {
        if (kw.isEmpty) continue;
        if (text.contains(kw)) score++;
      }
      if (score > 0) scored.add(MapEntry(score, e));
    }
    scored.sort((a, b) => b.key.compareTo(a.key));
    return scored.take(maxResults).map((e) => e.value).toList();
  }

  /// 从一段文本中提取召回关键词（角色名、地点、事件词等）
  /// 简单实现：提取 2-4 字的中文词组，过滤常见停用词
  static List<String> extractKeywords(String text, {List<String> charNames = const []}) {
    final keywords = <String>{};
    // 优先匹配角色名
    for (final name in charNames) {
      if (name.isNotEmpty && text.contains(name)) keywords.add(name);
    }
    // 匹配常见事件关键词
    const eventWords = ['告白', '分手', '吵架', '冲突', '亲吻', '拥抱', '约会', '表白',
      '误会', '吃醋', '冷战', '破冰', '背叛', '原谅', '生日', '礼物', '图书馆',
      '教室', '宿舍', '食堂', '操场', '回家', '生病', '受伤', '哭泣', '生气'];
    for (final w in eventWords) {
      if (text.contains(w)) keywords.add(w);
    }
    return keywords.toList();
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

  String buildMemoryContext(String charId, {int maxEntries = 8, List<String>? filterTags}) {
    final entries = _memories[charId];
    if (entries == null || entries.isEmpty) return '';

    List<EpisodicEntry> filtered(List<EpisodicEntry> src, int limit) {
      if (filterTags == null || filterTags.isEmpty) return src.sublist(0, src.length.clamp(0, limit));
      final matched = src.where((e) => e.tags.any((t) => filterTags.contains(t))).toList();
      final others = src.where((e) => !e.tags.any((t) => filterTags.contains(t))).toList();
      matched.length = matched.length.clamp(0, limit);
      final remaining = limit - matched.length;
      if (remaining > 0) {
        matched.addAll(others.take(remaining));
      }
      return matched;
    }

    final core = filtered(entries.where((e) => e.layer == 'core').toList(), maxEntries);
    final episodic = filtered(entries.where((e) => e.layer == 'episodic').toList(), maxEntries);
    final decay = filtered(entries.where((e) => e.layer == 'decay').toList(), maxEntries);

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

  /// 召回与当前消息相关的记忆（用于聊天 prompt 注入）
  /// 与 buildMemoryContext 的区别：不按层级全量展示，而是按关键词召回最相关的几条
  String buildRecalledContext(String charId, String currentMessage, {List<String> charNames = const [], int maxResults = 5}) {
    final keywords = extractKeywords(currentMessage, charNames: charNames);
    if (keywords.isEmpty) return '';
    final recalled = recallByKeywords(charId, keywords, maxResults: maxResults);
    if (recalled.isEmpty) return '';
    final buf = StringBuffer();
    buf.writeln('【唤起的记忆】（与当前话题相关）');
    for (final e in recalled) {
      buf.writeln('第${e.day}天: ${e.summary}');
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
