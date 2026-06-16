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
        return SafeArea(top: false, bottom: false, child: app.simInWorldView ? _buildWorldView(app, context) : _buildToolsView(app, context));
      },
    );
  }

  Widget _buildWorldView(AppProvider app, BuildContext context) {
    final simBg = app.simBgImageBytes;
    return Container(
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0x08FFFFFF),
      child: Row(children: [
        const SizedBox(width: 4),
        Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF32D74B))),
        const SizedBox(width: 8),
        Text('第${app.currentDay}天', style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        Text(app.currentPhase.replaceAll('上午', '☀️').replaceAll('下午', '🌤').replaceAll('晚上', '🌙').replaceAll('深夜', '🌃'), style: const TextStyle(fontSize: 13)),
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
