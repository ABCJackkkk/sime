import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:love_sim/providers/app_provider.dart';
import 'package:love_sim/screens/root_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final provider = AppProvider();
  await provider.init();
  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const LoveSimApp(),
    ),
  );
}

class LoveSimApp extends StatelessWidget {
  const LoveSimApp({super.key});

  CupertinoThemeData _darkTheme(double fs) => CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF7B8CDE),
    scaffoldBackgroundColor: const Color(0xFF0A0A0C),
    barBackgroundColor: const Color(0x0AFFFFFF),
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(color: const Color(0xFFEAEAEC), fontFamily: '.SF Pro Display', fontSize: fs),
      navTitleTextStyle: TextStyle(color: const Color(0xFFEAEAEC), fontSize: 17, fontWeight: FontWeight.w600),
    ),
  );

  CupertinoThemeData _lightTheme(double fs) => CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF5B6FCE),
    scaffoldBackgroundColor: const Color(0xFFF2F2F7),
    barBackgroundColor: const Color(0xEEF2F2F7),
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(color: const Color(0xFF1C1C1E), fontFamily: '.SF Pro Display', fontSize: fs),
      navTitleTextStyle: TextStyle(color: const Color(0xFF1C1C1E), fontSize: 17, fontWeight: FontWeight.w600),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        final fs = app.baseFontSize;
        return CupertinoApp(
          title: 'Love Sim',
          theme: app.isDarkMode ? _darkTheme(fs) : _lightTheme(fs),
          home: const RootScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

extension GlassBox on Widget {
  Widget glass({double opacity = 0.04, double borderRadius = 16, EdgeInsets padding = const EdgeInsets.all(16)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Color.fromRGBO(255, 255, 255, opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: const Color(0x12FFFFFF), width: 0.5),
          ),
          child: this,
        ),
      ),
    );
  }
}

class AppColors {
  static Color background = const Color(0xFF0A0A0C);
  static const surface = Color(0x0AFFFFFF);
  static const surfaceElevated = Color(0x0FFFFFFF);
  static const accent = Color(0xFF7B8CDE);
  static const accentGlow = Color(0x1A7B8CDE);
  static const Color textPrimaryDark = Color(0xFFEAEAEC);
  static const Color textPrimaryLight = Color(0xFF1C1C1E);

  static Color textPrimary(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness;
    return brightness == Brightness.dark ? textPrimaryDark : textPrimaryLight;
  }
  static const textSecondary = Color(0xFF8E8E93);
  static const textTertiary = Color(0xFF636366);
  static const border = Color(0x12FFFFFF);
  static const borderStrong = Color(0x1FFFFFFF);
  static const success = Color(0xFF30D158);
  static const warning = Color(0xFFFF9F0A);
  static const error = Color(0xFFFF453A);
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double opacity;
  final double borderRadius;
  final EdgeInsets padding;
  final double blurSigma;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.opacity = 0.04,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
    this.blurSigma = 20,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Color.fromRGBO(255, 255, 255, opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: const Color(0x12FFFFFF), width: 0.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

class GlassNavigationBar extends StatelessWidget implements ObstructingPreferredSizeWidget {
  final Widget? leading;
  final Widget middle;
  final Widget? trailing;
  final Color backgroundColor;
  final Color borderColor;

  const GlassNavigationBar({
    super.key,
    this.leading,
    required this.middle,
    this.trailing,
    this.backgroundColor = const Color(0x0AFFFFFF),
    this.borderColor = const Color(0x12FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 44,
              child: NavigationToolbar(
                leading: leading,
                middle: DefaultTextStyle(
                  style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 17, fontWeight: FontWeight.w600),
                  child: middle,
                ),
                trailing: trailing,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  bool shouldFullyObstruct(BuildContext context) => false;
}
