import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:sime/providers/app_provider.dart';
import 'package:sime/services/script_loader.dart';
import 'package:sime/models/script.dart';

/// 剧本创作器：分阶段生成 + 每步预览/重生成 + 角色编辑 + 试聊
class ScriptCreatorScreen extends StatefulWidget {
  const ScriptCreatorScreen({super.key});
  @override
  State<ScriptCreatorScreen> createState() => _ScriptCreatorScreenState();
}

enum _Phase { input, genWorld, previewWorld, genChars, previewChars, genEvents, previewEvents, done }

class _ScriptCreatorScreenState extends State<ScriptCreatorScreen> {
  // 输入
  final _storyCtrl = TextEditingController();
  final _protagonistCtrl = TextEditingController();
  final _charsCtrl = TextEditingController();
  final _worldCtrl = TextEditingController();

  // 流程状态
  _Phase _phase = _Phase.input;
  String? _error;
  String? _worldJson;
  String? _charactersJson;
  String? _eventsJson;
  String? _finalJson;

  // 编辑缓冲（可编辑生成的角色/世界核心字段）
  List<Map<String, dynamic>> _characters = [];
  Map<String, dynamic> _world = {};
  Map<String, dynamic> _meta = {};

  @override
  void dispose() {
    _storyCtrl.dispose();
    _protagonistCtrl.dispose();
    _charsCtrl.dispose();
    _worldCtrl.dispose();
    super.dispose();
  }

  String _buildDescription() {
    final parts = <String>[];
    if (_storyCtrl.text.trim().isNotEmpty) parts.add('【故事设定】\n${_storyCtrl.text.trim()}');
    if (_protagonistCtrl.text.trim().isNotEmpty) parts.add('【主角】\n${_protagonistCtrl.text.trim()}');
    if (_charsCtrl.text.trim().isNotEmpty) parts.add('【可攻略角色】\n${_charsCtrl.text.trim()}');
    if (_worldCtrl.text.trim().isNotEmpty) parts.add('【世界观与场景】\n${_worldCtrl.text.trim()}');
    return parts.join('\n\n');
  }

  // ─── 阶段1：生成世界观 ───
  Future<void> _generateWorld() async {
    if (_buildDescription().isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('请先填写'),
          content: const Text('至少填写一项：故事设定 / 主角 / 可攻略角色 / 世界观'),
          actions: [CupertinoDialogAction(child: const Text('好'), onPressed: () => Navigator.pop(context))],
        ),
      );
      return;
    }
    setState(() { _phase = _Phase.genWorld; _error = null; });
    try {
      final app = context.read<AppProvider>();
      final raw = await app.deepSeekClient!.generateWorld(_buildDescription());
      json.decode(raw); // 校验
      _worldJson = raw;
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _meta = (decoded['meta'] as Map<String, dynamic>?) ?? {};
      _world = (decoded['world'] as Map<String, dynamic>?) ?? {};
      setState(() { _phase = _Phase.previewWorld; });
    } catch (e) {
      setState(() { _error = '世界观生成失败：$e'; _phase = _Phase.input; });
    }
  }

  // ─── 阶段2：生成角色 ───
  Future<void> _generateCharacters() async {
    setState(() { _phase = _Phase.genChars; _error = null; });
    try {
      final app = context.read<AppProvider>();
      final raw = await app.deepSeekClient!.generateCharacters(_worldJson!, _buildDescription());
      final list = json.decode(raw);
      if (list is! List || list.isEmpty) throw Exception('角色列表为空');
      _charactersJson = raw;
      _characters = list.cast<Map<String, dynamic>>().map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() { _phase = _Phase.previewChars; });
    } catch (e) {
      setState(() { _error = '角色生成失败：$e'; _phase = _Phase.previewWorld; });
    }
  }

  // ─── 阶段3：生成事件 ───
  Future<void> _generateEvents() async {
    setState(() { _phase = _Phase.genEvents; _error = null; });
    try {
      final app = context.read<AppProvider>();
      final raw = await app.deepSeekClient!.generateEvents(_worldJson!, _charactersJson!, _buildDescription());
      json.decode(raw); // 校验
      _eventsJson = raw;
      setState(() { _phase = _Phase.previewEvents; });
    } catch (e) {
      setState(() { _error = '事件生成失败：$e'; _phase = _Phase.previewChars; });
    }
  }

  // ─── 合并 + 校验 ───
  Future<void> _assembleAndFinish() async {
    try {
      // 把编辑后的角色/世界写回 JSON
      _worldJson = json.encode({
        ...json.decode(_worldJson!) as Map<String, dynamic>,
        'meta': _meta,
        'world': _world,
      });
      _charactersJson = json.encode(_characters);
      final app = context.read<AppProvider>();
      final assembled = app.deepSeekClient!.assembleScript(_worldJson!, _charactersJson!, _eventsJson!);
      // 结构校验
      final loader = ScriptLoader();
      loader.loadFromJsonString(assembled);
      _finalJson = assembled;
      setState(() { _phase = _Phase.done; });
    } catch (e) {
      setState(() { _error = '合并校验失败：$e'; });
    }
  }

  void _resetToInput() {
    setState(() {
      _phase = _Phase.input;
      _error = null;
      _worldJson = null;
      _charactersJson = null;
      _eventsJson = null;
      _finalJson = null;
      _characters = [];
      _world = {};
      _meta = {};
    });
  }

  void _saveAndPop() {
    if (_finalJson == null) return;
    final name = _meta['name']?.toString() ?? '新剧本';
    context.read<AppProvider>().addCustomScript(name, _finalJson!);
    Navigator.pop(context);
  }

  void _saveAndContinue() {
    if (_finalJson == null) return;
    final name = _meta['name']?.toString() ?? '新剧本';
    context.read<AppProvider>().addCustomScript(name, _finalJson!);
    _resetToInput();
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('已保存'),
        content: Text('「$name」已加入剧本库'),
        actions: [CupertinoDialogAction(child: const Text('继续创作'), onPressed: () => Navigator.pop(context))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_navTitle()),
        leading: CupertinoButton(padding: EdgeInsets.zero, child: const Text('返回'), onPressed: () => Navigator.pop(context)),
      ),
      child: SafeArea(child: _buildBody()),
    );
  }

  String _navTitle() {
    switch (_phase) {
      case _Phase.input: return '创作剧本';
      case _Phase.genWorld: return '生成世界观…';
      case _Phase.previewWorld: return '预览·世界观';
      case _Phase.genChars: return '生成角色…';
      case _Phase.previewChars: return '预览·角色';
      case _Phase.genEvents: return '生成事件…';
      case _Phase.previewEvents: return '预览·事件';
      case _Phase.done: return '剧本就绪';
    }
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.input: return _buildInputView();
      case _Phase.genWorld:
      case _Phase.genChars:
      case _Phase.genEvents:
        return _buildLoadingView();
      case _Phase.previewWorld: return _buildWorldPreview();
      case _Phase.previewChars: return _buildCharsPreview();
      case _Phase.previewEvents: return _buildEventsPreview();
      case _Phase.done: return _buildDoneView();
    }
  }

  // ─── 输入页 ───
  Widget _buildInputView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('创作剧本', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('分三步生成：世界观 → 角色 → 事件。每步可预览和重生成。', style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel)),
        const SizedBox(height: 20),
        _buildInputField('1. 故事设定', '体裁、风格、基调、时间跨度', _storyCtrl, 4),
        _buildInputField('2. 主角', '性格、背景、处境', _protagonistCtrl, 3),
        _buildInputField('3. 可攻略角色', '每个角色一段：姓名、性格核心、秘密', _charsCtrl, 8),
        _buildInputField('4. 世界观与场景', '地点、气氛、时间跨度', _worldCtrl, 4),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13)),
          const SizedBox(height: 12),
        ],
        CupertinoButton.filled(
          onPressed: _generateWorld,
          child: const Text('开始生成'),
        ),
      ],
    );
  }

  Widget _buildInputField(String label, String hint, TextEditingController ctrl, int maxLines) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: ctrl,
            maxLines: maxLines,
            placeholder: hint,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ─── 加载页 ───
  Widget _buildLoadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 18),
            const SizedBox(height: 24),
            Text(_loadingText(), style: const TextStyle(fontSize: 16, color: CupertinoColors.secondaryLabel)),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              CupertinoButton(child: const Text('返回'), onPressed: _resetToInput),
            ],
          ],
        ),
      ),
    );
  }

  String _loadingText() {
    switch (_phase) {
      case _Phase.genWorld: return '正在与 AI 沟通，构思世界观…';
      case _Phase.genChars: return '正在塑造角色，赋予灵魂…';
      case _Phase.genEvents: return '正在编排事件，编织剧情…';
      default: return '';
    }
  }

  // ─── 世界观预览 ───
  Widget _buildWorldPreview() {
    final locations = (_world['locations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final interaction = (json.decode(_worldJson!) as Map<String, dynamic>)['interaction'] as Map<String, dynamic>?;
    final phases = (interaction?['time_config']?['phases'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final stages = (interaction?['relationship_stages'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: CupertinoColors.destructiveRed.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(_error!, style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13)),
          ),
        ],
        _buildPreviewCard(
          title: _meta['name']?.toString() ?? '未命名',
          subtitle: '${_meta['genre'] ?? ''} · ${_meta['tone'] ?? ''}',
          body: _meta['summary']?.toString() ?? '',
        ),
        const SizedBox(height: 12),
        _buildSectionTitle('地点（${locations.length}）'),
        ...locations.map((l) => _buildChipRow(l['name']?.toString() ?? '', l['desc']?.toString() ?? '')),
        const SizedBox(height: 12),
        _buildSectionTitle('时段（${phases.length}）'),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: phases.map((p) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: CupertinoColors.systemGrey6, borderRadius: BorderRadius.circular(6)),
            child: Text(p['name']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
          )).toList(),
        ),
        const SizedBox(height: 12),
        _buildSectionTitle('好感阶段（${stages.length}）'),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: stages.map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: CupertinoColors.activeBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
            child: Text('${s['label']} ${s['min']}-${s['max']}', style: const TextStyle(fontSize: 11)),
          )).toList(),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: CupertinoButton(child: const Text('重新生成'), onPressed: _generateWorld)),
            Expanded(child: CupertinoButton.filled(child: const Text('继续·生成角色'), onPressed: _generateCharacters)),
          ],
        ),
      ],
    );
  }

  // ─── 角色预览（可编辑） ───
  Widget _buildCharsPreview() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionTitle('可攻略角色（${_characters.length}）·点击编辑'),
        ..._characters.asMap().entries.map((entry) => _buildCharCard(entry.key, entry.value)),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: CupertinoButton(child: const Text('重新生成'), onPressed: _generateCharacters)),
            Expanded(child: CupertinoButton.filled(child: const Text('继续·生成事件'), onPressed: _generateEvents)),
          ],
        ),
      ],
    );
  }

  Widget _buildCharCard(int idx, Map<String, dynamic> c) {
    final basic = (c['basic'] as Map<String, dynamic>?) ?? {};
    final soul = (c['soul'] as Map<String, dynamic>?) ?? {};
    final speech = (c['speech'] as Map<String, dynamic>?) ?? {};
    final dual = (speech['dualMode'] as Map<String, dynamic>?) ?? {};
    final toClose = (dual['to_close'] as Map<String, dynamic>?) ?? {};
    return GestureDetector(
      onTap: () => _editCharacter(idx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: CupertinoColors.systemGrey6, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(basic['name']?.toString() ?? '?', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('${basic['gender'] ?? ''} · ${basic['age'] ?? ''}岁', style: const TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel)),
                const Spacer(),
                const Icon(CupertinoIcons.chevron_right, size: 14, color: CupertinoColors.tertiaryLabel),
              ],
            ),
            const SizedBox(height: 6),
            Text('核心：${soul['core'] ?? ''}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text('欲望：${soul['desire'] ?? ''}', style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel)),
            const SizedBox(height: 4),
            Text('对亲近者：「${toClose['example'] ?? ''}」', style: const TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  void _editCharacter(int idx) {
    final c = _characters[idx];
    final basic = (c['basic'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final soul = (c['soul'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final speech = (c['speech'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final dual = (speech['dualMode'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final toClose = (dual['to_close'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final nameCtrl = TextEditingController(text: basic['name']?.toString() ?? '');
    final coreCtrl = TextEditingController(text: soul['core']?.toString() ?? '');
    final desireCtrl = TextEditingController(text: soul['desire']?.toString() ?? '');
    final woundCtrl = TextEditingController(text: soul['wound']?.toString() ?? '');
    final toCloseExampleCtrl = TextEditingController(text: toClose['example']?.toString() ?? '');
    final toCloseOverviewCtrl = TextEditingController(text: toClose['overview']?.toString() ?? '');
    final summaryCtrl = TextEditingController(text: c['summary']?.toString() ?? '');

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('编辑角色'),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Text('保存'),
            onPressed: () {
              setState(() {
                _characters[idx] = {
                  ...c,
                  'summary': summaryCtrl.text,
                  'basic': {...basic, 'name': nameCtrl.text},
                  'soul': {...soul, 'core': coreCtrl.text, 'desire': desireCtrl.text, 'wound': woundCtrl.text},
                  'speech': {
                    ...speech,
                    'dualMode': {
                      ...dual,
                      'to_close': {'overview': toCloseOverviewCtrl.text, 'example': toCloseExampleCtrl.text},
                    },
                  },
                };
              });
              Navigator.pop(ctx);
            },
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildEditField('姓名', nameCtrl),
              _buildEditField('一句话概括', summaryCtrl),
              _buildEditField('性格核心', coreCtrl),
              _buildEditField('深层欲望', desireCtrl),
              _buildEditField('心理创伤', woundCtrl),
              _buildEditField('对亲近者·概述', toCloseOverviewCtrl),
              _buildEditField('对亲近者·例句', toCloseExampleCtrl, hint: '例：你饿了吗'),
              const SizedBox(height: 20),
              const Text('这些字段直接影响 AI 对话生成质量。其他字段（外貌/日程等）保持 AI 生成结果。', style: TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 事件预览 ───
  Widget _buildEventsPreview() {
    final events = json.decode(_eventsJson!) as Map<String, dynamic>;
    final daily = (events['daily'] as List?) ?? [];
    final sweetMinor = (events['sweet_minor'] as List?) ?? [];
    final sweetMajor = (events['sweet_major'] as List?) ?? [];
    final plot = (events['plot'] as List?) ?? [];
    final forcedChoice = (events['forced_choice'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionTitle('事件统计'),
        _buildStatRow('日常', daily.length),
        _buildStatRow('小甜', sweetMinor.length),
        _buildStatRow('大甜', sweetMajor.length),
        _buildStatRow('主线', plot.length),
        _buildStatRow('抉择', forcedChoice.length),
        const SizedBox(height: 16),
        _buildSectionTitle('日常事件示例'),
        ...daily.take(3).map((e) {
          final m = e as Map<String, dynamic>;
          return _buildChipRow(m['name']?.toString() ?? '', m['ai_hint']?.toString() ?? '');
        }),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: CupertinoButton(child: const Text('重新生成'), onPressed: _generateEvents)),
            Expanded(child: CupertinoButton.filled(child: const Text('合并完成'), onPressed: _assembleAndFinish)),
          ],
        ),
      ],
    );
  }

  // ─── 完成页 ───
  Widget _buildDoneView() {
    return ListView(
      padding: const EdgeInsets.all(20),
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
              const SizedBox(height: 12),
              Text(_meta['name']?.toString() ?? '新剧本', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('角色 ${_characters.length} 人 · 事件 ${_countEvents()} 个', style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('角色预览·点击试聊'),
        ..._characters.map((c) => _buildCharPreviewCard(c)),
        const SizedBox(height: 20),
        CupertinoButton.filled(
          child: const Text('保存并返回剧本库'),
          onPressed: _saveAndPop,
        ),
        const SizedBox(height: 8),
        CupertinoButton(
          child: const Text('保存后继续创作'),
          onPressed: _saveAndContinue,
        ),
        const SizedBox(height: 8),
        CupertinoButton(
          child: const Text('不满意，全部重来', style: TextStyle(color: CupertinoColors.destructiveRed)),
          onPressed: _resetToInput,
        ),
      ],
    );
  }

  Widget _buildCharPreviewCard(Map<String, dynamic> c) {
    final basic = (c['basic'] as Map<String, dynamic>?) ?? {};
    final appearance = (c['appearance'] as Map<String, dynamic>?) ?? {};
    final soul = (c['soul'] as Map<String, dynamic>?) ?? {};
    return GestureDetector(
      onTap: () => _trialChat(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: CupertinoColors.systemGrey6, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(basic['name']?.toString() ?? '?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('${basic['gender'] ?? ''} · 初始好感 ${basic['initial_affection'] ?? 50}', style: const TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel)),
                const Spacer(),
                const Icon(CupertinoIcons.chat_bubble, size: 14, color: CupertinoColors.activeBlue),
                const SizedBox(width: 4),
                const Text('试聊', style: TextStyle(fontSize: 12, color: CupertinoColors.activeBlue)),
              ],
            ),
            const SizedBox(height: 6),
            Text('外貌：${appearance['body'] ?? ''} ${appearance['hair'] ?? ''} ${appearance['eyes'] ?? ''}', style: const TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('核心：${soul['core'] ?? ''}', style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ─── 试聊 ───
  void _trialChat(Map<String, dynamic> charJson) {
    final messages = <Map<String, String>>[];
    final inputCtrl = TextEditingController();
    final scrollCtrl = ScrollController();
    StateSetter? dialogSetState;
    final app = context.read<AppProvider>();
    final playerName = app.userSettings.name.isEmpty ? '主角' : app.userSettings.name;
    final worldSummary = _meta['summary']?.toString() ?? '';

    // 临时构造一个 Character 对象用于 AI 调用
    Character character;
    try {
      character = Character.fromJson(charJson);
    } catch (_) {
      showCupertinoDialog(context: context, builder: (_) => CupertinoAlertDialog(title: const Text('角色数据不完整'), actions: [CupertinoDialogAction(child: const Text('好'), onPressed: () => Navigator.pop(context))]));
      return;
    }

    Future<void> _send() async {
      final text = inputCtrl.text.trim();
      if (text.isEmpty) return;
      messages.add({'role': 'user', 'content': text});
      inputCtrl.clear();
      messages.add({'role': 'assistant', 'content': '…'});
      dialogSetState?.call(() {});
      try {
        final reply = await app.deepSeekClient!.generateChatReply(
          userMessage: text,
          character: character,
          affection: character.initialAffection,
          chatHistory: messages.sublist(0, messages.length - 2).map((m) => <String, String>{
            'role': m['role'] == 'user' ? 'user' : 'assistant',
            'content': m['content'] ?? '',
          }).toList(),
          playerName: playerName,
          worldContext: worldSummary,
        );
        messages.last = {'role': 'assistant', 'content': reply};
      } catch (e) {
        messages.last = {'role': 'assistant', 'content': '（试聊失败：$e）'};
      }
      dialogSetState?.call(() {});
      Future.delayed(const Duration(milliseconds: 100), () {
        scrollCtrl.animateTo(scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });
    }

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text('试聊·${character.basic.name}')),
        child: SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setState) {
              dialogSetState = setState;
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final m = messages[i];
                        final isUser = m['role'] == 'user';
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: isUser ? CupertinoColors.activeBlue : CupertinoColors.systemGrey5,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(m['content'] ?? '', style: TextStyle(fontSize: 14, color: isUser ? CupertinoColors.white : CupertinoColors.black)),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: CupertinoColors.systemGrey5))),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            controller: inputCtrl,
                            placeholder: '发条消息试试…',
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Text('发送'),
                          onPressed: _send,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── 通用组件 ───
  Widget _buildPreviewCard({required String title, required String subtitle, required String body}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: CupertinoColors.systemGrey6, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CupertinoColors.secondaryLabel)),
    );
  }

  Widget _buildChipRow(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: CupertinoColors.activeBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(desc, style: const TextStyle(fontSize: 12, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text('$count', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController ctrl, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CupertinoColors.secondaryLabel)),
          const SizedBox(height: 4),
          CupertinoTextField(
            controller: ctrl,
            placeholder: hint,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  int _countEvents() {
    try {
      final events = json.decode(_eventsJson!) as Map<String, dynamic>;
      int count = 0;
      for (final key in ['daily', 'sweet_minor', 'sweet_major', 'plot', 'boundary', 'reversal', 'echo', 'misunderstanding', 'ensemble', 'world_shift', 'forced_choice', 'dialogue_trigger']) {
        final list = events[key];
        if (list is List) count += list.length;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }
}
