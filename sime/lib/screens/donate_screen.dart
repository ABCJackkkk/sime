import 'package:flutter/cupertino.dart';
import 'package:sime/main.dart';

class DonateScreen extends StatelessWidget {
  const DonateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('支持开发者', style: TextStyle(color: AppColors.textPrimaryDark)),
        backgroundColor: Color(0x0AFFFFFF),
        previousPageTitle: '设置',
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const SizedBox(height: 16),
            const Text('感谢你的支持 ❤️', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark)),
            const SizedBox(height: 8),
            const Text(
              '你的每一份支持都是我持续更新的动力',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/donate_wechat.png',
                width: 280,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => GlassContainer(
                  padding: const EdgeInsets.all(40),
                  child: Column(children: const [
                    Icon(CupertinoIcons.qrcode, size: 80, color: AppColors.textTertiary),
                    SizedBox(height: 12),
                    Text('收款码加载失败', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '微信扫码即可支持',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }
}
