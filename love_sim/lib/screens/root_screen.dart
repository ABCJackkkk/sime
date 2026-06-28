import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:love_sim/main.dart';
import 'package:love_sim/providers/app_provider.dart';
import 'package:love_sim/screens/scripts_screen.dart';
import 'package:love_sim/screens/settings_screen.dart';
import 'package:love_sim/screens/simulation_screen.dart';
import 'package:love_sim/screens/profile_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  bool _checkedUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoCheckUpdate();
    });
  }

  Future<void> _autoCheckUpdate() async {
    if (_checkedUpdate) return;
    _checkedUpdate = true;
    final app = context.read<AppProvider>();
    if (app.updateService.configUrl.isEmpty) return;

    try {
      final info = await app.checkUpdate();
      if (!mounted) return;
      if (info != null && app.updateService.hasNewVersion(info)) {
        _showUpdateDialog(info);
      }
    } catch (_) {}
  }

  void _showUpdateDialog(dynamic info) {
    final app = context.read<AppProvider>();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('v${info.latestVersion}'),
            const SizedBox(height: 8),
            if (info.changelog != null && info.changelog.isNotEmpty)
              Text(info.changelog, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          if (!info.forceUpdate)
            CupertinoDialogAction(
              child: const Text('稍后'),
              onPressed: () => Navigator.pop(ctx),
            ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('去更新'),
            onPressed: () {
              Navigator.pop(ctx);
              app.updateService.openDownloadPage(info.downloadUrl);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        if (app.simActive) {
          return const SimulationScreen();
        }

        return CupertinoTabScaffold(
          tabBar: _buildGlassTabBar(app),
          tabBuilder: (context, index) {
            switch (index) {
              case 0: return const ScriptsScreen();
              case 1: return const SettingsScreen();
              case 2: return const SimSlotsScreen();
              case 3: return const ProfileScreen();
              default: return const ScriptsScreen();
            }
          },
        );
      },
    );
  }

  CupertinoTabBar _buildGlassTabBar(AppProvider app) {
    return CupertinoTabBar(
      activeColor: AppColors.accent,
      inactiveColor: AppColors.textTertiary,
      backgroundColor: const Color(0xFF0A0A0C),
      currentIndex: app.currentTabIndex,
      onTap: (index) => app.setTab(index),
      items: const [
        BottomNavigationBarItem(icon: Icon(CupertinoIcons.doc_text, size: 22), activeIcon: Icon(CupertinoIcons.doc_text_fill, size: 22), label: '剧本'),
        BottomNavigationBarItem(icon: Icon(CupertinoIcons.gear, size: 22), activeIcon: Icon(CupertinoIcons.gear_solid, size: 22), label: '设置'),
        BottomNavigationBarItem(icon: Icon(CupertinoIcons.play_rectangle, size: 22), activeIcon: Icon(CupertinoIcons.play_rectangle_fill, size: 22), label: '模拟'),
        BottomNavigationBarItem(icon: Icon(CupertinoIcons.person_circle, size: 22), activeIcon: Icon(CupertinoIcons.person_circle_fill, size: 22), label: '我的'),
      ],
    );
  }
}

class SimSlotsScreen extends StatefulWidget {
  const SimSlotsScreen({super.key});
  @override
  State<SimSlotsScreen> createState() => _SimSlotsScreenState();
}

class _SimSlotsScreenState extends State<SimSlotsScreen> {
  int _deleteConfirmIndex = -1;
  int _resetConfirmIndex = -1;

  Future<void> _newGame(AppProvider app) async {
    if (!app.hasScript) {
      app.setTab(0);
      return;
    }
    final result = await app.saveCurrentToSlot();
    if (result == 'ok') {
      app.enterSim();
    }
  }

  Future<void> _loadSlot(AppProvider app, int index) async {
    setState(() {});
    final result = await app.loadSaveSlot(index);
    if (result != 'ok' && mounted) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('加载失败'),
          content: Text(result),
          actions: [CupertinoDialogAction(child: const Text('确定'), onPressed: () => Navigator.pop(context))],
        ),
      );
    }
  }

  void _confirmDelete(int index) {
    setState(() => _deleteConfirmIndex = index);
  }

  void _cancelDelete() {
    setState(() => _deleteConfirmIndex = -1);
  }

  void _confirmReset(int index) {
    setState(() => _resetConfirmIndex = index);
  }

  void _cancelReset() {
    setState(() => _resetConfirmIndex = -1);
  }

  Future<void> _doDelete(AppProvider app, int index) async {
    await app.deleteSaveSlot(index);
    setState(() => _deleteConfirmIndex = -1);
  }

  Future<void> _doReset(AppProvider app, int index) async {
    await app.resetSaveSlot(index);
    setState(() => _resetConfirmIndex = -1);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        return Container(
          color: CupertinoTheme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            child: Column(children: [
              _buildHeader(context, app),
              Expanded(child: app.saveSlots.isEmpty ? _buildEmptyState(context, app) : _buildSlotList(context, app)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AppProvider app) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF64D2FF)])), child: const Icon(CupertinoIcons.play_fill, size: 16, color: CupertinoColors.white)),
        const SizedBox(width: 10),
        Text('模拟', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
        const Spacer(),
        CupertinoButton(
          onPressed: app.hasScript ? () => _newGame(app) : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minSize: 0,
          borderRadius: BorderRadius.circular(10),
          color: app.hasScript ? AppColors.accent : AppColors.textTertiary.withAlpha(60),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(CupertinoIcons.add, size: 14, color: CupertinoColors.white),
            const SizedBox(width: 4),
            Text('新游戏', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: app.hasScript ? CupertinoColors.white : AppColors.textTertiary)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppProvider app) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF64D2FF)]), boxShadow: [BoxShadow(color: AppColors.accent.withAlpha(60), blurRadius: 24, offset: const Offset(0, 10))]), child: const Icon(CupertinoIcons.square_stack_3d_up_fill, size: 36, color: CupertinoColors.white)),
        const SizedBox(height: 24),
        Text('还没有存档', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
        const SizedBox(height: 8),
        Text(app.hasScript ? '点击右上角「新游戏」开始' : '请先在「剧本」页加载剧本', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 28),
        CupertinoButton(
          onPressed: app.hasScript ? () => _newGame(app) : null,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
          borderRadius: BorderRadius.circular(14),
          color: app.hasScript ? AppColors.accent : AppColors.textTertiary.withAlpha(60),
          child: Text('开始新游戏', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: app.hasScript ? CupertinoColors.white : AppColors.textTertiary)),
        ),
      ]),
    );
  }

  Widget _buildSlotList(BuildContext context, AppProvider app) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: app.saveSlots.length,
      itemBuilder: (context, index) => _buildSlotCard(context, app, index),
    );
  }

  Widget _buildSlotCard(BuildContext context, AppProvider app, int index) {
    final slot = app.saveSlots[index];
    final name = slot['scriptName'] ?? '未知剧本';
    final day = slot['currentDay'] ?? '1';
    final savedAt = slot['savedAt'] as String?;
    final deleting = _deleteConfirmIndex == index;
    final resetting = _resetConfirmIndex == index;

    String timeAgo = '';
    if (savedAt != null) {
      try { final dt = DateTime.parse(savedAt); timeAgo = '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'; } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0x0AFFFFFF),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(children: [
        CupertinoButton(
          onPressed: () => _loadSlot(app, index),
          padding: const EdgeInsets.all(16),
          minSize: 0,
          borderRadius: BorderRadius.circular(16),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF64D2FF)])), child: const Icon(CupertinoIcons.book_fill, size: 22, color: CupertinoColors.white)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
              const SizedBox(height: 4),
              Row(children: [
                Icon(CupertinoIcons.calendar, size: 11, color: AppColors.textTertiary.withAlpha(180)),
                const SizedBox(width: 4),
                Text('第$day天', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (timeAgo.isNotEmpty) ...[const SizedBox(width: 10), Icon(CupertinoIcons.clock, size: 11, color: AppColors.textTertiary.withAlpha(180)), const SizedBox(width: 4), Text(timeAgo, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary))],
              ]),
            ])),
            const Icon(CupertinoIcons.chevron_right, size: 18, color: AppColors.textTertiary),
          ]),
        ),
        Container(height: 0.5, color: AppColors.border),
        if (deleting)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row(children: [
            const Icon(CupertinoIcons.exclamationmark_triangle, size: 14, color: AppColors.error),
            const SizedBox(width: 6),
            const Expanded(child: Text('确定删除此存档？数据不可恢复', style: TextStyle(fontSize: 12, color: AppColors.error))),
            CupertinoButton(onPressed: _cancelDelete, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minSize: 0, borderRadius: BorderRadius.circular(8), color: AppColors.textTertiary.withAlpha(40), child: const Text('取消', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
            const SizedBox(width: 8),
            CupertinoButton(onPressed: () => _doDelete(app, index), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minSize: 0, borderRadius: BorderRadius.circular(8), color: AppColors.error, child: const Text('确认删除', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CupertinoColors.white))),
          ]))
        else if (resetting)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row(children: [
            const Icon(CupertinoIcons.exclamationmark_triangle, size: 14, color: Color(0xFFFF9500)),
            const SizedBox(width: 6),
            const Expanded(child: Text('确定重置？所有进度将清零', style: TextStyle(fontSize: 12, color: Color(0xFFFF9500)))),
            CupertinoButton(onPressed: _cancelReset, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minSize: 0, borderRadius: BorderRadius.circular(8), color: AppColors.textTertiary.withAlpha(40), child: const Text('取消', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
            const SizedBox(width: 8),
            CupertinoButton(onPressed: () => _doReset(app, index), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minSize: 0, borderRadius: BorderRadius.circular(8), color: const Color(0xFFFF9500), child: const Text('确认重置', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CupertinoColors.white))),
          ]))
        else
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            CupertinoButton(onPressed: () => _confirmReset(index), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), minSize: 0, borderRadius: BorderRadius.circular(6), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(CupertinoIcons.arrow_counterclockwise, size: 12, color: AppColors.textTertiary), SizedBox(width: 3), Text('重置', style: TextStyle(fontSize: 11, color: AppColors.textTertiary))])),
            const SizedBox(width: 6),
            CupertinoButton(onPressed: () => _confirmDelete(index), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), minSize: 0, borderRadius: BorderRadius.circular(6), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(CupertinoIcons.trash, size: 12, color: AppColors.textTertiary), SizedBox(width: 3), Text('删除', style: TextStyle(fontSize: 11, color: AppColors.textTertiary))])),
          ]),
        ),
      ]),
    );
  }
}
