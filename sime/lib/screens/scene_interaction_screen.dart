import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:provider/provider.dart';
import 'package:sime/main.dart';
import 'package:sime/models/script.dart';
import 'package:sime/providers/app_provider.dart';

class SceneInteractionScreen extends StatefulWidget {
  final SceneLocation location;

  const SceneInteractionScreen({super.key, required this.location});

  @override
  State<SceneInteractionScreen> createState() => _SceneInteractionScreenState();
}

class _SceneInteractionScreenState extends State<SceneInteractionScreen> {
  String _atmosphere = '';
  List<String> _charIds = [];
  List<Map<String, dynamic>> _choices = [];
  List<_NarrativeEntry> _narrativeEntries = [];
  bool _isLoading = false;
  bool _initialized = false;
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _showFreeInput = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initScene());
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _initScene() async {
    final app = context.read<AppProvider>();
    setState(() => _isLoading = true);
    final result = await app.enterScene(widget.location.id);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _initialized = true;
      _atmosphere = result['atmosphere'] as String? ?? '';
      _charIds = List<String>.from(result['chars'] as List? ?? []);
      _choices = List<Map<String, dynamic>>.from(result['choices'] as List? ?? []);
      if (_atmosphere.isNotEmpty) {
        _narrativeEntries.add(_NarrativeEntry(_atmosphere, false));
      }
    });
    _scrollToBottom();
  }

  Future<void> _onChoice(int index) async {
    if (_isLoading || index >= _choices.length) return;
    final choiceText = _choices[index]['text'] as String? ?? '';
    setState(() {
      _narrativeEntries.add(_NarrativeEntry(choiceText, true));
      _isLoading = true;
      _choices = [];
      _showFreeInput = false;
      _inputCtrl.clear();
    });
    _scrollToBottom();

    final app = context.read<AppProvider>();
    final result = await app.actInScene(index.toString());
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      final narrative = result['narrative'] as String? ?? '';
      if (narrative.isNotEmpty) {
        _narrativeEntries.add(_NarrativeEntry(narrative, false));
      }
      _choices = List<Map<String, dynamic>>.from(result['choices'] as List? ?? []);
    });
    _scrollToBottom();
  }

  Future<void> _onFreeAction() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isLoading) return;
    _inputCtrl.clear();
    await _submitFreeAction(text);
  }

  void _showFreeInputDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoPageScaffold(
        backgroundColor: CupertinoColors.transparent,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: const BoxDecoration(color: Color(0xFFFFFFFF), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                const Text('自己写', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                CupertinoButton(padding: EdgeInsets.zero, minSize: 0, onPressed: () => Navigator.pop(ctx), child: const Text('关闭', style: TextStyle(color: AppColors.accent))),
              ])),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: CupertinoTextField(
                controller: ctrl, placeholder: '写你想说的话或行动...', placeholderStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14), autofocus: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(color: const Color(0x0D000000), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border, width: 0.5)),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                maxLines: 5, minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (v) { final t = v.trim(); if (t.isEmpty) return; Navigator.pop(ctx); _submitFreeAction(t); },
              )),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    onPressed: () { final t = ctrl.text.trim(); if (t.isEmpty) return; Navigator.pop(ctx); _submitFreeAction(t); },
                    padding: const EdgeInsets.symmetric(vertical: 12), minSize: 0, borderRadius: BorderRadius.circular(10), color: AppColors.accent,
                    child: const Text('执行', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CupertinoColors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _submitFreeAction(String text) async {
    setState(() {
      _narrativeEntries.add(_NarrativeEntry(text, true));
      _isLoading = true;
      _choices = [];
    });
    _scrollToBottom();

    final app = context.read<AppProvider>();
    final result = await app.actInScene(text, isFreeText: true);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      final narrative = result['narrative'] as String? ?? '';
      if (narrative.isNotEmpty) {
        _narrativeEntries.add(_NarrativeEntry(narrative, false));
      }
      _choices = List<Map<String, dynamic>>.from(result['choices'] as List? ?? []);
    });
    _scrollToBottom();
  }

  void _onLeave() async {
    Navigator.of(context).pop();
    await context.read<AppProvider>().leaveScene();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.transparent,
      resizeToAvoidBottomInset: false,
      child: Consumer<AppProvider>(
        builder: (context, app, _) {
          final loc = widget.location;
          final visibilityHint = loc.visibilityDefault == 'private' ? '私密' : '公共';
          final locationIcon = _locationIcon(loc.id, loc.visibilityDefault);

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [app.simBgStartColor, app.simBgEndColor],
              ),
            ),
            child: SafeArea(
              child: Column(children: [
                _buildTopBar(loc.name, visibilityHint, locationIcon, app),
                Expanded(
                  child: _isLoading && !_initialized
                      ? const Center(child: CupertinoActivityIndicator(radius: 18, color: AppColors.accent))
                      : _buildNarrativeArea(),
                ),
                _buildActionBar(),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar(String name, String visibility, IconData icon, AppProvider app) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x05000000),
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(children: [
        CupertinoButton(
          padding: EdgeInsets.zero, minSize: 0,
          onPressed: () => _onLeave(),
          child: const Icon(CupertinoIcons.chevron_left, size: 20, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: visibility == '私密' ? AppColors.warning.withAlpha(20) : AppColors.success.withAlpha(20),
          ),
          child: Text(visibility, style: TextStyle(fontSize: 10, color: visibility == '私密' ? AppColors.warning : AppColors.success)),
        ),
        const Spacer(),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minSize: 0,
          onPressed: _isLoading ? null : _onLeave,
          child: const Text('离开', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
      ]),
    );
  }

  Widget _buildNarrativeArea() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(children: [
        if (_charIds.isNotEmpty) _buildCharBar(),
        Expanded(
          child: CupertinoScrollbar(
            controller: _scrollCtrl,
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _narrativeEntries.length,
              itemBuilder: (context, index) {
                final entry = _narrativeEntries[index];
                return _buildNarrativeBubble(entry);
              },
            ),
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: CupertinoActivityIndicator(radius: 12, color: AppColors.accent),
          ),
      ]),
    );
  }

  Widget _buildCharBar() {
    final app = context.read<AppProvider>();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0x08000000),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: _charIds.map((id) {
          final name = app.getCharDisplayName(id);
          final affection = app.getAffection(id);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColors.accent.withAlpha(15),
            ),
            child: Text('$name  ♥ ${affection.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNarrativeBubble(_NarrativeEntry entry) {
    if (entry.isPlayer) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Spacer(flex: 2),
          Flexible(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.accent.withAlpha(25),
              ),
              child: Text(entry.text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.6)),
            ),
          ),
        ]),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFFFFFFF),
      ),
      child: Text(entry.text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.8)),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0x0C000000),
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_choices.isNotEmpty) ..._buildChoiceButtons(),
        if (_choices.isNotEmpty && !_showFreeInput) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showFreeInputDialog(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(CupertinoIcons.pencil, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                const Text('自己写...', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
              ]),
            ),
          ),
        ],
        if (_choices.isEmpty) _buildFreeInput(),
      ]),
    );
  }

  List<Widget> _buildChoiceButtons() {
    return _choices.asMap().entries.map((e) {
      final index = e.key;
      final choice = e.value;
      final text = choice['text'] as String? ?? '';
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.accent.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
          onPressed: _isLoading ? null : () => _onChoice(index),
          child: Row(children: [
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
            ),
          ]),
        ),
      );
    }).toList();
  }

  Widget _buildFreeInput() {
    return Row(children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0x08000000),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: CupertinoTextField(
            controller: _inputCtrl,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            placeholder: '写你想说的话或行动...',
            placeholderStyle: const TextStyle(fontSize: 14, color: AppColors.textTertiary),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _onFreeAction(),
          ),
        ),
      ),
      const SizedBox(width: 8),
      CupertinoButton(
        padding: const EdgeInsets.all(12),
        minSize: 0,
        color: AppColors.accent.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
        onPressed: _isLoading ? null : _onFreeAction,
        child: const Icon(CupertinoIcons.arrow_up, size: 18, color: AppColors.accent),
      ),
    ]);
  }

  IconData _locationIcon(String id, String visibility) {
    if (visibility == 'private') return CupertinoIcons.lock_rotation;
    if (id.contains('class')) return CupertinoIcons.book;
    if (id.contains('library')) return CupertinoIcons.tray_full;
    if (id.contains('rooftop') || id.contains('tian')) return CupertinoIcons.sun_max;
    if (id.contains('play') || id.contains('cao')) return CupertinoIcons.sportscourt;
    if (id.contains('canteen') || id.contains('shi')) return CupertinoIcons.cart;
    if (id.contains('gate') || id.contains('men')) return CupertinoIcons.map_pin;
    if (id.contains('piano') || id.contains('qin')) return CupertinoIcons.music_note_2;
    if (id.contains('dorm') || id.contains('su')) return CupertinoIcons.bed_double;
    return CupertinoIcons.location;
  }
}

class _NarrativeEntry {
  final String text;
  final bool isPlayer;

  _NarrativeEntry(this.text, this.isPlayer);
}
