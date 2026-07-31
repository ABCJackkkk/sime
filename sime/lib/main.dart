import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
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

  static const CupertinoThemeData _inkTheme = CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: Color(0xFF000000),
    scaffoldBackgroundColor: Color(0xFFFEFEF7),
    barBackgroundColor: Color(0x05000000),
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(color: Color(0xFF000000), fontFamily: '.SF Pro Display', fontSize: 16),
      navTitleTextStyle: TextStyle(color: Color(0xFF000000), fontSize: 17, fontWeight: FontWeight.w600),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Sime',
      theme: _inkTheme,
      home: const RootScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ─── Inkwell 漫画风格颜色系统 ───

class AppColors {
  static const Color background = Color(0xFFFEFEF7);  // 暖白纸色
  static const Color card = Color(0xFFFFFFFF);         // 纯白卡片
  static const Color textPrimary = Color(0xFF000000);  // 墨黑
  static const Color textSecondary = Color(0xFF555555); // 深灰
  static const Color textTertiary = Color(0xFF888888);  // 中灰
  static const Color accent = Color(0xFF000000);        // 黑（强调/边框）
  static const Color accentGlow = Color(0x1A000000);
  static const Color highlight = Color(0xFFFFD700);     // 亮黄（漫画高亮）
  static const Color surface = Color(0x08000000);
  static const Color border = Color(0xFF000000);        // 粗黑边框
  static const Color borderStrong = Color(0xFF000000);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFFF8F00);
  static const Color error = Color(0xFFC62828);

  static Color textPrimaryFn(BuildContext context) => textPrimary;
  static Color textPrimaryDark = textPrimary; // 兼容旧引用

  static Color surfaceBg(BuildContext context, {double opacity = 0.04}) {
    return Color.fromRGBO(0, 0, 0, opacity);
  }

  static Color borderColor(BuildContext context, {double opacity = 0.07}) {
    return const Color(0xFF000000);
  }

  static Color cardShadow(BuildContext context) {
    return const Color(0xFF000000);
  }
}

// ─── 漫画面板（替代 GlassContainer） ───

class InkPanel extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final bool hasShadow;
  final double borderWidth;

  const InkPanel({
    super.key,
    required this.child,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.all(16),
    this.width,
    this.height,
    this.backgroundColor,
    this.hasShadow = true,
    this.borderWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.border, width: borderWidth),
        boxShadow: hasShadow
            ? [const BoxShadow(color: AppColors.accent, offset: Offset(6, 6), blurRadius: 0)]
            : null,
      ),
      child: child,
    );
  }
}

// ─── 兼容旧 GlassContainer 引用（转发到 InkPanel） ───

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double opacity;       // 忽略（旧参数）
  final double borderRadius;
  final EdgeInsets padding;
  final double blurSigma;     // 忽略（旧参数）
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
    return InkPanel(
      borderRadius: borderRadius,
      padding: padding,
      width: width,
      height: height,
      child: child,
    );
  }
}

// ─── 漫画导航栏（替代 GlassNavigationBar） ───

class InkNavBar extends StatelessWidget {
  final Widget? leading;
  final Widget middle;
  final Widget? trailing;
  final Color backgroundColor;
  final Color borderColor;

  const InkNavBar({
    super.key,
    this.leading,
    required this.middle,
    this.trailing,
    this.backgroundColor = const Color(0xFFFEFEF7),
    this.borderColor = const Color(0xFF000000),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 3)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 44,
          child: NavigationToolbar(
            leading: leading,
            middle: DefaultTextStyle(
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
              child: middle,
            ),
            trailing: trailing,
          ),
        ),
      ),
    );
  }
}

// ─── 兼容旧 GlassNavigationBar 引用（转发到 InkNavBar） ───

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
    this.backgroundColor = const Color(0xFFFEFEF7),
    this.borderColor = const Color(0xFF000000),
  });

  @override
  Widget build(BuildContext context) {
    return InkNavBar(
      leading: leading,
      middle: middle,
      trailing: trailing,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  bool shouldFullyObstruct(BuildContext context) => false;
}

// ─── 半色调网点背景（CustomPainter） ───

class HalftonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0A000000)
      ..style = PaintingStyle.fill;
    const spacing = 8.0;
    const dotRadius = 1.0;

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HalftoneBackground extends StatelessWidget {
  final Widget child;
  const HalftoneBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: HalftonePainter()),
        ),
        child,
      ],
    );
  }
}

// ─── 兼容旧 glass 扩展方法 ───

extension GlassBox on Widget {
  Widget glass({double opacity = 0.04, double borderRadius = 16, EdgeInsets padding = const EdgeInsets.all(16)}) {
    return InkPanel(
      borderRadius: borderRadius,
      padding: padding,
      child: this,
    );
  }
}