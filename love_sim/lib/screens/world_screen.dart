import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:love_sim/main.dart';
import 'package:love_sim/models/script.dart';
import 'package:love_sim/providers/app_provider.dart';
import 'package:love_sim/screens/chat_screen.dart';
import 'package:love_sim/widgets/typewriter_text.dart';
import 'package:love_sim/widgets/animated_button.dart';
import 'package:love_sim/widgets/skeleton_card.dart';
import 'package:love_sim/widgets/reactive_avatar.dart';

class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _customActionCtrl = TextEditingController();
  bool _showCustomAction = false;
  bool _showHistory = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _customActionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        return Column(children: [
          Expanded(child: _showHistory ? _buildHistoryList(app) : _buildNarrativeArea(app)),
          if (app.pendingChoices.isNotEmpty)
            ChoiceSlidePanel(child: _buildChoicePanel(app)),
          if (app.pendingInvitation.isNotEmpty) _buildInvitationBanner(app),
          _buildActionBar(app),
        ]);
      },
    );
  }

  Widget _buildNarrativeArea(AppProvider app) {
    final segments = app.narrativeSegments;
    if (segments.isEmpty) {
      if (app.isLoading) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const SkeletonCard(height: 90),
            const SizedBox(height: 6),
            const SkeletonCard(height: 70),
          ]),
        );
      }
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(CupertinoIcons.book, size: 40, color: AppColors.textTertiary.withAlpha(100)),
          const SizedBox(height: 12),
          Text('故事即将展开...', style: TextStyle(color: AppColors.textTertiary.withAlpha(180), fontSize: 15)),
        ]),
      );
    }

    return CupertinoScrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: segments.length,
        itemBuilder: (context, index) => _buildNarrativeCard(segments[index], index == segments.length - 1, index + 1, app),
      ),
    );
  }

  Widget _buildHistoryList(AppProvider app) {
    final segments = app.narrativeSegments;
    if (segments.isEmpty) {
      return Center(child: Text('暂无记录', style: TextStyle(color: AppColors.textTertiary.withAlpha(180), fontSize: 15)));
    }
    return CupertinoScrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: segments.length,
        itemBuilder: (context, index) => _buildNarrativeCard(segments[index], false, index + 1, app),
      ),
    );
  }

  String _eventLabel(String eventType) {
    switch (eventType) {
      case 'sweet_major': case 'sweet.major': return '重要时刻';
      case 'boundary': return '边界突破';
      case 'conflict': case 'misunderstanding': return '冲突';
      case 'reversal': return '转折';
      case 'forced_choice': return '抉择';
      case 'plot': return '剧情';
      case 'breakthrough': return '破阶';
      default: return eventType;
    }
  }

  Widget _buildNarrativeCard(String segment, bool isLatest, int index, AppProvider app) {
    final eventType = app.segmentEventTypes.length > index - 1 ? app.segmentEventTypes[index - 1] : '';
    final glowColor = _eventGlowColor(eventType);
    final isKeyEvent = eventType == 'sweet_major' || eventType == 'sweet.major' || eventType == 'boundary' || eventType == 'conflict' || eventType == 'forced_choice' || eventType == 'plot' || eventType == 'reversal';

    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isLatest ? glowColor.withAlpha(10) : const Color(0x08FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isLatest && !isKeyEvent ? AppColors.accent.withAlpha(60) : AppColors.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('# $index', style: TextStyle(fontSize: 10, color: AppColors.textTertiary.withAlpha(140))),
          if (isKeyEvent && eventType.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: glowColor.withAlpha(30), borderRadius: BorderRadius.circular(4)),
              child: Text(_eventLabel(eventType), style: TextStyle(fontSize: 9, color: glowColor, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        if (isLatest)
          TypewriterText(
            text: segment,
            style: TextStyle(fontSize: 14, height: 2.2, color: AppColors.textPrimaryDark, letterSpacing: 0.3),
            speed: const Duration(milliseconds: 18),
            enabled: true,
          )
        else
          Text(segment, style: TextStyle(fontSize: 14, height: 2.2, color: AppColors.textPrimaryDark.withAlpha(200), letterSpacing: 0.3)),
      ]),
    );

    if (isLatest && (isKeyEvent || true)) {
      return _PulsingBorder(baseColor: isKeyEvent ? glowColor : AppColors.accent, borderRadius: 16, width: 1.2, child: cardContent);
    }

    return cardContent;
  }

  Widget _buildChoicePanel(AppProvider app) {
    final choices = app.pendingChoices;
    if (choices.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: const BoxDecoration(color: Color(0x0AFFFFFF), border: Border(top: BorderSide(color: AppColors.accent, width: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: const Row(children: [
            Icon(CupertinoIcons.hand_raised, size: 14, color: AppColors.accent),
            SizedBox(width: 6),
            Text('做出选择', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
          ]),
        ),
        ...List.generate(choices.length, (i) {
          final choice = choices[i];
          final text = choice['text'] as String? ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: CupertinoButton(
              onPressed: () => app.pickChoice(i).then((_) => _scrollToBottom()),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderRadius: BorderRadius.circular(12),
              color: const Color(0x0FFFFFFF),
              child: Row(children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withAlpha(30)),
                  child: Center(child: Text('ABC'[i], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimaryDark, height: 1.4))),
                const SizedBox(width: 6),
                const Icon(CupertinoIcons.chevron_right, size: 14, color: AppColors.textTertiary),
              ]),
            ),
          );
        }),
      ]),
    );
  }

  Widget _buildInvitationBanner(AppProvider app) {
    final inv = app.pendingInvitation;
    if (inv.isEmpty) return const SizedBox.shrink();
    final charId = inv.keys.first;
    final locId = inv.values.first;
    app.getCharacter(charId);
    final name = app.getCharDisplayName(charId);
    final loc = (app.script?.events?.sceneLocations ?? []).firstWhere((l) => l.id == locId, orElse: () => SceneLocation(name: '某个地方'));
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: AppColors.accent.withAlpha(12), border: const Border(top: BorderSide(color: AppColors.accent, width: 0.5))),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF64D2FF)])), child: Center(child: Text(name.isNotEmpty ? name.characters.first : '?', style: const TextStyle(color: CupertinoColors.white, fontSize: 16, fontWeight: FontWeight.w700)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$name 邀请你去${loc.name}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark)),
          const SizedBox(height: 2),
          Text('点击头像前往 →', style: TextStyle(fontSize: 11, color: AppColors.textTertiary.withAlpha(200))),
        ])),
        GestureDetector(
          onTap: () async {
            app.clearInvitation(charId);
            final result = await app.triggerSceneEvent(locId, charId);
            final narrative = result['narrative'] as String? ?? '';
            if (narrative.isNotEmpty) {
              app.narrativeSegments.add(narrative);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF5B6FCE)])),
            child: const Text('赴约', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CupertinoColors.white)),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => app.clearInvitation(charId),
          child: const Icon(CupertinoIcons.xmark, size: 18, color: AppColors.textTertiary),
        ),
      ]),
    );
  }

  Widget _buildActionBar(AppProvider app) {
    final script = app.script;
    final chars = script?.characters.where((c) => c.fullCharacter).toList() ?? [];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: const BoxDecoration(color: Color(0x0AFFFFFF), border: Border(top: BorderSide(color: AppColors.border, width: 0.5))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_showCustomAction)
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
            Expanded(
              child: CupertinoTextField(
                controller: _customActionCtrl, placeholder: '输入你想做的事…', placeholderStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: const Color(0x08FFFFFF), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border, width: 0.5)),
                style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              onPressed: app.isLoading ? null : () { final t = _customActionCtrl.text.trim(); if (t.isEmpty) return; _customActionCtrl.clear(); app.customAction(t).then((_) => _scrollToBottom()); },
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), minSize: 0, borderRadius: BorderRadius.circular(10), color: const Color(0xFF32D74B),
              child: const Text('执行', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CupertinoColors.white)),
            ),
          ])),
        Row(children: [
          if (chars.isNotEmpty) ...[
            SizedBox(height: 44, width: 100,
              child: ListView(scrollDirection: Axis.horizontal,
                children: chars.map((c) {
                  final id = c.basic.id; final n = app.getCharDisplayName(id);
                  final img = app.getCharImageBytes(id);
                  final affect = app.affectionStates[id] ?? 50.0;
                  final recentEvent = app.segmentEventTypes.isNotEmpty ? app.segmentEventTypes.last : null;
                  return GestureDetector(
                    onTap: () { app.markCharRead(id); Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ChatScreen(characterId: id))); },
                    child: ReactiveAvatar(
                      size: 36, borderRadius: 10, affection: affect, recentEventType: recentEvent,
                      child: Container(margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
                        child: img != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(img, width: 36, height: 36, fit: BoxFit.cover))
                            : Container(decoration: const BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(10)), gradient: LinearGradient(colors: [AppColors.accent, Color(0xFF64D2FF)])), child: Center(child: Text(n.isNotEmpty ? n.characters.first : '?', style: const TextStyle(color: CupertinoColors.white, fontSize: 15, fontWeight: FontWeight.w700)))),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 6), color: AppColors.border),
          ],
          Expanded(child: Row(children: [
            Expanded(flex: 2,
              child: AnimatedButton(
                onTap: app.isLoading ? null : () => app.advance('daily').then((_) => _scrollToBottom()),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: app.isLoading ? AppColors.border : AppColors.borderStrong, width: 0.5), color: const Color(0x08FFFFFF)),
                  child: Center(child: Text('日常', style: TextStyle(color: AppColors.textPrimaryDark.withAlpha(app.isLoading ? 100 : 255), fontSize: 13, fontWeight: FontWeight.w500))),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(flex: 2,
              child: AnimatedButton(
                onTap: app.isLoading ? null : () => app.advance('major').then((_) => _scrollToBottom()),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: app.isLoading ? null : const LinearGradient(colors: [AppColors.accent, Color(0xFF5B6FCE)]), color: app.isLoading ? const Color(0x08FFFFFF) : null, border: app.isLoading ? Border.all(color: AppColors.border, width: 0.5) : null, boxShadow: app.isLoading ? null : [BoxShadow(color: AppColors.accent.withAlpha(40), blurRadius: 8, offset: const Offset(0, 3))]),
                  child: Center(child: Text('推进', style: TextStyle(color: app.isLoading ? AppColors.textTertiary : CupertinoColors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                ),
              ),
            ),
          ])),
          const SizedBox(width: 4),
          CupertinoButton(
            onPressed: () => setState(() { _showHistory = !_showHistory; }),
            padding: const EdgeInsets.all(6), minSize: 0, borderRadius: BorderRadius.circular(8),
            child: Container(width: 30, height: 30, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: _showHistory ? AppColors.accent.withAlpha(25) : const Color(0x08FFFFFF), border: Border.all(color: _showHistory ? AppColors.accent.withAlpha(60) : AppColors.border, width: 0.5)),
              child: Icon(CupertinoIcons.clock, size: 15, color: _showHistory ? AppColors.accent : AppColors.textTertiary),
            ),
          ),
          const SizedBox(width: 4),
          CupertinoButton(
            onPressed: () => setState(() { _showCustomAction = !_showCustomAction; _customActionCtrl.clear(); }),
            padding: const EdgeInsets.all(6), minSize: 0, borderRadius: BorderRadius.circular(8),
            child: Container(width: 30, height: 30, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: _showCustomAction ? const Color(0xFF32D74B).withAlpha(25) : const Color(0x08FFFFFF), border: Border.all(color: _showCustomAction ? const Color(0xFF32D74B).withAlpha(60) : AppColors.border, width: 0.5)),
              child: Icon(CupertinoIcons.text_cursor, size: 15, color: _showCustomAction ? const Color(0xFF32D74B) : AppColors.textTertiary),
            ),
          ),
        ]),
      ]),
    );
  }
}

Color _eventGlowColor(String eventType) {
  switch (eventType) {
    case 'sweet_major':
    case 'sweet.major':
      return const Color(0xFF5AE0A0);
    case 'boundary':
    case 'breakthrough':
      return const Color(0xFFFFB74D);
    case 'conflict':
    case 'misunderstanding':
    case 'reversal':
      return const Color(0xFFFF6B6B);
    case 'forced_choice':
    case 'plot':
      return const Color(0xFF7B8CDE);
    default:
      return AppColors.accent;
  }
}

class ChoiceSlidePanel extends StatefulWidget {
  final Widget child;
  const ChoiceSlidePanel({super.key, required this.child});

  @override
  State<ChoiceSlidePanel> createState() => _ChoiceSlidePanelState();
}

class _ChoiceSlidePanelState extends State<ChoiceSlidePanel> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _slide, child: widget.child);
  }
}

class _PulsingBorder extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final double borderRadius;
  final double width;

  const _PulsingBorder({
    required this.child,
    required this.baseColor,
    this.borderRadius = 16,
    this.width = 1.5,
  });

  @override
  State<_PulsingBorder> createState() => _PulsingBorderState();
}

class _PulsingBorderState extends State<_PulsingBorder> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final alpha = (30 + (_ctrl.value * 70)).round();
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: widget.baseColor.withAlpha(alpha), width: widget.width),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
