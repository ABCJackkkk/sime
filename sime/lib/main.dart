import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sime/providers/app_provider.dart';
import 'package:sime/screens/root_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final provider = AppProvider();
  await provider.init();
  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const SimeApp(),
    ),
  );
}

class SimeApp extends StatelessWidget {
  const SimeApp({super.key});

  static const CupertinoThemeData _darkTheme = CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: Color(0xFF7B8CDE),
    scaffoldBackgroundColor: Color(0xFF0A0A0C),
    barBackgroundColor: Color(0x0AFFFFFF),
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(color: Color(0xFFEAEAEC), fontFamily: '.SF Pro Display', fontSize: 16),
      navTitleTextStyle: TextStyle(color: Color(0xFFEAEAEC), fontSize: 17, fontWeight: FontWeight.w600),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Sime',
      theme: _darkTheme,
      home: const RootScreen(),
      debugShowCheckedModeBanner: false,
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

  static Color textPrimary(BuildContext context) => textPrimaryDark;
  static const textSecondary = Color(0xFF8E8E93);
  static const textTertiary = Color(0xFF636366);
  static const border = Color(0x12FFFFFF);
  static const borderStrong = Color(0x1FFFFFFF);
  static const success = Color(0xFF30D158);
  static const warning = Color(0xFFFF9F0A);
  static const error = Color(0xFFFF453A);

  static Color surfaceBg(BuildContext context, {double opacity = 0.04}) {
    return Color.fromRGBO(255, 255, 255, opacity);
  }

  static Color borderColor(BuildContext context, {double opacity = 0.07}) {
    return const Color(0x12FFFFFF);
  }

  static Color cardShadow(BuildContext context) {
    return const Color(0x00000000);
  }
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
