import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:sime/models/script.dart';
import 'package:sime/services/character_memory_service.dart';

class DeepSeekClient {
  final String apiKey;
  final String? corsProxy;
  static const _baseUrl = 'https://api.deepseek.com/chat/completions';
  static const _model = 'deepseek-chat';
  static const _maxRetries = 3;
  static const _baseDelayMs = 1000;

  final Random _rng = Random();
  final http.Client _httpClient = http.Client();

  static const _focusWeights = {
    'characterMoment':   {'speech': 35, 'relationship': 15, 'characterArc': 30, 'plot': 5,  'world': 15},
    'relationshipBeat':  {'speech': 15, 'relationship': 40, 'characterArc': 10, 'plot': 15, 'world': 20},
    'plotAdvancement':   {'speech': 5,  'relationship': 10, 'characterArc': 10, 'plot': 60, 'world': 15},
    'worldTexture':      {'speech': 10, 'relationship': 5,  'characterArc': 5,  'plot': 5,  'world': 75},
    'tensionEscalation': {'speech': 15, 'relationship': 20, 'characterArc': 15, 'plot': 35, 'world': 15},
    'ensembleScene':     {'speech': 25, 'relationship': 25, 'characterArc': 5,  'plot': 20, 'world': 25},
  };

  String _trimForFocus(String segment, String section, String? focus) {
    if (focus == null || segment.length < 100) return segment;
    final w = _focusWeights[focus] ?? _focusWeights['worldTexture']!;
    final sectionWeight = w[section] ?? 25;
    final scale = sectionWeight / 25.0;
    if (scale >= 1.0) return segment;
    final targetLen = (segment.length * scale).round();
    if (targetLen >= segment.length) return segment;
    final sentences = segment.split(RegExp(r'(?<=[。！？\n])'));
    final buf = StringBuffer();
    int cur = 0;
    for (final s in sentences) {
      if (cur + s.length > targetLen && cur > targetLen * 0.5) break;
      buf.write(s);
      cur += s.length;
    }
    return buf.toString();
  }

  DeepSeekClient({required this.apiKey, this.corsProxy});

  String _resolveUrl() {
    if (corsProxy != null && corsProxy!.isNotEmpty && kIsWeb) {
      return '$corsProxy${Uri.encodeComponent(_baseUrl)}';
    }
    return _baseUrl;
  }

  Future<String> _callApi({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 1024,
    double temperature = 0.8,
    List<Map<String, String>>? history,
    bool isWorldNarrative = false,
    int timeoutSeconds = 60,
  }) async {
    final effectiveMaxTokens = isWorldNarrative ? 1200 : maxTokens;
    final messages = <Map<String, String>>[];
    messages.add({'role': 'system', 'content': systemPrompt});
    if (history != null) messages.addAll(history);
    messages.add({'role': 'user', 'content': userPrompt});

    final body = json.encode({
      'model': _model,
      'messages': messages,
      'max_tokens': effectiveMaxTokens,
      'temperature': temperature,
    });

    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await _httpClient.post(
          Uri.parse(_resolveUrl()),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: body,
        ).timeout(Duration(seconds: timeoutSeconds));

        if (response.statusCode == 200) {
          final responseBody = utf8.decode(response.bodyBytes);
          final data = json.decode(responseBody) as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>;
          if (choices.isEmpty) throw Exception('API 返回空响应');
          final message = choices[0]['message'] as Map<String, dynamic>;
          return message['content'] as String;
        }

        if (response.statusCode >= 500 || response.statusCode == 429) {
          throw _ApiRetryException(response.statusCode);
        }
        throw Exception('API 请求失败 (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
      } on _ApiRetryException {
        if (attempt >= _maxRetries) throw Exception('API 服务器错误，已重试 $_maxRetries 次');
        final delay = (_baseDelayMs * pow(2, attempt - 1)).toInt() + _rng.nextInt(500);
        await Future.delayed(Duration(milliseconds: delay));
      } on TimeoutException {
        if (attempt >= _maxRetries) throw Exception('API 超时，已重试 $_maxRetries 次');
        final delay = (_baseDelayMs * pow(2, attempt - 1)).toInt();
        await Future.delayed(Duration(milliseconds: delay));
      } on Exception catch (e) {
        if (attempt >= _maxRetries || !(e.toString().contains('Connection') || e.toString().contains('Socket') || e.toString().contains('reset'))) rethrow;
        final delay = (_baseDelayMs * pow(2, attempt - 1)).toInt();
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
  }

  Future<String> callRaw({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 256,
    double temperature = 0.3,
  }) async {
    return _callApi(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: maxTokens,
      temperature: temperature,
    );
  }

  Stream<String> _callApiStreaming({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 1024,
    double temperature = 0.8,
    List<Map<String, String>>? history,
  }) async* {
    final messages = <Map<String, String>>[];
    messages.add({'role': 'system', 'content': systemPrompt});
    if (history != null) messages.addAll(history);
    messages.add({'role': 'user', 'content': userPrompt});

    final request = http.Request('POST', Uri.parse(_resolveUrl()));
    request.headers.addAll({
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    });
    request.body = json.encode({
      'model': _model,
      'messages': messages,
      'max_tokens': maxTokens,
      'temperature': temperature,
      'stream': true,
    });

    try {
      final streamedResponse = await _httpClient.send(request);
      final stream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') break;
          try {
            final jsonData = json.decode(data) as Map<String, dynamic>;
            final choices = jsonData['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield content;
              }
            }
          } catch (_) {}
        }
      }
    } finally {
      // 持久化 client 不关闭，复用 TCP 连接
    }
  }

  String _cleanNarrative(String s) {
    return s.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]'), '');
  }

  Future<String> generateNarrative({
    required String prompt,
    required String mode,
    required Map<String, dynamic> context,
    required GameScript script,
    required String narrativeHistory,
  }) async {
    final systemPrompt = _buildWorldSystemPrompt(script, context, narrativeHistory);
    final modePrompt = _buildWorldUserPrompt(mode, context);
    final userPrompt = prompt.isNotEmpty ? '$prompt\n\n$modePrompt' : modePrompt;
    return _cleanNarrative(await _callApi(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: 1200,
      temperature: 0.8,
    ));
  }

  String _buildWorldSystemPrompt(
    GameScript script,
    Map<String, dynamic> context,
    String narrativeHistory, {
    String? currentEventHint,
    String playerCard = '',
    String locationContext = '',
    String memoryContext = '',
    String tensionSnapshot = '',
    String affectionContext = '',
    String worldReport = '',
    Map<String, double> affectionStates = const {},
  }) {
    final buf = StringBuffer();

    // ── 静态前缀（同剧本不变，命中 DeepSeek context cache）──
    buf.writeln('你是一个恋爱模拟游戏的叙事引擎。你需要根据详细设定生成生动、有画面感、大胆真实的剧情叙事。越细致越鲜活，越出格越精彩。');
    buf.writeln();
    buf.writeln('【世界观】');
    buf.writeln(script.world.setting);
    final atm = script.world.atmosphere;
    buf.writeln('氛围基调: ${atm['base_mood'] ?? ''}');
    buf.writeln('色调: ${atm['color_palette'] ?? ''}');
    buf.writeln('写作指引: ${atm['hint'] ?? ''}');
    // 注入剧本层文风规格（最高优先级，所有叙事严格遵守）
    final ws = atm['writing_style'];
    if (ws is Map<String, dynamic>) {
      buf.writeln();
      buf.writeln('【文风规格·严格遵守】');
      buf.writeln('风格：${ws['label'] ?? ''}');
      final rules = ws['rules'];
      if (rules is List) {
        buf.writeln('规则：');
        for (final r in rules) {
          buf.writeln('- $r');
        }
      }
      if (ws['do_example'] != null) {
        buf.writeln('正例：${ws['do_example']}');
      }
      if (ws['dont_example'] != null) {
        buf.writeln('反例（禁止）：${ws['dont_example']}');
      }
    }
    buf.writeln();
    buf.writeln('【故事】基调${script.meta.tone} / 类型${script.meta.genre} / ${script.meta.summary}');
    buf.writeln();

    buf.writeln('【深度角色档案】（严格按以下设定扮演，不得偏离。注意：以下为角色完整档案，但角色当前对玩家的态度由【在场角色及当前状态】或上下文中的实时好感度决定——好感低于15=憎恶/回避，低于30=冷淡疏远，请勿按档案中的友好阶段描写。）');
    for (final c in script.characters.where((c) => c.fullCharacter)) {
      _writeCharProfile(buf, c);
    }
    buf.writeln();

    buf.writeln('【叙事格式规则】');
    buf.writeln('1. 用中文。可以描写世界/角色的行为与对话——只写世界/NPC的动作、神态、对话');
    buf.writeln('2. 不要替玩家描写玩家的意图与决定——玩家的选择已在剧情记录中，不要重复也不要擅自描写玩家在想什么');
    buf.writeln('3. 可以描写"你的"动作的后果（如"你的脚步声在走廊里回响"），但不要写"你决定走过去"这种替玩家做决定的句子');
    buf.writeln('4. 场景描写放在（）里，对话单独成行，动作与对话分行呈现，不要混成大段散文');
    buf.writeln('5. 动作与细节优先于台词和解释——写"她把脸转开了"别写"她感到难为情"');
    buf.writeln('6. 篇幅由情境决定。简短反应可以只有2-3行，复杂冲突/情绪转折可以写较长。宁短不凑，不强行写字数');
    buf.writeln('7. 角色行为严格遵守其soul/agent/speech/evolution设定');
    buf.writeln('8. 日常推进=当前时段片段，重要推进=整天发展');
    buf.writeln('9. 参考之前剧情保持连贯');
    buf.writeln('10. 允许描写角色间的暧昧张力、肢体接触、感官细节（气息、温度、触感、距离），允许直白露骨的亲密互动，越细致越鲜活');
    buf.writeln('11. 场景切换：当剧情自然需要转移地点时（如角色提议去某处、或情节推动需要换场景），在叙事末尾单独一行输出 [SCENE_SHIFT: location_id] 标记。location_id必须是剧本中已定义的地点id。玩家会收到确认弹窗，同意后切换场景继续叙事。不要强行切换——只在剧情自然需要时使用');
    buf.writeln();
    buf.writeln('【输出要求（最高优先级）】');
    buf.writeln('只输出叙事正文。不要输出JSON、代码、角色数据、系统提示、格式说明、元信息。如果无事可写，输出"一切如常。"四个字即可。');
    buf.writeln('以纯文学小说笔法写作，注重氛围、感官与情绪张力。');

    // ── 动态后缀（每次请求变化，放在静态前缀之后）──
    final plot = script.plot;
    if (plot != null) {
      final currentActId = plot.memory.currentAct;

      final tension = plot.narrativeTension.actualLevel;
      buf.writeln();
      buf.writeln('【剧情方向】');
      buf.writeln(_buildPlotDirectionHint(plot, currentActId, tension));

      buf.writeln();
      buf.writeln('【叙事张力】当前等级: ${tension.toStringAsFixed(1)}');
      for (final e in plot.narrativeTension.effects.entries) {
        final rangeMatch = RegExp(r'\d+').firstMatch(e.key);
        if (rangeMatch != null) {
          final threshold = double.tryParse(rangeMatch.group(0)!) ?? 0;
          if (tension >= threshold) {
            buf.writeln('  效果(${e.key}): ${e.value.hint}');
          }
        }
      }
      buf.writeln();

      final endingHints = _checkEndingProgress(plot);
      if (endingHints.isNotEmpty) {
        buf.writeln('【结局进度】$endingHints');
        buf.writeln();
      }

      final fsHint = _buildForeshadowHint(plot.foreshadowSystem);
      if (fsHint.isNotEmpty) {
        buf.writeln('【伏笔提示】$fsHint');
        buf.writeln();
      }
    }

    if (tensionSnapshot.isNotEmpty) {
      buf.writeln('【三维张力】$tensionSnapshot');
      buf.writeln();
    }

    if (currentEventHint != null && currentEventHint.isNotEmpty) {
      buf.writeln('【当前事件氛围】$currentEventHint');
      buf.writeln();
    }

    if (worldReport.isNotEmpty) {
      buf.writeln('【世界实时状态】');
      buf.writeln(worldReport);
      buf.writeln();
    }

    if (locationContext.isNotEmpty) {
      buf.writeln(locationContext);
      buf.writeln();
    }

    if (affectionContext.isNotEmpty) {
      buf.writeln('【角色好感度】');
      buf.writeln(affectionContext);
      buf.writeln();
    }

    // 好感阶段软约束：告诉AI每个角色当前的好感阶段及应有的态度
    if (affectionStates.isNotEmpty) {
      buf.writeln('【当前好感阶段约束 — 严格遵守】');
      for (final c in script.characters.where((c) => c.fullCharacter)) {
        final aff = affectionStates[c.basic.id];
        if (aff == null) continue;
        final stage = _affectionStageHint(aff);
        buf.writeln('${c.basic.name}（好感${aff.toStringAsFixed(1)}）: $stage');
      }
      buf.writeln();
    }

    buf.writeln(playerCard);

    if (memoryContext.isNotEmpty) {
      buf.writeln();
      buf.writeln(memoryContext);
    }

    if (narrativeHistory.isNotEmpty) {
      final recent = narrativeHistory.length > 800 ? narrativeHistory.substring(narrativeHistory.length - 800) : narrativeHistory;
      buf.writeln();
      buf.writeln('【最近剧情】');
      buf.writeln(recent);
    }
    return buf.toString();
  }

  String _buildPlotDirectionHint(GamePlot plot, String currentActId, double tension) {
    final buf = StringBuffer();
    buf.writeln('前提: ${plot.premise}');

    if (currentActId.isNotEmpty) {
      final act = plot.acts.where((a) => a.id == currentActId).firstOrNull;
      if (act != null) {
        buf.writeln('当前幕: ${act.name}（${act.description}）');
        buf.writeln('叙事方向: ${act.narrativeDirection}');
        if (act.tone.isNotEmpty) buf.writeln('基调: ${act.tone}');
        final ph = act.pacingHint;
        buf.writeln('节奏: 剧情${(ph.plotRatio * 100).toStringAsFixed(0)}% / 日常${(ph.dailyRatio * 100).toStringAsFixed(0)}% / 甜${(ph.sweetRatio * 100).toStringAsFixed(0)}%');
        if (act.mandatoryBeats.isNotEmpty) {
          buf.writeln('必须节拍: ${act.mandatoryBeats.take(4).join('、')}');
        }
      } else {
        buf.writeln('当前幕: $currentActId');
      }
    }

    final tensionLabel = tension < 25 ? '低（轻松日常）' : tension < 50 ? '中低（暗流涌动）' : tension < 75 ? '中高（冲突升级）' : '高（高潮/转折）';
    buf.writeln('张力判断: $tensionLabel');

    return buf.toString();
  }

  String _buildForeshadowHint(ForeshadowSystem fs) {
    if (fs.planted.isEmpty) return '';
    final buf = StringBuffer();
    buf.writeln('已埋下的伏笔（需在后续叙事中自然呼应）:');
    for (final f in fs.planted.take(5)) {
      buf.writeln('  - ${f.hint} (→${f.targetBeat} ${f.payoffHint})');
    }
    return buf.toString();
  }

  String _checkEndingProgress(GamePlot plot) {
    final buf = StringBuffer();
    for (final ending in plot.endings) {
      final progress = plot.memory.endingProgress[ending.id] ?? 0.0;
      if (progress >= 0.5) {
        final label = progress >= 0.9 ? '即将触发' : progress >= 0.7 ? '接近中' : '可发展';
        buf.writeln('  ${ending.title}(${ending.typeDesc}): $label (${(progress * 100).toStringAsFixed(0)}%) ${ending.aiHint}');
      }
    }
    return buf.toString().trim();
  }

  static void _writeCharProfile(StringBuffer buf, Character c) {
    buf.writeln('--- ${c.basic.name} ---');
    buf.writeln('基础: ${c.basic.age}岁 ${c.basic.gender} ${c.basic.height} ${c.basic.weight}');
    buf.writeln('外貌: ${c.basic.avatarDesc}');
    buf.writeln('特征: ${c.basic.distinctiveMarks.join('、')}');
    if (c.summary.isNotEmpty) buf.writeln('概述: ${c.summary}');

    final bg = c.background;
    if (bg != null) {
      buf.writeln('出身: ${bg.origin}');
      buf.writeln('经历: ${bg.history}');
      buf.writeln('现状: ${bg.currentSituation}');
    }

    final soul = c.soul;
    if (soul != null) {
      buf.writeln('【灵魂核心】${soul.core}');
      buf.writeln('渴望: ${soul.desire}');
      buf.writeln('创伤: ${soul.wound}');
      buf.writeln('恐惧: ${soul.fear}');
      buf.writeln('矛盾: ${soul.contradiction}');
      buf.writeln('对外人: ${soul.dualMode.toStranger}');
      buf.writeln('对亲密者: ${soul.dualMode.toClose}');
    }

    final agent = c.agent;
    if (agent != null) {
      buf.writeln('角色定位: ${agent.role}');
      buf.writeln('内在动机: ${agent.agenda}');
    }

    final speech = c.speech;
    if (speech != null) {
      final b5 = speech.bigFiveProfile;
      buf.writeln('【说话】开放${b5.openness}外向${b5.extraversion}宜人${b5.agreeableness}尽责${b5.conscientiousness}神经${b5.neuroticism}');
      buf.writeln('声线: ${speech.phonetics.pitch}');
      buf.writeln('语速: ${speech.phonetics.pace}');
      buf.writeln('用词风格: ${speech.vocabulary.style}');
      buf.writeln('回避词: ${speech.vocabulary.avoid.join('、')}');
      buf.writeln('对外说话: ${speech.dualMode.toStranger.overview}（例：${speech.dualMode.toStranger.example}）');
      buf.writeln('对亲近者: ${speech.dualMode.toClose.overview}（例：${speech.dualMode.toClose.example}）');
    }

    final humanity = c.humanity;
    if (humanity != null) {
      buf.writeln('【写作风格】自然、大胆。用动作和细节传递情绪，而非直接陈述。沉默也是表达。允许暧昧张力、感官描写（气息、温度、触感、距离），允许直白露骨的亲密互动描写。');
      buf.writeln('非语言动作库: ${humanity.nonVerbal.take(4).join(' | ')}');
    }

    final pref = c.preferences;
    if (pref != null) {
      buf.writeln('喜好: ${pref.likes.join('、')}');
      buf.writeln('厌恶: ${pref.dislikes.join('、')}');
    }

    final evo = c.evolution;
    if (evo != null && evo.affectionStages.isNotEmpty) {
      buf.writeln('【好感度态度】');
      for (final s in evo.affectionStages.take(6)) {
        buf.writeln('  ${s.range}: ${s.narrativeHint}');
      }
    }

    final mob = c.moodTriggers;
    if (mob != null) {
      buf.writeln('开心触发: ${mob.joy.take(2).join(' | ')}');
      buf.writeln('生气触发: ${mob.anger.take(2).join(' | ')}');
      buf.writeln('难过触发: ${mob.sadness.take(2).join(' | ')}');
      buf.writeln('嫉妒触发: ${mob.jealous.take(2).join(' | ')}');
    }

    final gift = c.giftResponse;
    if (gift != null) {
      buf.writeln('送礼反应: 喜欢=${gift.love.reaction} | 讨厌=${gift.hate.reaction}');
    }

    final bnd = c.boundary;
    if (bnd != null) {
      buf.writeln('【禁忌与边界】');
      if (bnd.physical.isNotEmpty) buf.writeln('物理边界: ${bnd.physical}');
      if (bnd.emotional.isNotEmpty) buf.writeln('情感边界: ${bnd.emotional}');
      if (bnd.paceHint.isNotEmpty) buf.writeln('节奏提示: ${bnd.paceHint}');
      if (bnd.topicTaboo.isNotEmpty) buf.writeln('话题禁区（触碰则-3.0）: ${bnd.topicTaboo.join(' | ')}');
    }
  }

  String buildCharProfile(Character c) {
    final buf = StringBuffer();
    _writeCharProfile(buf, c);
    return buf.toString();
  }

  String _buildWorldUserPrompt(String mode, Map<String, dynamic> context) {
    final day = context['day'] ?? '1';
    final season = context['season'] ?? '春';
    final weather = context['weather'] ?? '晴';
    final phase = context['phase'] ?? '上午';
    final weekday = context['weekday'] ?? '';
    final isWeekend = context['is_weekend'] ?? false;
    if (mode == 'major') {
      return '请推进一整天的剧情。${weekday}第${day}天${season}季，天气${weather}。今天发生了什么重要的事？';
    }
    if (mode == 'scene') {
      return '玩家来到了新场景。${weekday}第${day}天${season}季${phase}，天气${weather}。描述这个场景和在场的人物。';
    }
    if (mode == 'interact') {
      return '玩家与角色互动。${weekday}第${day}天${season}季${phase}，天气${weather}。描述互动细节。';
    }
    if (mode == 'skip_days') {
      return '玩家跳过了多天时间。请根据当前时间（第${day}天${season}季${weekday}，天气${weather}），概括这段时间发生的主要变化：季节更替、与角色的关系变化、重要事件。不必逐日描述，用"这几周来""这段时间"概括。';
    }
    // phase_pass / daily
    final phaseHints = {
      '凌晨': '夜深人静，大多数人都在睡觉。只有少数夜猫子还在活动。',
      '清晨': '天刚亮。角色应该在起床、晨练、上学/上班路上。',
      '上午': '上午的课程/工作刚开始。',
      '中午': '午餐时间。食堂、天台、树下。',
      '下午': '下午的课程/活动。',
      '傍晚': '天色渐暗。晚饭前后，社团活动结束。${isWeekend ? "周末的傍晚" : ""}',
      '夜晚': '夜晚了。${isWeekend ? "周末的夜晚，可以外出或在家休息。" : "该回家了，或者在家看书休息。"}',
    };
    final hint = phaseHints[phase] ?? '';
    final weekendNote = isWeekend ? '今天是周末，不用上学。' : '';
    return '${weekendNote}${weekday}第${day}天${season}季${phase}，天气${weather}。$hint\n请延续前面的叙事，写这个时段发生了什么。注意：地点和角色行为必须符合当前时段。如果是在学校，夜晚时段角色应该已经离开学校了。';
  }

  Future<List<Map<String, dynamic>>> generateChoices({
    required GameScript script,
    required String narrativeHistory,
    bool isLongEvent = false,
    Map<String, double> affectionStates = const {},
    String currentLocation = '',
    String currentPhase = '',
    List<String> sceneChars = const [],
  }) async {
    final recentNarrative = narrativeHistory.length > 1200
        ? narrativeHistory.substring(narrativeHistory.length - 1200)
        : narrativeHistory;

    final buf = StringBuffer();
    buf.writeln('你是一个恋爱模拟游戏的选项生成器。');
    buf.writeln('根据当前剧情为玩家生成2个建议行动方向。玩家也可以通过自由输入做任何行动。');
    buf.writeln();
    final names = script.characters.where((c) => c.fullCharacter).map((c) => c.basic.name).join('、');
    final ids = script.characters.where((c) => c.fullCharacter).map((c) => c.basic.id).join('、');
    buf.writeln('场景中的角色名: $names');
    buf.writeln('角色ID: $ids');
    if (sceneChars.isNotEmpty) {
      final presentNames = sceneChars.map((cid) =>
        script.characters.where((c) => c.basic.id == cid).firstOrNull?.basic.name ?? cid
      ).join('、');
      buf.writeln('当前在场角色: $presentNames');
    }
    if (currentLocation.isNotEmpty) buf.writeln('当前地点: $currentLocation');
    if (currentPhase.isNotEmpty) buf.writeln('当前时段: $currentPhase');
    // 注入在场角色好感度，让选项强度匹配关系阶段
    if (affectionStates.isNotEmpty && sceneChars.isNotEmpty) {
      final affInfo = <String>[];
      for (final cid in sceneChars) {
        final aff = affectionStates[cid];
        if (aff != null) {
          final charName = script.characters.where((c) => c.basic.id == cid).firstOrNull?.basic.name ?? cid;
          affInfo.add('$charName(${aff.toStringAsFixed(0)})');
        }
      }
      if (affInfo.isNotEmpty) buf.writeln('好感度: ${affInfo.join('、')}');
    }
    buf.writeln();
    buf.writeln('要求：');
    buf.writeln('1. 每个建议是玩家可以执行的行动方向，用简短中文描述（不超过15字）');
    buf.writeln('2. **选项必须延续当前叙事氛围**——当前是亲密时刻就给亲密选项，冲突时刻就给冲突选项，日常就给日常选项。不要在亲密时刻突然插入谈心，也不要在冲突时突然插入暧昧');
    buf.writeln('3. 两个建议给出不同方向（如：主动行动/观察等待，或 顺水推舟/另起话题）');
    buf.writeln('4. 选项的亲密度应匹配当前好感度阶段——好感<30不要给暧昧选项，好感>70才允许亲密选项');
    if (isLongEvent) {
      buf.writeln('5. 这是长事件的中间步骤，选项应推动事件向前发展');
    }
    buf.writeln('6. 纯JSON数组返回，不要额外文字');
    buf.writeln('格式：[{"text":"行动描述", "delta": 数字(好感度变化), "target":"角色id"}, ...]');
    buf.writeln();

    final result = await _callApi(
      systemPrompt: buf.toString(),
      userPrompt: '【当前剧情】\n$recentNarrative\n\n生成2个建议行动方向。',
      maxTokens: 512,
      temperature: 0.85,
    );
    return _parseChoices(result);
  }

  List<Map<String, dynamic>> _parseChoices(String raw) {
    final match = RegExp(r'\[[\s\S]*\]').firstMatch(raw);
    if (match != null) {
      try {
        final list = jsonDecode(match.group(0)!) as List;
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }
    return [
      {'text': '主动上前打招呼', 'delta': 1.5},
      {'text': '在远处静静观察', 'delta': 0.5},
      {'text': '故意引起注意', 'delta': -0.5},
    ];
  }

  Future<String> generateChoiceResponse({
    required String choice,
    required GameScript script,
    required String narrativeHistory,
    required Map<String, dynamic> timeContext,
    bool isContinuation = false,
    CharacterMemoryService? charMemory,
    String targetCharId = '',
    Map<String, double> affectionStates = const {},
  }) async {
    final recentNarrative = narrativeHistory.length > 1200
        ? narrativeHistory.substring(narrativeHistory.length - 1200)
        : narrativeHistory;

    String memoryContext = '';
    if (charMemory != null && targetCharId.isNotEmpty) {
      memoryContext = charMemory.buildMemoryContext(targetCharId);
    }

    final sysPrompt = _buildWorldSystemPrompt(
      script, timeContext, narrativeHistory,
      memoryContext: memoryContext,
      affectionStates: affectionStates,
    );

    String task;
    if (isContinuation) {
      task = '以下是最新的剧情记录。玩家在这个长事件中选择了「$choice」。'
          '你需要继续推进同一个事件的叙事，保持情节和角色的连贯。'
          '只写角色反应和世界变化——不要重复描写玩家的选择，也不要替玩家描写决定。'
          '篇幅由情境决定：简短反应可以只有2-3行，复杂冲突可以写较长。事件还有后续步骤，请在末尾为下一步留下自然的承接。\n\n'
          '【完整剧情记录】\n$recentNarrative';
    } else {
      task = '以下是最新的剧情记录。玩家选择了「$choice」。'
          '你需要紧接上文继续叙事，保持情节连贯、角色行为一致。'
          '只写角色反应和世界变化——不要重复描写玩家的选择，也不要替玩家描写决定。'
          '篇幅由情境决定。\n\n'
          '【完整剧情记录】\n$recentNarrative';
    }

    return _callApi(
      systemPrompt: sysPrompt,
      userPrompt: task,
      maxTokens: 1200,
      temperature: 0.8,
    );
  }

  Future<String> generateSceneEventNarrative({
    required SceneLocation location,
    required Character character,
    required double affection,
    required GameScript script,
    required String narrativeHistory,
    CharacterMemoryService? charMemory,
  }) async {
    final locationContext = '【场景】${location.name}\n描述: ${location.desc}\n氛围: ${location.sceneMoods.join('、')}\n提示: ${location.eventsHint}\n可见性: ${location.visibilityDefault == "private" ? "私密场合" : "公共场所"}';

    final affectionContext = '${character.basic.name}(${character.basic.id}): 好感${affection.toStringAsFixed(2)}';

    String memoryContext = '';
    if (charMemory != null) {
      memoryContext = charMemory.buildMemoryContext(character.basic.id);
    }

    final sysPrompt = _buildWorldSystemPrompt(
      script,
      {'day': 1, 'season': '', 'weather': '', 'phase': ''},
      narrativeHistory,
      locationContext: locationContext,
      affectionContext: affectionContext,
      memoryContext: memoryContext,
      affectionStates: {character.basic.id: affection},
    );

    return _callApi(
      systemPrompt: sysPrompt,
      userPrompt: '玩家来到${location.name}，遇到了${character.basic.name}。请描述这次偶遇互动。当前的好感度是${affection.toStringAsFixed(1)}，请据此决定角色对待玩家的态度和反应。',
      maxTokens: 1100,
      temperature: 0.8,
    );
  }

  Future<String> generateSceneAtmosphere({
    required SceneLocation location,
    required List<Character> presentChars,
    required int currentDay,
    required String season,
    required String weather,
    required String phase,
    required GameScript script,
    required String playerCard,
    CharacterMemoryService? charMemory,
  }) async {
    final buf = StringBuffer();
    buf.writeln(_buildWorldSystemPrompt(script, {
      'day': currentDay, 'season': season, 'weather': weather, 'phase': phase,
    }, ''));
    buf.writeln();

    buf.writeln('【场景描述】');
    buf.writeln('地点: ${location.name}');
    buf.writeln('描述: ${location.desc}');
    buf.writeln('氛围提示: ${location.eventsHint}');
    buf.writeln('可见性: ${location.visibilityDefault == "private" ? "私密场合" : "公共场所"}');
    buf.writeln();

    buf.writeln('【当前时空】');
    buf.writeln('第${currentDay}天 ${season}季 ${weather} ${phase}');
    buf.writeln();

    buf.writeln(playerCard);

    if (presentChars.isNotEmpty) {
      buf.writeln();
      buf.writeln('【在场角色】');
      for (final char in presentChars) {
        buf.writeln(buildCharProfile(char));
      }
    }

    if (charMemory != null && presentChars.isNotEmpty) {
      for (final c in presentChars) {
        final mc = charMemory.buildMemoryContext(c.basic.id);
        if (mc.isNotEmpty) {
          buf.writeln(mc);
        }
      }
    }

    return _callApi(
      systemPrompt: buf.toString(),
      userPrompt: '你站在${location.name}。请用一段叙事描述当前的场景氛围：光线、声音、气味、在场角色的状态。场景描写放在（）里，对话单独成行。不要替玩家做任何决定。篇幅由情境决定，宁短不凑。',
      maxTokens: 800,
      temperature: 0.8,
    );
  }

  Future<String> generateCustomActionConsequence({
    required String action,
    required GameScript script,
    required String narrativeHistory,
    required String playerCard,
    required Map<String, dynamic> timeContext,
    required List<Character> characters,
    required Map<String, double> affectionStates,
    CharacterMemoryService? charMemory,
    String targetCharId = '',
  }) async {
    final ruling = script.gameInteraction?.advanceModes['free']?.rulingEngine;

    final affectionBuf = StringBuffer();
    for (final c in characters.where((c) => c.fullCharacter)) {
      final aff = affectionStates[c.basic.id] ?? 50.0;
      affectionBuf.writeln('${c.basic.name}(${c.basic.id}): 好感${aff.toStringAsFixed(1)}');
    }

    String memoryContext = '';
    if (charMemory != null && targetCharId.isNotEmpty) {
      memoryContext = charMemory.buildMemoryContext(targetCharId);
    }

    String rulingContext = '';
    if (ruling != null) {
      rulingContext = '【行动合法性】${ruling.reasonabilityHint}\n暴力政策: ${ruling.violencePolicy}';
      if (ruling.outputRules.isNotEmpty) {
        rulingContext += '\n【裁定规则 — 来自脚本定义】';
        for (final r in ruling.outputRules) {
          rulingContext += '\n  $r';
        }
      }
    }

    final sysPrompt = _buildWorldSystemPrompt(
      script, timeContext, narrativeHistory,
      playerCard: playerCard,
      affectionContext: affectionBuf.toString(),
      memoryContext: memoryContext,
      currentEventHint: rulingContext,
      affectionStates: affectionStates,
    );

    return _callApi(
      systemPrompt: sysPrompt,
      userPrompt: '玩家行动: $action',
      maxTokens: 1200,
      temperature: 0.8,
    );
  }

  Future<String> generateChatReply({
    required String userMessage,
    required Character character,
    required double affection,
    required List<Map<String, String>> chatHistory,
    required String playerName,
    required String worldContext,
    GameScript? script,
    String narrativeHistory = '',
    String memoryContext = '',
    String rankingContext = '',
    String locationContext = '',
  }) async {
    return _callApi(
      systemPrompt: _buildChatSystemPrompt(character, affection, playerName, worldContext, script: script, narrativeHistory: narrativeHistory, memoryContext: memoryContext, rankingContext: rankingContext, locationContext: locationContext),
      userPrompt: userMessage,
      maxTokens: 512,
      temperature: 0.9,
      history: chatHistory,
    );
  }

  /// 角色主动发起消息（非回复玩家）
  /// [trigger] 触发原因：drama=修罗场事件，care=日常关心，provocation=挑衅
  /// [triggerContext] 触发上下文（如"听说玩家和某人亲密"）
  Future<String> generateInitiativeMessage({
    required Character character,
    required double affection,
    required List<Map<String, String>> chatHistory,
    required String playerName,
    required String worldContext,
    String trigger = 'care',
    String triggerContext = '',
    GameScript? script,
    String narrativeHistory = '',
    String memoryContext = '',
  }) async {
    final sysPrompt = _buildChatSystemPrompt(
      character, affection, playerName, worldContext,
      script: script,
      narrativeHistory: narrativeHistory,
      memoryContext: memoryContext,
    );

    String userPrompt;
    switch (trigger) {
      case 'drama':
        userPrompt = '你现在主动给$playerName发消息。原因：$triggerContext\n'
            '请以角色的口吻发一条消息给$playerName。可以是质问、试探、阴阳怪气、装作不经意提起——由你的性格和当前好感度决定。\n'
            '只输出消息内容本身，不要加引号、不要加旁白、不要描写动作。就像微信发一条消息。';
        break;
      case 'provocation':
        userPrompt = '你现在主动给$playerName发消息。原因：$triggerContext\n'
            '请以角色的口吻发一条挑衅或找茬的消息。由你的性格决定方式——可以是阴阳怪气、直接质问、或者装作无意。\n'
            '只输出消息内容本身，不要加引号、不要加旁白。就像微信发一条消息。';
        break;
      default:
        userPrompt = '你现在主动给$playerName发一条消息。'
            '不需要特别理由——可以是日常问候、想起什么想说、看到什么联想到$playerName、或者就是想聊天。'
            '由你的性格和当前好感度决定发什么、语气如何。好感低可以是不耐烦的催促或冷冷的命令，好感高可以是撒娇或关心。'
            '只输出消息内容本身，不要加引号、不要加旁白、不要描写动作。就像微信发一条消息。';
    }

    return _callApi(
      systemPrompt: sysPrompt,
      userPrompt: userPrompt,
      maxTokens: 256,
      temperature: 0.95,
      history: chatHistory,
    );
  }

  Stream<String> generateChatReplyStreaming({
    required String userMessage,
    required Character character,
    required double affection,
    required List<Map<String, String>> chatHistory,
    required String playerName,
    required String worldContext,
    GameScript? script,
    String narrativeHistory = '',
    String memoryContext = '',
    String rankingContext = '',
    String locationContext = '',
  }) {
    return _callApiStreaming(
      systemPrompt: _buildChatSystemPrompt(character, affection, playerName, worldContext, script: script, narrativeHistory: narrativeHistory, memoryContext: memoryContext, rankingContext: rankingContext, locationContext: locationContext),
      userPrompt: userMessage,
      maxTokens: 512,
      temperature: 0.9,
      history: chatHistory,
    );
  }

  String _buildChatSystemPrompt(Character character, double affection, String playerName, String worldContext, {GameScript? script, String narrativeHistory = '', String memoryContext = '', String rankingContext = '', String focus = '', String locationContext = ''}) {
    final buf = StringBuffer();
    final isClose = affection >= 60;
    final f = focus.isNotEmpty ? focus : null;
    final bool hostile = affection < 10;
    final bool hatred = affection >= 10 && affection < 20;
    final bool detest = affection >= 20 && affection < 30;
    final bool dislike = affection >= 30 && affection < 40;
    final bool mildDislike = affection >= 40 && affection < 50;
    buf.writeln('你现在就是这个角色，正在用微信和$playerName聊天。只发文字消息，就像真人微信聊天一样。');
    buf.writeln();
    buf.writeln('【当前】$worldContext');
    if (locationContext.isNotEmpty) buf.writeln('地点: $locationContext');
    buf.writeln();
    buf.writeln('【角色档案】${character.basic.name} ${character.basic.age}岁${character.basic.gender}');
    buf.writeln('概述: ${character.summary}');

    final soul = character.soul;
    if (soul != null) {
      buf.writeln('灵魂: ${soul.core}');
      buf.writeln('渴望: ${soul.desire}');
      if (hostile) {
        buf.writeln('对死敌: 见面即杀意。不必掩饰敌意。可以冷暴力、嘲讽、威胁、公开对峙。你不躲——你在找机会。沉默的时候不是回避——是在衡量怎么下手。');
      } else if (hatred) {
        buf.writeln('对仇人: 深刻敌意。主动加害。不放过任何机会让你难受。');
      } else if (detest) {
        buf.writeln('对憎恨之人: 强烈反感。避之不及，开口必带刺。');
      } else if (dislike) {
        buf.writeln('对厌恶之人: 明显不喜欢。不情愿接触，回应冷淡简短。');
      } else if (mildDislike) {
        buf.writeln('对轻微厌恶之人: 有些不顺眼。客气但疏远，字少话冷。');
      } else if (isClose) {
        buf.writeln('对亲近者: ${soul.dualMode.toClose}');
      } else {
        buf.writeln('对外人: ${soul.dualMode.toStranger}');
      }
    }

    final agent = character.agent;
    if (agent != null) buf.writeln('定位: ${agent.role} / 动机: ${agent.agenda}');

    final speech = character.speech;
    if (speech != null) {
      buf.writeln('语气: ${speech.phonetics.pitch} ${speech.phonetics.pace}');
      buf.writeln('用词: ${speech.vocabulary.style} 回避${speech.vocabulary.avoid.join('、')}');
      if (hostile) {
        buf.writeln('对话模式: 进攻性。不回避——主动挑衅。话里藏刀。沉默也是武器——不是无话可说，是让你猜。');
      } else if (hatred || detest || dislike || mildDislike) {
        buf.writeln('对话模式: 极简短。不接话茬。已读不回也可以。拒绝任何温度。');
      } else if (isClose) {
        buf.writeln('对话模式: ${speech.dualMode.toClose.overview} ${speech.dualMode.toClose.example}');
      } else {
        buf.writeln('对话模式: ${speech.dualMode.toStranger.overview} ${speech.dualMode.toStranger.example}');
      }
    }

    final humanity = character.humanity;
    if (humanity != null) {
      buf.writeln('聊天风格: 纯文字消息，像真人微信。不要描写动作、神态、心理、环境。不要用*括号*或（括号）写动作。');
    }

    final evo = character.evolution;
    if (evo != null && evo.affectionStages.isNotEmpty) {
      for (final s in evo.affectionStages) {
        if (_affectionInRange(affection, s.range)) {
          buf.writeln('当前态度: ${s.narrativeHint}');
          break;
        }
      }
    }

    buf.writeln();
    buf.writeln('当前好感${affection.toStringAsFixed(1)}。');
    if (affection < 10) {
      buf.writeln('死敌——不共戴天，见面即杀意。回复可以含威胁/嘲讽/冷血。你不是在回避——你在逼近。不必留情。');
    } else if (affection < 20) {
      buf.writeln('仇恨——对你怀有深刻敌意。回复应冷淡、抵触、拒绝任何情感窗口。');
    } else if (affection < 30) {
      buf.writeln('憎恨——强烈反感，避之不及。回复简短、抗拒、不想多说一个字。');
    } else if (affection < 40) {
      buf.writeln('厌恶——明显不喜欢你。回复应不情愿、疏远、尽量结束对话。');
    } else if (affection < 50) {
      buf.writeln('轻微厌恶——有些不顺眼。回复应客气但冷淡、保持距离。');
    } else if (affection < 60) {
      buf.writeln('陌生人——无感，点头之交。回复自然、中性、不主动也不回避。');
    } else if (affection < 70) {
      buf.writeln('有好感——愿意接触。回复自然、有回应、偶尔主动。');
    } else if (affection < 80) {
      buf.writeln('欣赏——主动关注。回复温暖、主动、乐意交流。');
    } else if (affection < 90) {
      buf.writeln('喜欢——明显亲近意愿。回复亲密、主动、会撒娇或嘴硬。通过文字语气表达暧昧，允许描写肢体接触与感官细节。');
    } else if (affection < 100) {
      buf.writeln('爱——深度依恋。回复温柔、深情、会为你做任何事。通过文字表达深情，允许描写触感、温度、呼吸等感官细节。');
    } else {
      buf.writeln('永恒唯一——灵魂绑定。回复极致亲密，通过文字语气和用词表达深层羁绊，允许描写皮肤触感、气息交缠等感官细节。');
    }
    buf.writeln('回复拆分为2-4条短消息，用===MSG===分隔。每条消息像微信发的一条文字，简短零碎。不要描写动作、神态、心理、环境。不要用*括号*或（括号）。不要加旁白或总结。');

    final bnd = character.boundary;
    if (bnd != null) {
      String taboo = '';
      if (bnd.topicTaboo.isNotEmpty) taboo = ' | 【禁区】玩家触碰以下任何话题直接-3.0好感：${bnd.topicTaboo.join('；')}';
      if (bnd.emotional.isNotEmpty) {
        buf.writeln('【情感边界】${bnd.emotional}$taboo');
      } else if (taboo.isNotEmpty) {
        buf.writeln(taboo.substring(3));
      }
      if (bnd.paceHint.isNotEmpty) buf.writeln('【节奏】${bnd.paceHint}');
    }

    if (script != null) {
      final chatRestrictions = script.dialogue?.chatRestrictions;
      if (chatRestrictions != null && chatRestrictions.isNotEmpty) {
        buf.writeln();
        buf.writeln('【聊天限制】');
        final freq = chatRestrictions['frequency'];
        if (freq != null) buf.writeln('频率: ${freq['hint'] ?? freq.toString()}');
        final boundary = chatRestrictions['boundary'];
        if (boundary != null) buf.writeln('边界: ${boundary['hint'] ?? boundary.toString()}');
        final redLines = chatRestrictions['red_lines'];
        if (redLines is List && redLines.isNotEmpty) buf.writeln('红线: ${(redLines).join('、')}');
      }

      final gifting = script.gameItems?.gifting;
      if (gifting != null) {
        buf.writeln();
        buf.writeln('【送礼提示】');
        final reactionRule = gifting.reactionRule;
        if (reactionRule.isNotEmpty) {
          buf.writeln('反应规则: ${reactionRule['hint'] ?? reactionRule.toString()}');
        }
        if (gifting.uniqueGiftRule.isNotEmpty) buf.writeln('特殊规则: ${gifting.uniqueGiftRule}');
        if (gifting.chainGifting.isNotEmpty) buf.writeln('连赠: ${gifting.chainGifting}');
      }
    }

    buf.writeln('你在和$playerName聊天。$worldContext');
    if (memoryContext.isNotEmpty) {
      buf.writeln(memoryContext);
      buf.writeln();
    }
    if (rankingContext.isNotEmpty) {
      buf.writeln(rankingContext);
      buf.writeln();
    }
    if (narrativeHistory.isNotEmpty) {
      final recent = narrativeHistory.length > 300 ? narrativeHistory.substring(narrativeHistory.length - 300) : narrativeHistory;
      buf.writeln('【最近发生的事】$recent');
    }
    return buf.toString();
  }

  bool _affectionInRange(double val, String range) {
    final parts = range.split('-');
    if (parts.length == 2) {
      final lo = double.tryParse(parts[0].trim()) ?? 0;
      final hi = double.tryParse(parts[1].trim()) ?? 100;
      return val >= lo && val < hi;
    }
    if (range == '100') return val >= 99.5;
    final v = double.tryParse(range.trim());
    return v != null && val >= v;
  }

  /// 好感阶段软约束提示文本
  /// 与_buildChatSystemPrompt中的11段约束保持一致
  static String _affectionStageHint(double aff) {
    if (aff < 10) return '死敌——不共戴天，见面即杀意。描写应体现敌意、回避或主动加害';
    if (aff < 20) return '仇恨——深刻敌意。描写应冷淡、抵触、拒绝任何情感窗口';
    if (aff < 30) return '憎恨——强烈反感，避之不及。描写应简短、抗拒、不愿多说';
    if (aff < 40) return '厌恶——明显不喜欢。描写应不情愿、疏远、尽量结束接触';
    if (aff < 50) return '轻微厌恶——有些不顺眼。描写应客气但冷淡、保持距离';
    if (aff < 60) return '陌生人——无感，点头之交。描写应自然、中性、不主动也不回避';
    if (aff < 70) return '有好感——愿意接触。描写应自然、有回应、偶尔主动';
    if (aff < 80) return '欣赏——主动关注。描写应温暖、主动、乐意交流';
    if (aff < 90) return '喜欢——明显亲近意愿。描写应亲密、主动，可有肢体接触暗示和暧昧张力';
    if (aff < 100) return '爱——深度依恋。描写应温柔、深情，允许亲密互动的感官细节（文学化笔法，留白多于直白）';
    return '永恒唯一——灵魂绑定。允许大胆描写亲密场景的感官氛围（纯文学笔法，重在氛围与张力）';
  }

  /// 会话压缩：把一次场景互动/行动会话的全部叙事压缩成结构化摘要
  /// 摘要存入 charMemory，作为长期记忆永不丢失
  Future<String> summarizeSession({
    required List<String> sessionSegments,
    required int day,
    required String locationContext,
    required String playerName,
  }) async {
    if (sessionSegments.isEmpty) return '';
    final fullText = sessionSegments.join('\n\n');
    // 超长文本先做硬截断（保留首尾，中间省略），避免 token 爆炸
    String input = fullText;
    if (input.length > 6000) {
      final head = input.substring(0, 2000);
      final tail = input.substring(input.length - 3000);
      input = '$head\n\n[……中间省略${input.length - 5000}字……]\n\n$tail';
    }
    final systemPrompt = '你是叙事摘要引擎。把一次互动会话的全部叙事压缩为结构化摘要，'
        '用于角色的长期记忆。保留关键信息，丢弃流水账。'
        '输出格式（严格）：\n'
        '第X天·地点：\n'
        '- 关键事件：1-2 句话概括发生了什么（冲突/破冰/告白/误会等）\n'
        '- 关系变化：涉及的角色和好感变化方向（如"夏娇娇 破冰"）\n'
        '- 重要对话：玩家说的关键话或角色说的关键话（如有，1 句）\n'
        '- 伏笔/细节：值得记住的细节（如有，1 句）\n\n'
        '要求：\n'
        '1. 总字数 ≤ 150 字\n'
        '2. 只输出摘要，不要输出原文\n'
        '3. 没有关键事件的日常互动，输出"日常互动，无特殊事件"即可\n'
        '4. 使用中文';
    final userPrompt = '第$day天，地点：$locationContext\n主角：$playerName\n\n以下是本次互动的全部叙事：\n\n$input\n\n请生成结构化摘要。';
    return _callApi(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: 400,
      temperature: 0.3,
      timeoutSeconds: 120,
    );
  }

  Future<double> analyzeAffectionDelta({
    required String playerMessage,
    required String aiReply,
    required Character character,
    required double currentAffection,
  }) async {
    final buf = StringBuffer();
    buf.writeln('你是情感分析器。分析玩家消息对角色好感度的影响，只输出一个数字。');
    buf.writeln();
    buf.writeln('【基础评分】');
    buf.writeln('+3.0=极其甜蜜/浪漫/深情 +1.5=友好/关心 +0.5=中性聊天 -0.5=轻微冒犯 -1.5=明显失礼 -3.0=严重伤害');
    buf.writeln();

    final bnd = character.boundary;
    if (bnd != null && bnd.topicTaboo.isNotEmpty) {
      buf.writeln('【禁区裁决 — 优先于基础评分】');
      buf.writeln('玩家消息如果触碰以下任何禁区，直接返回负值，不管语气多好：');
      for (final t in bnd.topicTaboo) {
        buf.writeln('  - $t');
      }
      buf.writeln('触碰禁区：最低-1.5，直接问出口-3.0。绕道试探-0.5。');
      buf.writeln();
    }

    buf.writeln('当前好感: ${currentAffection.toStringAsFixed(1)}');
    if (bnd != null) {
      if (bnd.emotional.isNotEmpty) buf.writeln('情感边界: ${bnd.emotional}');
      if (bnd.paceHint.isNotEmpty) buf.writeln('节奏: ${bnd.paceHint}');
    }
    buf.writeln('玩家消息: $playerMessage');
    buf.writeln('角色回复: $aiReply');
    buf.writeln();
    buf.writeln('只输出数字，如: -3.0 或 +1.5 或 -0.5');

    final result = await _callApi(systemPrompt: buf.toString(), userPrompt: '', maxTokens: 16, temperature: 0.1);
    return _parseAffectionDelta(result.trim());
  }

  double _parseAffectionDelta(String raw) {
    final match = RegExp(r'-?\d+\.?\d*').firstMatch(raw);
    if (match != null) {
      final val = double.tryParse(match.group(0)!) ?? 0.0;
      return val.clamp(-3.0, 3.0);
    }
    return 0.0;
  }

  Future<String> generateEventNarrative({
    required String eventType,
    required String aiHint,
    required GameScript script,
    required String narrativeHistory,
    required Map<String, dynamic> timeContext,
    String playerCard = '',
    Map<String, dynamic>? freeformContext,
    String worldReport = '',
    CharacterMemoryService? charMemory,
  }) async {
    String locationContext = '';
    String affectionContext = '';
    String memoryContext = '';
    String eventHint = '事件类型: $eventType';
    Map<String, double> affStates = {};

    if (freeformContext != null) {
      final loc = freeformContext['location_name'] ?? '';
      final locDesc = freeformContext['location_desc'] ?? '';
      final phase = freeformContext['phase'] ?? '';
      final weather = freeformContext['weather'] ?? '';
      final mood = freeformContext['mood'] ?? '';
      final charDetails = freeformContext['char_details'] as List<dynamic>? ?? [];

      locationContext = '【当前场景】$phase·$loc·$weather·氛围$mood';
      if (locDesc.isNotEmpty) locationContext += '\n场景描述: $locDesc';

      final affBuf = StringBuffer();
      for (final cd in charDetails) {
        final m = cd as Map<String, dynamic>;
        final char = script.characters.where((c) => c.basic.id == m['id']).firstOrNull;
        final name = char?.basic.name ?? m['id'];
        final affVal = (m['affection'] as num?)?.toDouble() ?? 50.0;
        affBuf.writeln('$name: 好感${m['affection']} ${m['tier']}${(m['relation'] != null && m['relation'].toString().isNotEmpty ? ' 关系:${m['relation']}' : '')}');
        affStates[m['id'] as String] = affVal;
        if (charMemory != null) {
          final mc = charMemory.buildMemoryContext(m['id'] as String);
          if (mc.isNotEmpty) memoryContext += mc + '\n';
        }
      }
      affectionContext = affBuf.toString();
      eventHint += '\n这是自由叙事事件。请根据在场角色的好感度、关系和性格设定，自然生成一段场景叙事。';
    } else {
      eventHint += '\n事件AI提示: $aiHint';
    }

    final sysPrompt = _buildWorldSystemPrompt(
      script, timeContext, narrativeHistory,
      playerCard: playerCard,
      locationContext: locationContext,
      affectionContext: affectionContext,
      memoryContext: memoryContext,
      worldReport: worldReport,
      currentEventHint: eventHint,
      affectionStates: affStates,
    );

    final prompt = freeformContext != null
        ? '生成日常自由叙事。当前在场角色: ${(freeformContext['char_details'] as List).map((c) => script.characters.where((ch) => ch.basic.id == c['id']).firstOrNull?.basic.name ?? c['id']).join('、')}。'
        : '生成${eventType}事件叙事。提示: $aiHint';

    return _callApi(
      systemPrompt: sysPrompt,
      userPrompt: prompt,
      maxTokens: 1200,
      temperature: 1.0,
    );
  }

  Future<String> generateWorldNarrative({
    required String mode,
    required dynamic directive,
    required int currentDay,
    required int totalDays,
    required String season,
    required String weather,
    required String phase,
    required String fullNarrativeHistory,
    required String playerCard,
    required String rankingContext,
    required List<String> charProfiles,
    required List<String> worldDynamicsLines,
    required String locationName,
    required String locationDesc,
    required String participantDetails,
    String? focus,
    String tensionSnapshot = '',
    String frequencyHooks = '',
    CharacterMemoryService? charMemory,
    bool isQuietDay = false,
  }) async {
    final w = directive.wordCount as int;
    final weightLabel = directive.weight.toString().split('.').last;
    final focusLabel = directive.focusLabel as String;
    final hint = directive.narrativeHint as String?;
    final effectiveFocus = focus ?? 'worldTexture';

    Map<String, dynamic>? route;
    if (!isQuietDay) {
      try {
        route = await _routeNarrative(
          currentDay: currentDay, totalDays: totalDays, season: season,
          weather: weather, phase: phase, locationName: locationName,
          participantDetails: participantDetails, tensionSnapshot: tensionSnapshot,
          collisionLines: worldDynamicsLines, infoGapLines: const [],
          recentHistory: fullNarrativeHistory.length > 400
              ? fullNarrativeHistory.substring(fullNarrativeHistory.length - 400)
              : fullNarrativeHistory,
        );
      } catch (_) { /* fallback */ }
    }

    final routedFocus = route?['primary_focus'] as String? ?? effectiveFocus;
    final routedShape = route?['narrative_shape'] as String? ?? 'dialogue_heavy';
    final routedTone = route?['tone'] as String? ?? '';
    final routedIntents = (route?['character_intents'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? <String, String>{};
    final routedTags = (route?['relevant_tags'] as List?)?.cast<String>() ?? <String>[];

    // ─── Step 2: Build prompt ───
    final buf = StringBuffer();

    if (isQuietDay) {
      buf.writeln('第${currentDay}天 · $season · $weather · $phase');

      if (tensionSnapshot.isNotEmpty) {
        buf.writeln('【三维张力】$tensionSnapshot');
      }

      if (participantDetails.isNotEmpty) {
        buf.writeln('\n【在场角色】');
        buf.writeln(participantDetails);
      }

      if (frequencyHooks.isNotEmpty) {
        buf.writeln('\n【日程提示】');
        buf.writeln(frequencyHooks);
      }

      buf.writeln('\n【玩家】');
      buf.writeln(playerCard);

      final quietHistory = fullNarrativeHistory.length > 400
          ? fullNarrativeHistory.substring(fullNarrativeHistory.length - 400)
          : fullNarrativeHistory;
      buf.writeln('\n---');
      buf.writeln('【最近发生的事】');
      buf.writeln(quietHistory);

      buf.writeln('\n---');
      buf.writeln('请根据以上信息写一段叙事。');
      buf.writeln('规则：');
      buf.writeln('1. 用（）描写环境，对话单独成行。不要替玩家写意图');
      buf.writeln('2. 从最近发生的事中接上情节，不要凭空开始新的一天');
      buf.writeln('3. 篇幅由情境决定，宁短不凑');

      return _cleanNarrative(await _callApi(
        systemPrompt: '你是一个恋爱模拟游戏的世界叙事引擎。根据设定生成生动、有画面感、大胆真实的世界叙事。越出格越精彩。',
        userPrompt: buf.toString(),
        temperature: 0.9,
        isWorldNarrative: true,
      ));
    }

    buf.writeln('【叙事权重】$weightLabel（篇幅由情境决定，不强行凑字。环境描写简短，对话与冲突较长）');
    buf.writeln('【叙事焦点】$focusLabel');
    if (route != null) {
      buf.writeln('【叙事形状】$routedShape');
      if (routedTone.isNotEmpty) buf.writeln('【基调】$routedTone');
    }
    if (hint != null && hint.isNotEmpty) {
      buf.writeln('【特殊指引】$hint');
    }
    buf.writeln();

    buf.writeln('【世界此刻】');
    buf.writeln('第${currentDay}天/$totalDays天 · $season · $weather · $phase');

    if (tensionSnapshot.isNotEmpty) {
      buf.writeln('【三维张力】$tensionSnapshot');
    }

    if (locationName.isNotEmpty) {
      buf.writeln('地点: $locationName');
      if (locationDesc.isNotEmpty) buf.writeln('$locationDesc');
    }

    if (participantDetails.isNotEmpty) {
      buf.writeln('\n【在场角色】');
      buf.writeln(participantDetails);
    }

    if (routedIntents.isNotEmpty) {
      buf.writeln('\n【角色此刻意图】');
      for (final e in routedIntents.entries) {
        buf.writeln('$e.key: $e.value');
      }
    }

    if (worldDynamicsLines.isNotEmpty || frequencyHooks.isNotEmpty) {
      buf.writeln('\n【世界动态】');
      for (final line in worldDynamicsLines) {
        buf.writeln(line);
      }
      if (frequencyHooks.isNotEmpty) {
        buf.writeln(frequencyHooks);
      }
    }

    buf.writeln('\n【玩家角色卡】');
    buf.writeln(playerCard);

    if (rankingContext.isNotEmpty) {
      buf.writeln('\n【排名数据 - 请严格使用此数据，不要编造】');
      buf.writeln(rankingContext);
    }

    if (charMemory != null && participantDetails.isNotEmpty) {
      final memBuf = StringBuffer();
      final pids = RegExp(r'\((\w+)\)').allMatches(participantDetails).map((m) => m.group(1)!).toList();
      for (final pid in pids) {
        final ctx = charMemory.buildMemoryContext(pid, filterTags: routedTags.isEmpty ? null : routedTags);
        if (ctx.isNotEmpty) {
          memBuf.writeln('【$pid】');
          memBuf.writeln(ctx);
        }
      }
      if (memBuf.isNotEmpty) {
        buf.writeln('\n【角色记忆（按当前焦点过滤）】');
        buf.writeln(memBuf.toString());
      }
    }

    if (charProfiles.isNotEmpty) {
      buf.writeln('\n---');
      buf.writeln('【所有角色档案】');
      for (final profile in charProfiles) {
        buf.writeln(_trimForFocus(profile, 'speech', routedFocus));
      }
    }

    buf.writeln('\n---');
    buf.writeln('【叙事历史（最近）】');
    final history = fullNarrativeHistory.length > 600
        ? fullNarrativeHistory.substring(fullNarrativeHistory.length - 600)
        : fullNarrativeHistory;
    buf.writeln(history);

    final shapeInstructions = _shapePrompt(routedShape, routedFocus);

    buf.writeln('\n---');
    buf.writeln('请根据以上信息写一段叙事。');
    buf.writeln('规则：');
    buf.writeln('1. 不要把上面的数据逐条罗列，而是展开一个具体的、可感的瞬间');
    buf.writeln('2. 重点描写角色的感受、互动和环境细节');
    buf.writeln('3. 纯叙事不含选项。篇幅由情境决定，不强行凑字');
    buf.writeln('4. $shapeInstructions');
    if (routedTone.isNotEmpty) {
      buf.writeln('5. 基调：$routedTone');
    }

    return _cleanNarrative(await _callApi(
      systemPrompt: '你是一个恋爱模拟游戏的世界叙事引擎。根据设定生成生动、有画面感、大胆真实的世界叙事。越出格越精彩。',
      userPrompt: buf.toString(),
      temperature: 0.9,
      isWorldNarrative: true,
    ));
  }

  // ─── Two-step Prompting: Route ───

  Future<Map<String, dynamic>?> _routeNarrative({
    required int currentDay,
    required int totalDays,
    required String season,
    required String weather,
    required String phase,
    required String locationName,
    required String participantDetails,
    required String tensionSnapshot,
    required List<String> collisionLines,
    required List<String> infoGapLines,
    required String recentHistory,
  }) async {
    final buf = StringBuffer();
    buf.writeln('你是叙事路由器。根据情境摘要，选择1个主要叙事焦点、2个次要焦点、叙事形状、基调，并为每个在场角色写1句话意图（不超过15字）。');
    buf.writeln();
    buf.writeln('焦点选项: characterMoment(角色瞬间), relationshipBeat(关系节拍), plotAdvancement(剧情推进), worldTexture(世界质感), tensionEscalation(张力升级), ensembleScene(群像场景)');
    buf.writeln('形状选项: dialogue_heavy(对话主导), montage(蒙太奇), reveal(信息揭示), tension_escalation(张力上升), quiet(静谧时刻), action_reaction(动作反应)');
    buf.writeln('基调选项: warm(温暖), tense(紧张), melancholic(忧伤), hopeful(期待), awkward(尴尬), subtle_tension(暗流)');
    buf.writeln('记忆标签: 考试, 暧昧, 吃醋, 共同经历, 第三方提及, 冲突, 日常, 核心记忆');
    buf.writeln();
    buf.writeln('情境: 第${currentDay}天/$totalDays · $season · $weather · $phase');
    if (locationName.isNotEmpty) buf.writeln('地点: $locationName');
    if (participantDetails.isNotEmpty) buf.writeln('在场: $participantDetails');
    if (tensionSnapshot.isNotEmpty) buf.writeln('张力: $tensionSnapshot');
    if (collisionLines.isNotEmpty) buf.writeln('日程: ${collisionLines.take(2).join(' | ')}');
    if (infoGapLines.isNotEmpty) buf.writeln('信息: ${infoGapLines.take(2).join(' | ')}');
    if (recentHistory.isNotEmpty) {
      buf.writeln('最近: ${recentHistory.length > 200 ? recentHistory.substring(recentHistory.length - 200) : recentHistory}');
    }
    buf.writeln();
    buf.writeln('输出纯JSON（不要markdown包裹）：');
    buf.writeln('{"primary_focus":"...","narrative_shape":"...","tone":"...","character_intents":{"角色名":"意图..."},"relevant_tags":["..."]}');

    final raw = await _callApi(
      systemPrompt: buf.toString(),
      userPrompt: '输出路由决策JSON。',
      maxTokens: 256,
      temperature: 0.3,
    );
    return _parseRouteResult(raw);
  }

  Map<String, dynamic>? _parseRouteResult(String raw) {
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
    if (match == null) return null;
    try {
      final map = json.decode(match.group(0)!) as Map<String, dynamic>;
      if (map.containsKey('primary_focus')) return map;
    } catch (_) {}
    return null;
  }

  String _shapePrompt(String shape, String focus) {
    switch (shape) {
      case 'dialogue_heavy':
        return '以对话为主，动作描写辅助。角色之间的对话应该推动情节或揭示关系。';
      case 'montage':
        return '快速切换几个片段，蒙太奇风格。每个片段简短但有画面感，片段之间有时间跳跃。';
      case 'reveal':
        return '逐步揭示一个信息。先铺垫氛围，再通过细节或对话慢慢揭露，不要一次性说完。';
      case 'tension_escalation':
        return '张力逐步上升，每段都比前一段更紧。从平静开始，逐步积累到一个小高潮。';
      case 'quiet':
        return '静谧时刻，环境描写为主。写声音、光线、气味、温度——让读者感受到此刻的氛围。';
      case 'action_reaction':
        return '动作→反应→动作，快速节奏。一个动作紧接着一个反应，不要停顿。';
      default:
        return '以对话为主，动作描写辅助。';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 分阶段剧本生成（替代旧的 createScript 一次性生成）
  // 阶段1: generateWorld   → meta + player + world + interaction
  // 阶段2: generateCharacters → characters 数组
  // 阶段3: generateEvents   → events + plot
  // 合并:  assembleScript   → 完整 JSON 字符串
  // ─────────────────────────────────────────────────────────────

  /// 通用 JSON 清洗：去掉 markdown 代码块标记
  String _cleanJsonResponse(String raw) {
    String cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      final start = cleaned.indexOf('\n');
      if (start >= 0) cleaned = cleaned.substring(start + 1);
      if (cleaned.endsWith('```')) cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    return cleaned.trim();
  }

  /// 阶段1：生成世界观层（meta + player + world + interaction）
  /// 输出独立的 JSON 对象，不含 characters 和 events
  Future<String> generateWorld(String userDescription) async {
    final systemPrompt = '''你是恋爱模拟游戏的世界观架构师。根据用户的描述，生成世界观层 JSON。

输出必须是纯 JSON，不要 markdown 代码块标记。严格按下方模板的字段名和数据类型生成。

=== 模板开始 ===
{
  "meta": {
    "id": "english_snake_case_id",
    "name": "剧本中文名",
    "version": "1.0.0",
    "author": "",
    "genre": "体裁风格",
    "tone": "基调关键词，逗号分隔",
    "mode": "world_driven",
    "summary": "一句话简介"
  },
  "player": {
    "background": "主角背景故事，第三人称",
    "current_state": "主角当前状态和处境"
  },
  "world": {
    "summary": "世界观概述",
    "setting": "场景设定详述",
    "atmosphere": {"time_sense": "时间感","tone": "气氛","interaction_quality": "互动质感","writing_style": {"label": "风格名称","rules": ["可执行规则1","可执行规则2"],"do_example": "100-200字正例","dont_example": "100字反例"}},
    "locations": [
      {
        "id": "english_id",
        "name": "中文名",
        "desc": "详细描述",
        "trigger_tags": ["标签1","标签2"],
        "narrative_profile": {
          "event_affinity": ["plot","daily","sweet_minor"],
          "keywords": ["关键词1","关键词2"]
        }
      }
    ],
    "special_rules": {},
    "memory": {
      "current_time": {"day":1,"season":"秋","weather":"晴","phase":"上午"},
      "location_changes": [],
      "world_history": {},
      "world_summary": ""
    }
  },
  "interaction": {
    "time_config": {
      "total_days": 300,
      "start_day": 1,
      "end_day": 300,
      "phases": [
        {"id":"凌晨","name":"凌晨","hour":"00-06","mood":"万籁俱寂","skippable":true},
        {"id":"清晨","name":"清晨","hour":"06-08","mood":"日出晨起","skippable":false},
        {"id":"上午","name":"上午","hour":"08-11","mood":"上午课程","skippable":false},
        {"id":"中午","name":"中午","hour":"11-13","mood":"午休午餐","skippable":false},
        {"id":"下午","name":"下午","hour":"13-17","mood":"下午课程","skippable":false},
        {"id":"傍晚","name":"傍晚","hour":"17-19","mood":"黄昏归家","skippable":false},
        {"id":"夜晚","name":"夜晚","hour":"19-24","mood":"晚间自由","skippable":false}
      ],
      "special_days": [
        {"day": 7, "name": "特殊日子名称", "desc": "描述", "effects": {"affection_boost": {}}}
      ]
    },
    "relationship_stages": [
      {"state":"enemy","label":"死敌","min":0,"max":10},
      {"state":"hate","label":"仇恨","min":10,"max":20},
      {"state":"disgust","label":"憎恨","min":20,"max":30},
      {"state":"aversion","label":"厌恶","min":30,"max":40},
      {"state":"mild_aversion","label":"轻微厌恶","min":40,"max":50},
      {"state":"stranger","label":"陌生人","min":50,"max":60},
      {"state":"favorable","label":"有好感","min":60,"max":70},
      {"state":"appreciation","label":"欣赏","min":70,"max":80},
      {"state":"crush","label":"喜欢","min":80,"max":90},
      {"state":"love","label":"爱","min":90,"max":100},
      {"state":"eternal","label":"永恒唯一","min":100,"max":100}
    ],
    "breakthrough_rule": "好感度>=80进入'喜欢'阶段。要变成'爱'必须触发告白事件。达到'永恒唯一'需要触发终极羁绊事件。",
    "affection": {
      "min": 1,
      "max": 100,
      "precision": 0.01,
      "tiers": [10,20,30,40,50,60,70,80,90,100],
      "boundary_events": {"rule":"跨阶段需触发突破事件","requires":"","breakthrough_event":"","event_type":"","outcome_range":{}},
      "tier_breakthrough": [],
      "overflow_pool": "",
      "gain_multiplier": {},
      "decline_multiplier": {},
      "decline_rules": [],
      "tiers_desc": {},
      "unique_bond": {
        "rule": "好感度100具有唯一性——主角只能与一个角色达到100，其他角色封顶99.99",
        "trigger": "仅终极羁绊事件可解锁100，一旦选择即不可逆"
      }
    },
    "advance_modes": {
      "daily": {"time_advance":{"phases":1},"enabled":true},
      "major": {"time_advance":{"phases":1},"enabled":true}
    }
  },
  "data_layer": {"ranking":{"total_students":100,"events":[]}},
  "rhythm_config": {},
  "memory_config": {},
  "action_rules": {},
  "fallback_narratives": {}
}
=== 模板结束 ===

重要规则：
1. 严格按照模板字段名和数据类型生成，不要新增字段，不要漏掉字段。
2. **不要**生成 items、shop、gift_response、multi_lover、equipment 等字段——这些系统已删除。
3. world.locations 至少 5 个，地点 id 用英文小写+下划线。
4. phases 必须是 7 段中文名（凌晨/清晨/上午/中午/下午/傍晚/夜晚），不要用十二时辰。
5. relationship_stages 必须是 11 段（死敌/仇恨/憎恨/厌恶/轻微厌恶/陌生人/有好感/欣赏/喜欢/爱/永恒唯一），与好感阶段提示一致。
6. special_days 必须放在 time_config 内部，不要放在外层。
7. unique_bond 表达"一人 100，其余封顶 99.99"的约束。
8. 私密地点（如角色房间、公寓）通过 trigger_tags 标注，并需要 favorability_threshold 字段。
9. 输出纯 JSON，不要 markdown 代码块标记，不要额外解释文字。
10. **atmosphere.writing_style 必须生成**，字段包含：
    - label：风格名称（如"电影感白描""纯文学留白""现代言情流畅""现代爽文利落"，或自定义与剧本基调匹配的风格名）
    - rules：3-5 条**可执行**规则（节奏方向、感官比例、心理描写比例、对话占比等，不要用"细腻""文学化"这种模糊形容词，也不要硬性字数限制）
    - do_example：100-200 字符合该风格的示范叙事
    - dont_example：100 字违反该风格的反面例子
    文风应与剧本基调匹配：悬疑→冷峻短句、甜宠→温暖流畅、爽文→利落反转、悲剧→克制留白。''';

    final userPrompt = '请根据以下描述生成世界观层 JSON：\n\n$userDescription';

    final raw = await _callApi(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: 4096,
      temperature: 0.85,
      timeoutSeconds: 180,
    );
    return _cleanJsonResponse(raw);
  }

  /// 阶段2：基于世界观生成角色列表
  /// [worldJson] 是阶段1 的输出 JSON 字符串
  Future<String> generateCharacters(String worldJson, String userDescription) async {
    final systemPrompt = '''你是恋爱模拟游戏的角色设计师。基于给定的世界观，生成可攻略角色列表 JSON。

输出必须是纯 JSON 数组（不要外层包裹），不要 markdown 代码块标记。严格按下方角色模板生成每个角色。

=== 单个角色模板开始 ===
{
  "full_character": true,
  "summary": "角色一句话概括",
  "char_intro": "角色一句话自我介绍口吻",
  "basic": {"id":"english_id","name":"中文名","gender":"男/女","age":18,"height":"170cm","initial_affection":50},
  "background": {"origin":"出身","history":"经历","current_situation":"现状"},
  "details": {"goals":["目标1","目标2"],"fears":["恐惧1","恐惧2"],"secrets":["秘密1","秘密2"],"quirks":["怪癖1","怪癖2"]},
  "soul": {
    "core": "性格核心一句话",
    "desire": "深层欲望",
    "wound": "心理创伤",
    "fear": "恐惧",
    "contradiction": "性格矛盾点",
    "dualMode": {
      "to_stranger": "对外人的态度描述",
      "to_close": "对亲密者的态度描述"
    }
  },
  "speech": {
    "bigFiveProfile": {
      "openness": 0.5,
      "extraversion": 0.5,
      "agreeableness": 0.7,
      "conscientiousness": 0.6,
      "neuroticism": 0.4
    },
    "phonetics": {"pitch":"音色描述","pace":"语速描述"},
    "vocabulary": {"style":"用词风格","avoid":["不说的词1","不说的词2"]},
    "dualMode": {
      "to_stranger": {"overview":"对外方式","example":"例：嗯"},
      "to_close": {"overview":"对亲近者方式","example":"例：你饿了吗"}
    }
  },
  "humanity": {"non_verbal":["非语言动作1","非语言动作2"]},
  "agent": {"role":"角色定位","agenda":"内在动机"},
  "appearance": {"body":"身形描述","face":"面部描述","hair":"发型发色","eyes":"眼睛描述","clothing":"穿着风格","accessory":"配饰","distinctive_features":"显著特征"},
  "preferences": {"likes":["喜欢1","喜欢2"],"dislikes":["讨厌1","讨厌2"]},
  "mood_triggers": {"joy":["开心触发1"],"anger":["生气触发1"],"sadness":["难过触发1"],"nervous":["紧张触发1"],"jealous":["嫉妒触发1"]},
  "boundary": {
    "pace_hint": "节奏提示",
    "physical": "物理边界",
    "emotional": "情感边界",
    "topic_taboo": ["禁忌话题1","禁忌话题2"]
  },
  "evolution": {
    "affection_stages": [
      {"stage":"死敌","range":"0-10","narrative_hint":"此阶段的描写提示"},
      {"stage":"仇恨","range":"10-20","narrative_hint":"..."},
      {"stage":"憎恨","range":"20-30","narrative_hint":"..."},
      {"stage":"厌恶","range":"30-40","narrative_hint":"..."},
      {"stage":"轻微厌恶","range":"40-50","narrative_hint":"..."},
      {"stage":"陌生人","range":"50-60","narrative_hint":"..."},
      {"stage":"有好感","range":"60-70","narrative_hint":"..."},
      {"stage":"欣赏","range":"70-80","narrative_hint":"..."},
      {"stage":"喜欢","range":"80-90","narrative_hint":"..."},
      {"stage":"爱","range":"90-100","narrative_hint":"..."},
      {"stage":"永恒唯一","range":"100-100","narrative_hint":"..."}
    ]
  },
  "schedule": {
    "weekday": [{"phase":"上午","location":"地点id","activity":"活动描述","priority":50}],
    "weekend": [{"phase":"上午","location":"地点id","activity":"活动描述","priority":50}]
  },
  "memory_tags": {"default":["日常"],"affection_breakthrough":["暧昧"],"conflict":["冲突"],"triangular":["吃醋"]},
  "stats": [
    {"id":"intelligence","name":"智力","max":100,"value":70},
    {"id":"appearance","name":"外貌","max":100,"value":60},
    {"id":"charisma","name":"魅力","max":100,"value":50}
  ],
  "grades": [
    {"id":"chinese","name":"语文","max":100,"value":80},
    {"id":"math","name":"数学","max":100,"value":60}
  ],
  "discovery_condition": "如何解锁此角色",
  "relations": {"flat":[],"dimensional":[]},
  "memory": {"episodic_memory":[]}
}
=== 单个角色模板结束 ===

重要规则：
1. 至少生成 2 个 full_character=true 的可攻略角色，建议 3-4 个。
2. **不要**生成 gift_response 字段——礼物系统已删除。
3. 角色间要有差异化：不同性格核心、不同对话风格、不同秘密。
4. evolution.affection_stages 必须是 11 段，stage 名与 range 对应（死敌 0-10、仇恨 10-20、憎恨 20-30、厌恶 30-40、轻微厌恶 40-50、陌生人 50-60、有好感 60-70、欣赏 70-80、喜欢 80-90、爱 90-100、永恒唯一 100-100）。
5. soul.dualMode 和 speech.dualMode 都是对象，不是字符串。
6. boundary.topic_taboo 是字符串数组。
7. mood_triggers 包含 joy/anger/sadness/nervous/jealous 五个，都是数组。
8. speech.bigFiveProfile 五个字段 openness/extraversion/agreeableness/conscientiousness/neuroticism 都是 0-1 的数字。
9. schedule 中字段是 phase（中文时段名），不是 time。
10. 角色之间要有 relations 关联（在 dimensional 中标注关系）。
11. 至少一个角色的 initial_affection 较低（5-15）以增加挑战。
12. 输出纯 JSON 数组（[...]），不要 markdown 代码块标记，不要额外解释文字。''';

    final userPrompt = '世界观JSON：\n$worldJson\n\n用户原始描述：\n$userDescription\n\n请基于以上世界观生成角色列表 JSON 数组。';

    final raw = await _callApi(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: 8192,
      temperature: 0.9,
      timeoutSeconds: 180,
    );
    return _cleanJsonResponse(raw);
  }

  /// 阶段3：基于世界观+角色生成事件层
  Future<String> generateEvents(String worldJson, String charactersJson, String userDescription) async {
    final systemPrompt = '''你是恋爱模拟游戏的事件设计师。基于给定的世界观和角色，生成事件层 JSON。

输出必须是纯 JSON 对象，不要 markdown 代码块标记。严格按下方模板生成。

=== 模板开始 ===
{
  "summary": "事件层说明",
  "scene_locations": [
    {
      "id": "english_id",
      "name": "中文名",
      "desc": "描述",
      "visibility_default": "public",
      "events_hint": "可能发生什么事件",
      "available_phases": ["上午","中午","下午","傍晚","夜晚"],
      "scene_moods": ["情绪1","情绪2"],
      "narrative_profile": {
        "event_affinity": {"plot":0.8,"daily":0.5},
        "keywords": ["关键词1","关键词2"]
      }
    }
  ],
  "scene_events": [],
  "plot": [],
  "daily": [
    {"id":"daily_1","name":"事件名","ai_hint":"AI生成提示","ai_rule":"fixed","weight":1.0,"severity":"medium","mood":"轻松","context_tags":["校园"],"location_req":["location_id"],"required_chars":["char_id"],"always_memory":false,"duration":"short","max_steps":3}
  ],
  "boundary": [],
  "sweet_minor": [],
  "sweet_major": [],
  "reversal": [],
  "echo": [],
  "misunderstanding": [],
  "ensemble": [],
  "world_shift": [],
  "forced_choice": [],
  "resource": [],
  "dialogue_trigger": [],
  "butterfly_system": {"seeds":[],"max_seeds":5,"bloom_chance":0.2},
  "tension_field": {},
  "conditions": [],
  "chains": [],
  "post_ending_pool": [],
  "daily_scenes": [],
  "memory": {"recent_events":[],"compressed":[],"event_counter":0}
}
=== 模板结束 ===

重要规则：
1. 严格按照模板字段名生成，不要新增字段。
2. **不要**生成 resource 事件——商店系统已删除，与购买/金币相关的事件都不要。
3. scene_locations 至少 3 个，应与 world.locations 呼应（可复用 id）。
4. events.scene_locations 的 narrative_profile.event_affinity 是对象（键是事件类型，值是权重数字 0-1）。
5. daily 事件至少 5 个，覆盖不同的 location 和 char。
6. sweet_minor 至少 3 个，sweet_major 至少 1 个。
7. plot 事件至少 2 个，关联主线推进。
8. forced_choice 至少 1 个，包含玩家选择分支。
9. dialogue_trigger 可为空数组。
10. 每个事件的 ai_hint 要具体可执行（不要"角色互动"这种空泛提示）。
11. tension_field 可留空对象 {}。
12. 输出纯 JSON，不要 markdown 代码块标记，不要额外解释文字。''';

    final userPrompt = '世界观JSON：\n$worldJson\n\n角色列表JSON：\n$charactersJson\n\n用户原始描述：\n$userDescription\n\n请基于以上世界观和角色生成事件层 JSON。';

    final raw = await _callApi(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: 6144,
      temperature: 0.85,
      timeoutSeconds: 180,
    );
    return _cleanJsonResponse(raw);
  }

  /// 合并三个阶段的结果为完整剧本 JSON 字符串
  /// 任何一个输入是无效 JSON 都会抛异常
  String assembleScript(String worldJson, String charactersJson, String eventsJson) {
    final world = json.decode(worldJson) as Map<String, dynamic>;
    final characters = json.decode(charactersJson);
    final events = json.decode(eventsJson) as Map<String, dynamic>;

    final assembled = <String, dynamic>{
      'meta': world['meta'] ?? {},
      'player': world['player'] ?? {},
      'world': world['world'] ?? {},
      'characters': characters is List ? characters : [],
      'events': events,
      'interaction': world['interaction'] ?? {},
      'data_layer': world['data_layer'] ?? {'ranking': {'total_students': 100, 'events': []}},
      'rhythm_config': world['rhythm_config'] ?? {},
      'memory_config': world['memory_config'] ?? {},
      'action_rules': world['action_rules'] ?? {},
      'fallback_narratives': world['fallback_narratives'] ?? {},
    };
    return json.encode(assembled);
  }

  /// 兼容入口：一次性完成三阶段生成（用于旧调用方）
  Future<String> createScript(String userDescription) async {
    final worldJson = await generateWorld(userDescription);
    final charactersJson = await generateCharacters(worldJson, userDescription);
    final eventsJson = await generateEvents(worldJson, charactersJson, userDescription);
    return assembleScript(worldJson, charactersJson, eventsJson);
  }
}

class _ApiRetryException implements Exception {
  final int statusCode;
  _ApiRetryException(this.statusCode);
}
