import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:love_sim/main.dart';
import 'package:love_sim/providers/app_provider.dart';

class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key});

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  bool _loading = true;
  String? _qrUrl;
  String? _tip;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final app = context.read<AppProvider>();
    try {
      final info = await app.checkUpdate();
      if (!mounted) return;
      setState(() {
        _qrUrl = info?.donateQrUrl;
        _tip = info?.donateTip;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('支持开发者', style: TextStyle(color: AppColors.textPrimaryDark)),
        backgroundColor: const Color(0x0AFFFFFF),
        previousPageTitle: '设置',
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF64D2FF)]),
                      boxShadow: [BoxShadow(color: AppColors.accent.withAlpha(40), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: const Icon(CupertinoIcons.heart_fill, size: 28, color: CupertinoColors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text('感谢你的支持', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark)),
                  const SizedBox(height: 8),
                  Text(
                    _tip ?? '你的支持是我持续更新的动力 ❤️',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  if (_qrUrl != null && _qrUrl!.isNotEmpty)
                    GlassContainer(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _qrUrl!,
                            width: 200, height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 200, height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: AppColors.border.withAlpha(50),
                              ),
                              child: const Center(child: Icon(CupertinoIcons.qrcode, size: 60, color: AppColors.textTertiary)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('扫码支持', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ]),
                    )
                  else
                    GlassContainer(
                      padding: const EdgeInsets.all(30),
                      child: Column(children: const [
                        Icon(CupertinoIcons.qrcode, size: 60, color: AppColors.textTertiary),
                        SizedBox(height: 12),
                        Text('暂未开启打赏功能', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      ]),
                    ),
                  const SizedBox(height: 40),
                ]),
              ),
      ),
    );
  }
}
