import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:love_sim/main.dart';
import 'package:love_sim/providers/app_provider.dart';
import 'package:love_sim/screens/world_screen.dart';
import 'package:love_sim/screens/contacts_screen.dart';
import 'package:love_sim/screens/shop_screen.dart';
import 'package:love_sim/screens/scene_screen.dart';
import 'package:love_sim/screens/sim_settings_screen.dart';
import 'package:love_sim/screens/sim_profile_screen.dart';

class SimulationScreen extends StatelessWidget {
  const SimulationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        if (!app.hasScript) { app.exitSim(); return const SizedBox.shrink(); }
        return SafeArea(top: false, bottom: false, child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: app.simInWorldView ? _buildWorldView(app, context) : _buildToolsView(app, context),
        ));
      },
    );
  }

  Widget _buildWorldView(AppProvider app, BuildContext context) {
    final simBg = app.simBgImageBytes;
    return Container(
      key: const ValueKey('world'),
      decoration: simBg != null
          ? BoxDecoration(image: DecorationImage(image: MemoryImage(simBg), fit: BoxFit.cover))
          : BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [app.simBgStartColor, app.simBgEndColor])),
      child: Column(children: [
        _buildWorldTopBar(app, context),
        const Expanded(child: WorldScreen()),
      ]),
    );
  }

  Widget _buildToolsView(AppProvider app, BuildContext context) {
    final simBg = app.simBgImageBytes;
    return Container(
      key: const ValueKey('tools'),
      decoration: simBg != null
          ? BoxDecoration(image: DecorationImage(image: MemoryImage(simBg), fit: BoxFit.cover))
          : BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [app.simBgStartColor, app.simBgEndColor])),
      child: Column(children: [
        _buildToolsTopBar(app, context),
        Expanded(
          child: CupertinoTabScaffold(
            tabBar: CupertinoTabBar(
              activeColor: AppColors.accent,
              inactiveColor: AppColors.textTertiary,
              backgroundColor: CupertinoColors.black.withAlpha(30),
              currentIndex: app.simTabIndex,
              onTap: (index) => app.setSimTab(index),
              items: const [
                BottomNavigationBarItem(icon: Icon(CupertinoIcons.person_2, size: 22), activeIcon: Icon(CupertinoIcons.person_2_fill, size: 22), label: '通讯录'),
                BottomNavigationBarItem(icon: Icon(CupertinoIcons.bag, size: 22), activeIcon: Icon(CupertinoIcons.bag_fill, size: 22), label: '商店'),
                BottomNavigationBarItem(icon: Icon(CupertinoIcons.location, size: 22), activeIcon: Icon(CupertinoIcons.location_fill, size: 22), label: '场景'),
                BottomNavigationBarItem(icon: Icon(CupertinoIcons.gear, size: 22), activeIcon: Icon(CupertinoIcons.gear_solid, size: 22), label: '设置'),
                BottomNavigationBarItem(icon: Icon(CupertinoIcons.person, size: 22), activeIcon: Icon(CupertinoIcons.person_fill, size: 22), label: '我的'),
              ],
            ),
            tabBuilder: (context, index) {
              switch (index) {
                case 0: return const ContactsScreen();
                case 1: return const ShopScreen();
                case 2: return const SceneScreen();
                case 3: return const SimSettingsScreen();
                case 4: return const SimProfileScreen();
                default: return const ContactsScreen();
              }
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildWorldTopBar(AppProvider app, BuildContext context) {
    final we = app.worldEngine;
    final weekday = we?.weekdayName ?? '';
    final day = int.tryParse(app.currentDay) ?? 1;
    final weekNum = ((day - 1) ~/ 7) + 1;
    final isWeekend = we?.isWeekend ?? false;
    final special = we?.currentSpecialDay;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0x08FFFFFF),
      child: Row(children: [
        const SizedBox(width: 4),
        Text('第${weekNum}周', style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Text('第${day}天', style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        Text(weekday, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        if (isWeekend) ...[const SizedBox(width: 4), Text('休', style: const TextStyle(color: Color(0xFFFFD60A), fontSize: 11, fontWeight: FontWeight.w600))],
        if (special != null) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: const Color(0xFFFFD60A).withAlpha(25)), child: Text(special['name'] ?? '', style: const TextStyle(color: Color(0xFFFFD60A), fontSize: 10, fontWeight: FontWeight.w600)))],
        const Spacer(),
        CupertinoButton(
          onPressed: () => app.toggleSimView(),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minSize: 0,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.accent.withAlpha(30), border: Border.all(color: AppColors.accent.withAlpha(60), width: 0.5)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(CupertinoIcons.square_grid_2x2, size: 14, color: AppColors.accent),
              SizedBox(width: 4),
              Text('工具箱', style: TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => app.exitSim(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.error.withAlpha(80), width: 0.5)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(CupertinoIcons.xmark, size: 12, color: AppColors.error),
              SizedBox(width: 2),
              Text('退出', style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildToolsTopBar(AppProvider app, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0x08FFFFFF),
      child: Row(children: [
        CupertinoButton(
          onPressed: () => app.toggleSimView(),
          padding: EdgeInsets.zero,
          minSize: 0,
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(CupertinoIcons.chevron_left, size: 18, color: AppColors.accent),
            SizedBox(width: 2),
            Text('返回世界', style: TextStyle(fontSize: 14, color: AppColors.accent, fontWeight: FontWeight.w500)),
          ]),
        ),
        const Spacer(),
        Text('第${app.currentDay}天', style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        GestureDetector(
          onTap: () => app.exitSim(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.error.withAlpha(80), width: 0.5)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(CupertinoIcons.xmark, size: 12, color: AppColors.error),
              SizedBox(width: 2),
              Text('退出', style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ]),
    );
  }
}
