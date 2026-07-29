import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:sime/main.dart';
import 'package:sime/models/script.dart';
import 'package:sime/providers/app_provider.dart';
import 'package:sime/screens/chat_screen.dart';
import 'package:sime/widgets/typewriter_text.dart';
import 'package:sime/widgets/animated_button.dart';
import 'package:sime/widgets/skeleton_card.dart';
import 'package:sime/widgets/reactive_avatar.dart';

class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  bool _showHistory = false;
  // 记录已播放过打字动画的最新段内容，避免重建后重播
  String _lastAnimatedSegment = '';

  @override
  bool get wantKeepAlive => true;

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        // 检测AI标记法场景切换
        if (app.hasPendingSceneShift) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showSceneShiftDialog(app);
          });
        }
        return SafeArea(
          top: false,
          child: Column(children: [
            Expanded(child: _showHistory ? _buildHistoryList(app) : _buildNarrativeArea(app)),
            if (app.pendingChoices.isNotEmpty)
              ChoiceSlidePanel(child: _buildChoicePanel(app)),
            if (app.pendingInvitation.isNotEmpty) _buildInvitationBanner(app),
            _buildActionBar(app),
          ]),
        );
      },
    );
  }

  void _showSceneShiftDialog(AppProvider app) {
    final locName = app.pendingSceneShiftName;
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('场景切换'),
        content: Text('剧情建议前往「$locName」\n是否跟随切换场景？'),
        actions: [
          CupertinoDialogAction(
            child: const Text('留在这里'),
            onPressed: () { app.clearPendingSceneShift(); Navigator.of(ctx).pop(); },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('前往'),
            onPressed: () {
              final locId = app.pendingSceneShiftId;
              app.clearPendingSceneShift();
              Navigator.of(ctx).pop();
              app.enterScene(locId);
            },
          ),
        ],
      ),
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

  String _cleanText(String s) {
    return s.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  }

  Widget _buildNarrativeCard(String segment, bool isLatest, int index, AppProvider app) {
    final cleanSegment = _cleanText(segment);
    if (cleanSegment.isEmpty) return const SizedBox.shrink();
    final eventType = app.segmentEventTypes.length > index - 1 ? app.segmentEventTypes[index - 1] : '';
    final glowColor = _eventGlowColor(eventType);
    final isKeyEvent = eventType == 'sweet_major' || eventType == 'sweet.major' || eventType == 'boundary' || eventType == 'conflict' || eventType == 'forced_choice' || eventType == 'plot' || eventType == 'reversal';

    // 最新段只有内容变化时才播放打字动画；已播放过的（切回页面）直接显示全文
    final bool shouldAnimateLatest = isLatest && cleanSegment != _lastAnimatedSegment;
    if (isLatest && shouldAnimateLatest) {
      _lastAnimatedSegment = cleanSegment;
    }

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
        if (shouldAnimateLatest)
          TypewriterText(
            key: ValueKey('tw_$index'),
            text: cleanSegment,
            style: TextStyle(fontSize: 14, height: 2.2, color: AppColors.textPrimaryDark, letterSpacing: 0.3),
            speed: const Duration(milliseconds: 18),
            enabled: true,
          )
        else
          Text(cleanSegment, style: TextStyle(fontSize: 14, height: 2.2, color: AppColors.textPrimaryDark.withAlpha(200), letterSpacing: 0.3)),
      ]),
    );

    if (isLatest) {
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
    final charImg = app.getCharImageBytes(charId);
    final loc = (app.script?.events?.sceneLocations ?? []).firstWhere((l) => l.id == locId, orElse: () => SceneLocation(name: '某个地方'));
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: AppColors.accent.withAlpha(12), border: const Border(top: BorderSide(color: AppColors.accent, width: 0.5))),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: charImg != null
              ? Image.memory(charImg, width: 36, height: 36, fit: BoxFit.cover)
              : Container(width: 36, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF64D2FF)])), child: Center(child: Text(name.isNotEmpty ? name.characters.first : '?', style: const TextStyle(color: CupertinoColors.white, fontSize: 16, fontWeight: FontWeight.w700)))),
        ),
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
    final we = app.worldEngine;
    final phase = app.currentPhase;
    final weekday = we?.weekdayName ?? '';
    final weather = app.currentWeather;
    final isWeekend = we?.isWeekend ?? false;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: const BoxDecoration(color: Color(0x0AFFFFFF), border: Border(top: BorderSide(color: AppColors.border, width: 0.5))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 时间状态栏
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: AppColors.accent.withAlpha(20)), child: Text(weekday, style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600))),
          const SizedBox(width: 6),
          Expanded(child: Text(phase, style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, maxLines: 1)),
          if (isWeekend) ...[const SizedBox(width: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: const Color(0xFFFFD60A).withAlpha(25)), child: const Text('休', style: TextStyle(color: Color(0xFFFFD60A), fontSize: 10, fontWeight: FontWeight.w600)))],
          const SizedBox(width: 6),
          Text(weather, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const Spacer(),
          if (app.isLoading) const CupertinoActivityIndicator(),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: app.isLoading ? null : () => _showCalendar(context, app),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: AppColors.accent.withAlpha(15), border: Border.all(color: AppColors.accent.withAlpha(30))),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(CupertinoIcons.forward, size: 10, color: AppColors.accent), SizedBox(width: 2), Text('跳过', style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w500))]),
            ),
          ),
        ])),
        // 行动栏
        Row(children: [
          Expanded(flex: 3, child: GestureDetector(
            onTap: app.isLoading ? null : () => _showLocationPicker(context, app),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: app.isLoading ? const Color(0x03FFFFFF) : const Color(0x08FFFFFF), border: Border.all(color: app.isLoading ? AppColors.border.withAlpha(60) : AppColors.border, width: 0.5)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(CupertinoIcons.location, size: 14, color: app.isLoading ? AppColors.textTertiary : AppColors.accent), const SizedBox(width: 4), Text('去别处', style: TextStyle(color: app.isLoading ? AppColors.textTertiary : AppColors.textPrimaryDark, fontSize: 12))]),
            ),
          )),
          const SizedBox(width: 4),
          Expanded(flex: 3, child: GestureDetector(
            onTap: app.isLoading ? null : () => _showTrainingPicker(context, app),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: app.isLoading ? const Color(0x03FFFFFF) : const Color(0x08FFFFFF), border: Border.all(color: app.isLoading ? AppColors.border.withAlpha(60) : AppColors.border, width: 0.5)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(CupertinoIcons.flame, size: 14, color: app.isLoading ? AppColors.textTertiary : AppColors.warning), const SizedBox(width: 4), Text('锻炼', style: TextStyle(color: app.isLoading ? AppColors.textTertiary : AppColors.textPrimaryDark, fontSize: 12))]),
            ),
          )),
          const SizedBox(width: 4),
          Expanded(flex: 3, child: GestureDetector(
            onTap: app.isLoading ? null : () => _showCharPicker(context, app),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: app.isLoading ? const Color(0x03FFFFFF) : const Color(0x08FFFFFF), border: Border.all(color: app.isLoading ? AppColors.border.withAlpha(60) : AppColors.border, width: 0.5)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(CupertinoIcons.person_2, size: 14, color: app.isLoading ? AppColors.textTertiary : AppColors.accent), const SizedBox(width: 4), Text('互动', style: TextStyle(color: app.isLoading ? AppColors.textTertiary : AppColors.textPrimaryDark, fontSize: 12))]),
            ),
          )),
          const SizedBox(width: 4),
          Expanded(flex: 2, child: GestureDetector(
            onTap: app.isLoading ? null : () => app.passPhase().then((_) => _scrollToBottom()),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: app.isLoading ? null : const LinearGradient(colors: [AppColors.accent, Color(0xFF5B6FCE)]), color: app.isLoading ? const Color(0x08FFFFFF) : null, boxShadow: app.isLoading ? null : [BoxShadow(color: AppColors.accent.withAlpha(40), blurRadius: 8, offset: const Offset(0, 3))]),
              child: Center(child: app.isLoading ? const CupertinoActivityIndicator() : const Text('度过', style: TextStyle(color: CupertinoColors.white, fontSize: 12, fontWeight: FontWeight.w600))),
            ),
          )),
          const SizedBox(width: 4),
          CupertinoButton(
            onPressed: app.isLoading ? null : () => _showCustomActionDialog(context, app),
            padding: const EdgeInsets.all(6), minSize: 0, borderRadius: BorderRadius.circular(8),
            child: Container(width: 30, height: 30, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0x08FFFFFF), border: Border.all(color: AppColors.border, width: 0.5)),
              child: const Icon(CupertinoIcons.text_cursor, size: 15, color: AppColors.textTertiary),
            ),
          ),
        ]),
        // 角色快速入口
        if (chars.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: SizedBox(height: 36, width: double.infinity,
          child: ListView(scrollDirection: Axis.horizontal,
            children: chars.map((c) {
              final id = c.basic.id; final n = app.getCharDisplayName(id);
              final loc = we?.getCharacterLocations()[id] ?? '';
              final locName = loc.isNotEmpty ? (script?.world.locations.firstWhere((l) => l['id'] == loc, orElse: () => {'name': ''})['name'] ?? '') : '';
              final charImg = app.getCharImageBytes(id);
              return GestureDetector(
                onTap: () { app.markCharRead(id); Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ChatScreen(characterId: id))); },
                child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0x08FFFFFF)), child: Row(mainAxisSize: MainAxisSize.min, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: charImg != null
                        ? Image.memory(charImg, width: 22, height: 22, fit: BoxFit.cover)
                        : Container(width: 22, height: 22, decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF64D2FF)])), child: Center(child: Text(n.isNotEmpty ? n.characters.first : '?', style: const TextStyle(color: CupertinoColors.white, fontSize: 11, fontWeight: FontWeight.w700)))),
                  ),
                  const SizedBox(width: 4),
                  Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n, style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 10, fontWeight: FontWeight.w500)),
                    if (locName.isNotEmpty) Text(locName, style: const TextStyle(color: AppColors.textTertiary, fontSize: 8)),
                  ]),
                ])),
              );
            }).toList(),
          ),
        )),
      ]),
    );
  }

  void _showCustomActionDialog(BuildContext context, AppProvider app) {
    final ctrl = TextEditingController();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoPageScaffold(
        backgroundColor: CupertinoColors.transparent,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: const BoxDecoration(color: Color(0xFF1C1C1E), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                const Text('自定义行动', style: TextStyle(color: AppColors.textPrimaryDark, fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                CupertinoButton(padding: EdgeInsets.zero, minSize: 0, onPressed: () => Navigator.pop(ctx), child: const Text('关闭', style: TextStyle(color: AppColors.accent))),
              ])),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: CupertinoTextField(
                controller: ctrl, placeholder: '输入你想做的事…', placeholderStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14), autofocus: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(color: const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border, width: 0.5)),
                style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 15),
                maxLines: 4, minLines: 1,
              )),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    onPressed: () { final t = ctrl.text.trim(); if (t.isEmpty) return; Navigator.pop(ctx); app.customAction(t).then((_) => _scrollToBottom()); },
                    padding: const EdgeInsets.symmetric(vertical: 12), minSize: 0, borderRadius: BorderRadius.circular(10), color: const Color(0xFF32D74B),
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

  void _showLocationPicker(BuildContext context, AppProvider app) {
    final locations = app.script?.world.locations ?? [];
    showCupertinoModalPopup(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
      String? selectedLoc;
      String sceneNarrative = '';
      List sceneChars = [];
      bool loadingPreview = false;
      final actionCtrl = TextEditingController();

      return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
      decoration: const BoxDecoration(color: Color(0xFF1C1C1E), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Text(selectedLoc == null ? '去哪里？' : '做什么？', style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 17, fontWeight: FontWeight.w600)),
          const Spacer(),
          CupertinoButton(padding: EdgeInsets.zero, minSize: 0, onPressed: () => Navigator.pop(ctx), child: const Text('关闭', style: TextStyle(color: AppColors.accent))),
        ])),
        if (selectedLoc == null)
          Expanded(child: ListView.builder(itemCount: locations.length, itemBuilder: (_, i) {
            final loc = locations[i];
            final charsHere = app.worldEngine?.getCharactersAtLocation(loc['id'] ?? '') ?? [];
            return CupertinoButton(
              onPressed: () async {
                setModalState(() { selectedLoc = loc['id']; loadingPreview = true; });
                final preview = await app.previewLocation(loc['id'] ?? '');
                if (ctx.mounted) {
                  setModalState(() {
                    sceneNarrative = (preview['narrative'] ?? '').toString();
                    sceneChars = List.from(preview['characters'] ?? []);
                    loadingPreview = false;
                  });
                }
              },
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                const Icon(CupertinoIcons.location, size: 18, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(loc['name'] ?? '', style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 15)),
                  if (charsHere.isNotEmpty) Text(charsHere.map((c) => c.basic.name).join('、') + ' 在此', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ])),
                const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.textTertiary),
              ]),
            );
          }))
        else ...[
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (loadingPreview)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CupertinoActivityIndicator()))
            else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0x0AFFFFFF)),
                child: Text(sceneNarrative.isNotEmpty ? sceneNarrative : '...', style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 14, height: 1.6)),
              ),
              if (sceneChars.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('这里的人', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 6, children: sceneChars.map((ch) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.accent.withAlpha(20)),
                  child: Text(ch['name'] ?? '', style: const TextStyle(color: AppColors.accent, fontSize: 13)),
                )).toList()),
              ],
            ],
          ]))),
          Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border, width: 0.5))), child: Row(children: [
            CupertinoButton(
              onPressed: () => setModalState(() { selectedLoc = null; sceneNarrative = ''; sceneChars = []; }),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), minSize: 0, borderRadius: BorderRadius.circular(8),
              child: const Text('返回', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Expanded(child: CupertinoTextField(
              controller: actionCtrl,
              placeholder: '想做什么？（锻炼/找人/观察…）',
              placeholderStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0x08FFFFFF), borderRadius: BorderRadius.circular(10)),
              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
            )),
            const SizedBox(width: 8),
            CupertinoButton(
              onPressed: () { final act = actionCtrl.text.trim(); if (act.isEmpty) return; Navigator.pop(ctx); app.actAtLocation(selectedLoc!, act).then((_) => _scrollToBottom()); },
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), minSize: 0, borderRadius: BorderRadius.circular(10), color: AppColors.accent,
              child: const Text('行动', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CupertinoColors.white)),
            ),
          ])),
        ],
      ]));
    }));
  }

  void _showTrainingPicker(BuildContext context, AppProvider app) {
    final trainings = app.getAvailableTraining();
    showCupertinoModalPopup(context: context, builder: (ctx) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
      decoration: const BoxDecoration(color: Color(0xFF1C1C1E), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Text('锻炼什么？', style: TextStyle(color: AppColors.textPrimaryDark, fontSize: 17, fontWeight: FontWeight.w600)), const Spacer(), CupertinoButton(padding: EdgeInsets.zero, minSize: 0, onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: AppColors.accent)))])),
        if (trainings.isEmpty)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('当前时段没有可用的锻炼', style: TextStyle(color: AppColors.textTertiary))))
        else
          Expanded(child: ListView.builder(itemCount: trainings.length, itemBuilder: (_, i) {
            final t = trainings[i];
            final name = t['name']?.toString() ?? '';
            final stat = t['target_stat']?.toString() ?? '';
            final grade = t['target_grade']?.toString() ?? '';
            final gain = (t['gain'] as num?)?.toDouble() ?? 0;
            final labels = <String>[];
            if (stat.isNotEmpty) labels.add(stat + '+' + gain.toStringAsFixed(0));
            if (grade.isNotEmpty) labels.add(grade + '+' + (t['grade_gain']?.toString() ?? '1'));
            return CupertinoButton(
              onPressed: () { Navigator.pop(ctx); app.doTraining(t['id']?.toString() ?? '').then((_) => _scrollToBottom()); },
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.warning.withAlpha(25)), child: const Icon(CupertinoIcons.flame, size: 16, color: AppColors.warning)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 15)),
                  if (labels.isNotEmpty) Text(labels.join(' '), style: const TextStyle(color: AppColors.accent, fontSize: 11)),
                ])),
                const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.textTertiary),
              ]),
            );
          })),
      ]),
    ));
  }

    void _showCalendar(BuildContext context, AppProvider app) {
    final currentDay = int.tryParse(app.currentDay) ?? 1;
    final totalDays = app.worldEngine?.totalDays ?? 365;
    final today = currentDay;
    final controller = ScrollController(initialScrollOffset: ((today - 1) ~/ 7) * 60.0);

    showCupertinoModalPopup(context: context, builder: (ctx) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
      decoration: const BoxDecoration(color: Color(0xFF1C1C1E), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          const Text('日历', style: TextStyle(color: AppColors.textPrimaryDark, fontSize: 17, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('第$today天 / 共$totalDays天', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 8),
          CupertinoButton(padding: EdgeInsets.zero, minSize: 0, onPressed: () => Navigator.pop(ctx), child: const Text('关闭', style: TextStyle(color: AppColors.accent))),
        ])),
        // 周标签
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: ['一','二','三','四','五','六','日'].map((d) => Expanded(child: Center(child: Text(d, style: TextStyle(color: d == '日' ? AppColors.error : AppColors.textTertiary, fontSize: 11))))).toList())),
        Expanded(child: GridView.builder(
          controller: controller,
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 1.2),
          itemCount: totalDays,
          itemBuilder: (_, i) {
            final day = i + 1;
            final wd = (day - 1) % 7;
            final isToday = day == today;
            final isPast = day < today;
            final isWeekend = wd >= 5;
            final special = app.worldEngine?.calendar.getSpecialDay(day);
            final isSpecial = special != null;
            final isExamDay = day % 30 == 0;
            Color bg = isToday ? AppColors.accent : (isPast ? const Color(0x05FFFFFF) : const Color(0x0AFFFFFF));
            if (isSpecial) bg = const Color(0xFFFFD60A).withAlpha(30);
            return GestureDetector(
              onTap: isPast ? null : () {
                final skip = day - today;
                if (skip <= 0) return;
                Navigator.pop(ctx);
                app.skipDays(skip).then((_) => _scrollToBottom());
              },
              child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: bg, border: isToday ? Border.all(color: AppColors.accent, width: 1.5) : null), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$day', style: TextStyle(color: isPast ? AppColors.textTertiary.withAlpha(80) : (isToday ? CupertinoColors.white : (isWeekend ? AppColors.error.withAlpha(180) : AppColors.textPrimaryDark)), fontSize: isToday ? 14 : 12, fontWeight: isToday ? FontWeight.w700 : FontWeight.w400)),
                if (isSpecial) Text(special['name']?.toString() ?? '', style: const TextStyle(color: Color(0xFFFFD60A), fontSize: 7), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (isExamDay && !isSpecial) const Text('考试', style: TextStyle(color: AppColors.warning, fontSize: 7)),
              ])),
            );
          },
        )),
      ]),
    ));
  }
  void _showCharPicker(BuildContext context, AppProvider app) {
    final chars = app.script?.characters.where((c) => c.fullCharacter).toList() ?? [];
    final locs = app.worldEngine?.getCharacterLocations() ?? {};
    final affs = app.affectionStates;
    final controller = TextEditingController();
    String selectedChar = '';
    showCupertinoModalPopup(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
      decoration: const BoxDecoration(color: Color(0xFF1C1C1E), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Text('找谁？', style: TextStyle(color: AppColors.textPrimaryDark, fontSize: 17, fontWeight: FontWeight.w600)), const Spacer(), CupertinoButton(padding: EdgeInsets.zero, minSize: 0, onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: AppColors.accent)))])),
        Expanded(child: ListView.builder(itemCount: chars.length, itemBuilder: (_, i) {
          final ch = chars[i];
          final charLocName = (() { final lid = locs[ch.basic.id] ?? ''; return app.script?.world.locations.firstWhere((l) => l['id'] == lid, orElse: () => {'name': ''})['name'] ?? ''; })();
          final aff = (affs[ch.basic.id] ?? 50).toStringAsFixed(0);
          final isSelected = selectedChar == ch.basic.id;
          return CupertinoButton(
            onPressed: () => setModalState(() { selectedChar = ch.basic.id; }),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: LinearGradient(colors: isSelected ? [AppColors.accent, const Color(0xFF64D2FF)] : [AppColors.textTertiary.withAlpha(80), AppColors.textTertiary.withAlpha(40)])), child: Center(child: Text(ch.basic.name.characters.first, style: const TextStyle(color: CupertinoColors.white, fontSize: 16, fontWeight: FontWeight.w700)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ch.basic.name, style: TextStyle(color: isSelected ? AppColors.accent : AppColors.textPrimaryDark, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(charLocName.isNotEmpty ? charLocName : '位置未知', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                Text('好感 ' + aff, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
              ])),
              if (isSelected) const Icon(CupertinoIcons.checkmark_alt, color: AppColors.accent, size: 20),
            ]),
          );
        })),
        if (selectedChar.isNotEmpty) ...[
          Container(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border, width: 0.5))), child: Row(children: [
            Expanded(child: CupertinoTextField(
              controller: controller,
              placeholder: '你想做什么？（问好/聊天/帮忙…）',
              placeholderStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0x08FFFFFF), borderRadius: BorderRadius.circular(10)),
              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
            )),
            const SizedBox(width: 8),
            CupertinoButton(
              onPressed: () { final act = controller.text.trim(); if (act.isEmpty) return; Navigator.pop(ctx); app.interactWithChar(selectedChar, act).then((_) => _scrollToBottom()); },
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), minSize: 0, borderRadius: BorderRadius.circular(10), color: AppColors.accent,
              child: const Text('行动', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CupertinoColors.white)),
            ),
          ])),
          const SizedBox(height: 8),
        ],
      ]),
    )));
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
