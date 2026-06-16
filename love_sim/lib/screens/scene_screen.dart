import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:provider/provider.dart';
import 'package:love_sim/main.dart';
import 'package:love_sim/models/script.dart';
import 'package:love_sim/providers/app_provider.dart';

class SceneScreen extends StatefulWidget {
  const SceneScreen({super.key});

  @override
  State<SceneScreen> createState() => _SceneScreenState();
}

class _SceneScreenState extends State<SceneScreen> {
  void _refresh() {
    context.read<AppProvider>().refreshSceneChars();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Consumer<AppProvider>(
        builder: (context, app, _) {
          final script = app.script;
          final locations = script?.events?.sceneLocations ?? [];
          return SafeArea(
            child: Column(children: [
              _buildHeader(app),
              if (locations.isEmpty)
                Expanded(child: Center(child: Text('暂无场景数据', style: TextStyle(color: AppColors.textTertiary.withAlpha(180), fontSize: 15))))
              else
                Expanded(
                  child: CupertinoScrollbar(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: locations.length,
                      itemBuilder: (context, index) => _buildLocationCard(app, locations[index]),
                    ),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildHeader(AppProvider app) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: 0,
      opacity: 0.06,
      child: Row(children: [
        const Icon(CupertinoIcons.location, size: 16, color: AppColors.accent),
        const SizedBox(width: 8),
        const Text('场景', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark)),
        const Spacer(),
        Text('第${app.currentDay}天 ${app.currentPhase}', style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: const EdgeInsets.all(6), minSize: 0,
          onPressed: _refresh,
          child: const Icon(CupertinoIcons.refresh, size: 16, color: AppColors.textTertiary),
        ),
      ]),
    );
  }

  Widget _buildLocationCard(AppProvider app, SceneLocation loc) {
    final sceneChars = app.getSceneChars(loc.id);
    final currentPhase = app.currentPhase;
    final isAvailable = loc.availablePhases.isEmpty || loc.availablePhases.contains(currentPhase);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0x08FFFFFF),
        border: Border.all(color: isAvailable ? AppColors.border : AppColors.border.withAlpha(80), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: isAvailable ? AppColors.accent.withAlpha(25) : AppColors.textTertiary.withAlpha(15)),
            child: Center(child: Icon(
              _locationIcon(loc.id, loc.visibilityDefault),
              size: 18,
              color: isAvailable ? AppColors.accent : AppColors.textTertiary,
            )),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(loc.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isAvailable ? AppColors.textPrimaryDark : AppColors.textTertiary)),
              if (!isAvailable) ...[
                const SizedBox(width: 6),
                Text('（${currentPhase}不可达）', style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
              ],
            ]),
            const SizedBox(height: 2),
            Text(loc.desc.length > 40 ? '${loc.desc.substring(0, 40)}...' : loc.desc, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: loc.visibilityDefault == 'private' ? AppColors.warning.withAlpha(15) : AppColors.success.withAlpha(15)),
            child: Text(loc.visibilityDefault == 'private' ? '私密' : '公共', style: TextStyle(fontSize: 10, color: loc.visibilityDefault == 'private' ? AppColors.warning : AppColors.success)),
          ),
        ]),
        if (sceneChars.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('偶遇角色', style: TextStyle(fontSize: 11, color: AppColors.textTertiary.withAlpha(180))),
          const SizedBox(height: 8),
          ...sceneChars.map((charId) {
            final char = app.getCharacter(charId);
            if (char == null) return const SizedBox.shrink();
            final name = app.getCharDisplayName(charId);
            final affection = app.getAffection(charId);
            final charImg = app.getCharImageBytes(charId);
            return _buildCharRow(app, charId, char, name, affection, charImg, loc);
          }),
        ],
        if (sceneChars.isEmpty) ...[
          const SizedBox(height: 10),
          Text('当前无人', style: TextStyle(fontSize: 12, color: AppColors.textTertiary.withAlpha(120))),
        ],
      ]),
    );
  }

  Widget _buildCharRow(AppProvider app, String charId, Character char, String name, double affection, Uint8List? charImg, SceneLocation loc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _triggerSceneEvent(app, charId, char, name, loc),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppColors.accent.withAlpha(8),
            border: Border.all(color: AppColors.accent.withAlpha(30), width: 0.5),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF64D2FF)])),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: charImg != null
                    ? Image.memory(charImg, width: 36, height: 36, fit: BoxFit.cover)
                    : Center(child: Text(name.isNotEmpty ? name.characters.first : '?', style: const TextStyle(color: CupertinoColors.white, fontSize: 15, fontWeight: FontWeight.w700))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 14, color: AppColors.textPrimaryDark))),
            Text('♥ ${affection.toStringAsFixed(1)}', style: TextStyle(fontSize: 12, color: _affectionColor(affection))),
            const SizedBox(width: 8),
            const Icon(CupertinoIcons.chevron_right, size: 14, color: AppColors.textTertiary),
          ]),
        ),
      ),
    );
  }

  void _triggerSceneEvent(AppProvider app, String charId, Character char, String name, SceneLocation loc) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 20, color: AppColors.accent)),
    );
    app.triggerSceneEvent(loc.id, charId).then((result) {
      Navigator.of(context).pop();
      final narrative = result['narrative'] as String? ?? '';
      final delta = (result['delta'] as num?)?.toDouble() ?? 0.0;
      if (narrative.isEmpty) return;
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: Row(children: [
            const Icon(CupertinoIcons.location, size: 18, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(loc.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark)),
          ]),
          content: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(narrative, style: const TextStyle(fontSize: 14, color: AppColors.textPrimaryDark, height: 1.7)),
              if (delta.abs() > 0.05) ...[
                const SizedBox(height: 10),
                Text(delta > 0 ? '♥ 好感度 +${delta.toStringAsFixed(2)}' : '♥ 好感度 ${delta.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: delta > 0 ? AppColors.error : AppColors.textTertiary)),
              ],
            ]),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('好的', style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );
    });
  }

  Color _affectionColor(double val) {
    if (val < 20) return AppColors.error;
    if (val < 40) return const Color(0xFFFF9800);
    if (val < 60) return const Color(0xFF64D2FF);
    if (val < 80) return AppColors.accent;
    return const Color(0xFF9C27B0);
  }

  IconData _locationIcon(String id, String visibility) {
    if (visibility == 'private') return CupertinoIcons.lock_rotation;
    if (id.contains('class')) return CupertinoIcons.book;
    if (id.contains('library')) return CupertinoIcons.tray_full;
    if (id.contains('rooftop') || id.contains('tian')) return CupertinoIcons.sun_max;
    if (id.contains('play') || id.contains('cao')) return CupertinoIcons.sportscourt;
    if (id.contains('gate') || id.contains('men')) return CupertinoIcons.bus;
    if (id.contains('shop') || id.contains('mai')) return CupertinoIcons.cart;
    return CupertinoIcons.map_pin;
  }
}
