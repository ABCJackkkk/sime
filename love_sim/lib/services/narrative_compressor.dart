import 'package:love_sim/services/deepseek_client.dart';

class NarrativeCompressor {
  static const int _softLimit = 12000;
  static const int _targetLen = 9000;
  static const int _maxSegments = 20;
  static const int _summaryTargetLen = 400;

  DeepSeekClient? _client;
  String _compressedPrefix = '';
  int _aiCompressCount = 0;
  static const int _aiCompressInterval = 8;

  void attach(DeepSeekClient client) {
    _client = client;
  }

  int get softLimit => _softLimit;
  bool needsCompression(String narrative) => narrative.length > _softLimit;

  CompressResult compressSegments(List<String> segments, {String? playerName}) {
    String truncatedHistory = '';

    if (segments.isEmpty) {
      return CompressResult(history: '', segments: [], replacedCount: 0);
    }

    final totalChars = segments.fold<int>(0, (sum, s) => sum + s.length);
    if (totalChars <= _softLimit) {
      truncatedHistory = segments.join('\n\n');
      return CompressResult(history: truncatedHistory, segments: segments, replacedCount: 0);
    }

    int dropCount = 0;
    final kept = <String>[];
    int runningTotal = 0;
    for (int i = segments.length - 1; i >= 0; i--) {
      if (runningTotal + segments[i].length > _targetLen && kept.isNotEmpty) {
        dropCount = i + 1;
        break;
      }
      kept.insert(0, segments[i]);
      runningTotal += segments[i].length;
    }

    final prefix = _compressedPrefix.isNotEmpty
        ? '[前略: ${dropCount}段叙事，概要: $_compressedPrefix]'
        : '[前略: ${dropCount}段叙事]';
    truncatedHistory = '$prefix\n\n${kept.join('\n\n')}';

    segments.removeRange(0, dropCount);
    if (prefix.isNotEmpty) segments.insert(0, prefix);

    if (segments.length > _maxSegments) {
      segments.removeAt(0);
    }

    return CompressResult(history: truncatedHistory, segments: segments, replacedCount: dropCount);
  }

  Future<CompressResult> maybeAiCompress(String recentPrefix, {String? playerName}) async {
    _aiCompressCount++;
    if (_aiCompressCount < _aiCompressInterval) {
      return CompressResult(history: recentPrefix, segments: [], replacedCount: 0);
    }
    _aiCompressCount = 0;

    final client = _client;
    if (client == null) return CompressResult(history: recentPrefix, segments: [], replacedCount: 0);

    try {
      final summary = await _summarize(client, recentPrefix, playerName: playerName);
      _compressedPrefix = summary;
      return CompressResult(history: summary, segments: [], replacedCount: 0);
    } catch (_) {
      return CompressResult(history: recentPrefix, segments: [], replacedCount: 0);
    }
  }

  Future<String> compress(String narrative, {String? playerName}) async {
    if (narrative.length <= _softLimit) return narrative;
    return _hardTruncate(narrative);
  }

  Future<String> _summarize(DeepSeekClient client, String text, {String? playerName}) async {
    final who = playerName ?? '主角';
    return client.callRaw(
      systemPrompt: '你是叙事摘要引擎。将以下故事片段压缩为$_summaryTargetLen字以内的摘要。'
          '保留关键人物关系变化、重要事件和情感转折。不要添加新内容。使用中文。',
      userPrompt: '将以下${who}的故事压缩为摘要：\n\n$text',
      maxTokens: 256,
      temperature: 0.3,
    );
  }

  String _hardTruncate(String narrative) {
    if (narrative.length <= _softLimit) return narrative;
    final cutoff = narrative.length - _softLimit;
    final trimPoint = narrative.indexOf('\n', cutoff);
    final start = trimPoint > 0 ? trimPoint + 1 : cutoff;
    return '[已省略前 ${cutoff ~/ 1000}k 字历史]\n\n${narrative.substring(start)}';
  }

  void reset() {
    _compressedPrefix = '';
    _aiCompressCount = 0;
  }
}

class CompressResult {
  final String history;
  final List<String> segments;
  final int replacedCount;
  CompressResult({required this.history, required this.segments, this.replacedCount = 0});
}
