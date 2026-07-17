import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sime/models/script.dart';

class ScriptEntry {
  final String id;
  String name;
  String version;
  final String assetPath;
  String type;
  String description;
  GameScript? script;
  ScriptEntry({required this.id, required this.name, this.version = '', required this.assetPath, this.type = '', this.description = '', this.script});
}

class ScriptRegistry {
  static final ScriptRegistry _instance = ScriptRegistry._();
  factory ScriptRegistry() => _instance;
  ScriptRegistry._();

  final Map<String, ScriptEntry> _entries = {};
  String? _activeId;

  List<ScriptEntry> get entries => _entries.values.toList();
  ScriptEntry? get activeEntry => _activeId != null ? _entries[_activeId] : null;
  bool get isEmpty => _entries.isEmpty;

  void register(String id, String assetPath, {String type = '', String description = ''}) {
    _entries[id] = ScriptEntry(id: id, name: id, assetPath: assetPath, type: type, description: description);
  }

  void registerEntry(ScriptEntry entry) {
    _entries[entry.id] = entry;
  }

  Future<ScriptEntry?> load(String id) async {
    final entry = _entries[id];
    if (entry == null) return null;
    if (entry.script != null) return entry;
    try {
      final jsonString = await rootBundle.loadString(entry.assetPath);
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      final meta = jsonMap['meta'] as Map<String, dynamic>?;
      if (meta != null) {
        entry.name = meta['name'] ?? entry.name;
        entry.version = meta['version'] ?? entry.version;
        entry.type = meta['type'] ?? entry.type;
        entry.description = meta['description'] ?? entry.description;
      }
      entry.script = GameScript.fromJson(jsonMap);
      return entry;
    } catch (_) {
      return null;
    }
  }

  Future<ScriptEntry?> preload(String id) async => load(id);

  Future<ScriptEntry?> activate(String id) async {
    final entry = await load(id);
    if (entry != null) {
      _activeId = id;
    }
    return entry;
  }

  void deactivate() {
    _activeId = null;
  }

  Future<void> preloadAll() async {
    for (final id in _entries.keys) {
      await load(id);
    }
  }

  ScriptEntry? getById(String id) => _entries[id];

  void reset() {
    _activeId = null;
    for (final e in _entries.values) {
      e.script = null;
    }
  }
}
