import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sime/models/script.dart';

class ScriptLoader {
  Future<GameScript> loadFromAsset(String assetPath) async {
    final jsonString = await rootBundle.loadString(assetPath);
    final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    return _parseWithDiagnostics(jsonMap);
  }

  GameScript loadFromJsonString(String jsonString) {
    final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    return _parseWithDiagnostics(jsonMap);
  }

  GameScript _parseWithDiagnostics(Map<String, dynamic> json) {
    try { ScriptMeta.fromJson(json['meta'] ?? {}); } catch (e) { throw Exception('meta层解析失败: $e'); }
    try { ScriptPlayer.fromJson(json['player'] ?? {}); } catch (e) { throw Exception('player层解析失败: $e'); }
    try { ScriptWorld.fromJson(json['world'] ?? {}); } catch (e) { throw Exception('world层解析失败: $e'); }
    try {
      final chars = json['characters'];
      if (chars is List) {
        for (int i = 0; i < chars.length; i++) {
          final c = chars[i];
          if (c is! Map) continue;
          final id = c['id']?.toString() ?? c['name']?.toString() ?? 'index_$i';
          try { Character.fromJson(c); } catch (e) { throw Exception('characters[$i]($id)解析失败: $e'); }
        }
      }
    } catch (e) { throw Exception('characters层解析失败: $e'); }
    try { ScriptItems.fromJson(json['items'] ?? {}); } catch (e) { throw Exception('items(旧)层解析失败: $e'); }
    try { InteractionConfig.fromJson(json['interaction'] ?? {}); } catch (e) { throw Exception('interaction(旧)层解析失败: $e'); }
    try { ScriptEvents.fromJson(json['events'] ?? {}); } catch (e) { throw Exception('events(旧)层解析失败: $e'); }
    try { GamePlot.fromJson(json['plot'] ?? {}); } catch (e) { throw Exception('plot层解析失败: $e'); }
    try { GameEvents.fromJson(json['events'] ?? {}); } catch (e) { throw Exception('gameEvents层解析失败: $e'); }
    try { GameDialogue.fromJson(json['dialogue'] ?? {}); } catch (e) { throw Exception('dialogue层解析失败: $e'); }
    try { GameItems.fromJson(json['items'] ?? {}); } catch (e) { throw Exception('gameItems层解析失败: $e'); }
    try { GameInteraction.fromJson(json['interaction'] ?? {}); } catch (e) { throw Exception('gameInteraction层解析失败: $e'); }
    return GameScript.fromJson(json);
  }
}
