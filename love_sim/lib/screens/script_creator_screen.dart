import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:love_sim/providers/app_provider.dart';
import 'package:love_sim/services/script_loader.dart';

class ScriptCreatorScreen extends StatefulWidget {
  const ScriptCreatorScreen({super.key});

  @override
  State<ScriptCreatorScreen> createState() => _ScriptCreatorScreenState();
}

class _ScriptCreatorScreenState extends State<ScriptCreatorScreen> {
  int _step = 0;
  static const _totalSteps = 5;

  final _stepControllers = List.generate(_totalSteps, (_) => TextEditingController());
  final _stepFocusNodes = List.generate(_totalSteps, (_) => FocusNode());

  bool _generating = false;
  bool _done = false;
  String? _resultJson;
  String? _error;
  String _statusText = '';

  static const _stepTitles = [
    '你想讲一个什么样的故事？',
    '主角是什么样的人？',
    '有哪些可以心动的角色？',
    '故事发生在哪里？',
    '最后确认',
  ];

  static const _stepSubtitles = [
    '体裁、风格、基调——先定大局',
    '性格、背景、处境——玩家扮演谁',
    '写下你心目中他/她们的样子',
    '地点、气氛、时间跨度',
    '检查一下，没问题就生成',
  ];

  static const _stepPlaceholders = [
    '校园恋爱，高二到高考结束。偏现实向，有成长的酸甜苦辣，也有没说出口的遗憾。基调温暖带点感伤。四个可攻略角色，剧情跨两年半。',
    '转学到新城市的高中生。话不多但心里想得多，画得一手好素描。父母离异，跟妈妈住。在新学校谁也不认识，一切从零开始。',
    '林晓：隔壁班的体育委员，阳光开朗，篮球打得好，成绩一般。其实家里压力很大，从不在人前说。她笑起来有两个酒窝，是那种能照亮一整个教室的人。\n\n陆辞：同班的学习委员，安静寡言，物理竞赛保送生。眼神很冷，但偶尔会偷偷帮别人把掉在地上的笔捡起来。他有秘密。\n\n苏晚晴：转校生，和你同一天到新学校。看起来柔弱，骨子里倔得不行。爱好写小说，笔记本从不离身。她是唯一一个第一天就主动跟你说话的人。',
    '学校：高二B班教室、天台、操场、图书馆、食堂、琴房\n城市：江南小城，有河有桥有老巷子\n时间：从秋天开学开始，经历两年半，有四季变化\n气氛：晨曦的教室、雨天的走廊、傍晚的操场、深夜的便利店',
    '',
  ];

  @override
  void dispose() {
    for (final c in _stepControllers) { c.dispose(); }
    for (final f in _stepFocusNodes) { f.dispose(); }
    super.dispose();
  }

  void _nextStep() {
    if (_step < _totalSteps - 1) {
      setState(() { _step++; });
      _stepFocusNodes[_step].requestFocus();
    } else {
      _generate();
    }
  }

  void _prevStep() {
    if (_step > 0) setState(() { _step--; });
  }

  String _buildFullDescription() {
    final parts = <String>[];
    if (_stepControllers[0].text.trim().isNotEmpty) {
      parts.add('【故事设定】\n${_stepControllers[0].text.trim()}');
    }
    if (_stepControllers[1].text.trim().isNotEmpty) {
      parts.add('【主角】\n${_stepControllers[1].text.trim()}');
    }
    if (_stepControllers[2].text.trim().isNotEmpty) {
      parts.add('【可攻略角色】\n${_stepControllers[2].text.trim()}');
    }
    if (_stepControllers[3].text.trim().isNotEmpty) {
      parts.add('【世界观与场景】\n${_stepControllers[3].text.trim()}');
    }
    return parts.join('\n\n');
  }

  Future<void> _generate() async {
    final desc = _buildFullDescription();
    if (desc.isEmpty) return;

    setState(() { _generating = true; _error = null; _done = false; _statusText = '正在与 AI 沟通，构思角色...'; });

    try {
      final app = context.read<AppProvider>();
      final raw = await app.deepSeekClient!.createScript(desc);

      setState(() { _statusText = '正在校验剧本结构...'; });

      try {
        json.decode(raw) as Map<String, dynamic>;
      } catch (_) {
        setState(() { _generating = false; _error = 'AI 返回的不是有效 JSON，请点击下方按钮重试'; });
        return;
      }

      final loader = ScriptLoader();
      try {
        loader.loadFromJsonString(raw);
      } catch (e) {
        final msg = e.toString();
        setState(() { _generating = false; _error = '剧本结构校验失败：${msg.length > 200 ? msg.substring(0, 200) : msg}'; });
        return;
      }

      final map = json.decode(raw) as Map<String, dynamic>;
      final meta = map['meta'] as Map<String, dynamic>?;
      final chars = map['characters'] as List<dynamic>?;
      final locations = map['world']?['locations'] as List<dynamic>?;
      final summary = StringBuffer();
      summary.writeln('剧本：${meta?['name'] ?? '未知'}');
      if (chars != null) {
        final names = chars.where((c) => c is Map && c['full_character'] == true)
            .map((c) => (c as Map)['basic']?['name'] ?? '?').toList();
        summary.writeln('角色：${names.join('、')}（共${names.length}人）');
      }
      if (locations != null) {
        summary.writeln('地点：${locations.length}个');
      }
      summary.writeln('体裁：${meta?['genre'] ?? '未知'}');
      summary.writeln('基调：${meta?['tone'] ?? ''}');

      setState(() {
        _generating = false;
        _done = true;
        _resultJson = raw;
        _statusText = summary.toString();
      });
    } catch (e) {
      setState(() { _generating = false; _error = '生成失败：$e'; });
    }
  }

  void _saveAndPop() {
    if (_resultJson == null) return;
    final map = json.decode(_resultJson!) as Map<String, dynamic>;
    final name = (map['meta'] as Map?)?['name'] ?? '新剧本';
    final app = context.read<AppProvider>();
    app.addCustomScript(name.toString(), _resultJson!);
    Navigator.pop(context);
  }

  void _saveAndContinue() {
    if (_resultJson == null) return;
    final map = json.decode(_resultJson!) as Map<String, dynamic>;
    final name = (map['meta'] as Map?)?['name'] ?? '新剧本';
    final app = context.read<AppProvider>();
    app.addCustomScript(name.toString(), _resultJson!);
    setState(() {
      _done = false;
      _resultJson = null;
      _statusText = '';
      _step = 0;
      for (final c in _stepControllers) { c.clear(); }
    });
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('已保存'),
        content: Text('「$name」已加入剧本库，你可以在剧本页加载游玩'),
        actions: [CupertinoDialogAction(child: const Text('继续创作'), onPressed: () => Navigator.pop(context))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_step == _totalSteps - 1 ? '确认生成' : '第${_step + 1}步'),
        leading: _step > 0 && !_done && !_generating
            ? CupertinoButton(padding: EdgeInsets.zero, child: const Text('上一步'), onPressed: _prevStep)
            : null,
        trailing: _done
            ? CupertinoButton(padding: EdgeInsets.zero, child: const Text('保存'), onPressed: _saveAndContinue)
            : null,
      ),
      child: SafeArea(
        child: _done ? _buildResultView() : _buildStepView(),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(_totalSteps, (i) {
          final isActive = i == _step;
          final isDone = i < _step;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i > 0 ? 4 : 0, right: i < _totalSteps - 1 ? 4 : 0),
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isActive
                      ? CupertinoColors.activeBlue
                      : isDone
                          ? CupertinoColors.systemGreen
                          : CupertinoColors.systemGrey4,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepView() {
    if (_generating) return _buildGeneratingView();

    return Column(
      children: [
        _buildProgressBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(
                  _stepTitles[_step],
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                ),
                const SizedBox(height: 6),
                Text(
                  _stepSubtitles[_step],
                  style: const TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
                ),
                const SizedBox(height: 20),
                if (_step < _totalSteps - 1) ...[
                  CupertinoTextField(
                    controller: _stepControllers[_step],
                    focusNode: _stepFocusNodes[_step],
                    maxLines: _step == 2 ? 12 : 6,
                    placeholder: _stepPlaceholders[_step],
                    style: const TextStyle(fontSize: 15, height: 1.5),
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  CupertinoButton.filled(
                    onPressed: _stepControllers[_step].text.trim().isEmpty ? null : _nextStep,
                    child: Text(_step < _totalSteps - 2 ? '下一步' : '生成剧本'),
                  ),
                  if (_step > 0) ...[
                    const SizedBox(height: 8),
                    CupertinoButton(
                      child: const Text('上一步'),
                      onPressed: _prevStep,
                    ),
                  ],
                ] else ...[
                  _buildReviewCard('故事设定', _stepControllers[0].text, CupertinoIcons.book_fill),
                  const SizedBox(height: 12),
                  _buildReviewCard('主角', _stepControllers[1].text, CupertinoIcons.person_fill),
                  const SizedBox(height: 12),
                  _buildReviewCard('可攻略角色', _stepControllers[2].text, CupertinoIcons.heart_fill),
                  const SizedBox(height: 12),
                  _buildReviewCard('世界观与场景', _stepControllers[3].text, CupertinoIcons.map_fill),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13)),
                    const SizedBox(height: 12),
                  ],
                  CupertinoButton.filled(
                    onPressed: _generate,
                    child: const Text('🎬 生成剧本'),
                  ),
                  const SizedBox(height: 8),
                  CupertinoButton(
                    child: const Text('上一步'),
                    onPressed: _prevStep,
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(String label, String content, IconData icon) {
    final text = content.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: CupertinoColors.systemGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CupertinoColors.secondaryLabel)),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(fontSize: 14, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 18),
            const SizedBox(height: 24),
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: CupertinoColors.secondaryLabel),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13)),
              const SizedBox(height: 8),
              CupertinoButton(child: const Text('重新生成'), onPressed: _generate),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CupertinoColors.systemGreen.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                const Icon(CupertinoIcons.check_mark_circled_solid, color: CupertinoColors.systemGreen, size: 56),
                const SizedBox(height: 16),
                const Text('剧本生成完成', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(_statusText, style: const TextStyle(fontSize: 14, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          CupertinoButton.filled(
            child: const Text('保存并返回剧本库'),
            onPressed: _saveAndPop,
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            child: const Text('保存后继续创作新剧本'),
            onPressed: _saveAndContinue,
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            child: const Text('不满意，重新生成', style: TextStyle(color: CupertinoColors.destructiveRed)),
            onPressed: _generate,
          ),
        ],
      ),
    );
  }
}
