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
          Widget page;
          switch (index) {
            case 0: page = const ContactsScreen(); break;
            case 1: page = const ShopScreen(); break;
            case 2: page = const SceneScreen(); break;
            case 3: page = const SimSettingsScreen(); break;
            case 4: page = const SimProfileScreen(); break;
            default: page = const ContactsScreen();
          }
          return Column(children: [
            _buildToolsTopBar(app, context),
            Expanded(child: page),
          ]);
        },
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      color: const Color(0x08FFFFFF),
      child: SafeArea(
        bottom: false,
        child: Row(children: [
          const SizedBox(width: 4),
          Text('第${weekNum}周', style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text('第${day}天', style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text(weekday, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
          if (isWeekend) ...[const SizedBox(width: 4), const Text('休', style: TextStyle(color: Color(0xFFFFD60A), fontSize: 10, fontWeight: FontWeight.w600))],
          if (special != null) ...[const SizedBox(width: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: const Color(0xFFFFD60A).withAlpha(25)), child: Text(special['name'] ?? '', style: const TextStyle(color: Color(0xFFFFD60A), fontSize: 9, fontWeight: FontWeight.w600)))],
          const Spacer(),
          CupertinoButton(
            onPressed: () => app.toggleSimView(),
            padding: EdgeInsets.zero,
            minSize: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), color: AppColors.accent.withAlpha(25), border: Border.all(color: AppColors.accent.withAlpha(50), width: 0.5)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(CupertinoIcons.square_grid_2x2, size: 11, color: AppColors.accent),
                SizedBox(width: 3),
                Text('工具箱', style: TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => app.exitSim(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: AppColors.error.withAlpha(80), width: 0.5)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(CupertinoIcons.xmark, size: 10, color: AppColors.error),
                SizedBox(width: 2),
                Text('退出', style: TextStyle(fontSize: 9, color: AppColors.error, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildToolsTopBar(AppProvider app, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: const Color(0x08FFFFFF),
      child: SafeArea(
        bottom: false,
        child: Row(children: [
          CupertinoButton(
            onPressed: () => app.toggleSimView(),
            padding: EdgeInsets.zero,
            minSize: 0,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(CupertinoIcons.chevron_left, size: 16, color: AppColors.accent),
              SizedBox(width: 2),
              Text('返回世界', style: TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w500)),
            ]),
          ),
          const Spacer(),
          Text('第${app.currentDay}天', style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: () => app.exitSim(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.error.withAlpha(80), width: 0.5)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(CupertinoIcons.xmark, size: 11, color: AppColors.error),
                SizedBox(width: 2),
                Text('退出', style: TextStyle(fontSize: 9, color: AppColors.error, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
