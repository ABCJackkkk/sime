import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sime/main.dart';
import 'package:sime/providers/app_provider.dart';
import 'package:sime/screens/announcement_screen.dart';
import 'package:sime/screens/donate_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _corsProxyController = TextEditingController();
  final TextEditingController _updateUrlController = TextEditingController();
  bool _isInitializing = true;
  bool _checkingUpdate = false;
  String? _updateStatus;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('api_key') ?? '';
    _apiKeyController.text = savedKey;
    _corsProxyController.text = prefs.getString('cors_proxy') ?? '';
    _updateUrlController.text = prefs.getString('update_config_url') ?? '';
    if (savedKey.isNotEmpty) {
      context.read<AppProvider>().setApiKey(savedKey);
    }
    setState(() => _isInitializing = false);
  }

  Future<void> _saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', key);
  }

  Future<void> _saveCorsProxy(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cors_proxy', url);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _corsProxyController.dispose();
    _updateUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Container(color: CupertinoTheme.of(context).scaffoldBackgroundColor, child: const Center(child: CupertinoActivityIndicator()));
    }

    return Container(
      color: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Consumer<AppProvider>(
          builder: (context, app, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Text('设置', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context), letterSpacing: -0.5)),
                  const SizedBox(height: 28),
                  _buildApiSection(app),
                  const SizedBox(height: 16),
                  _buildGlobalBgSection(app),
                  const SizedBox(height: 16),
                  _buildUpdateSection(app),
                  const SizedBox(height: 16),
                  _buildAboutSection(app),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildApiSection(AppProvider app) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.accent.withAlpha(30)), child: const Icon(CupertinoIcons.lock_fill, size: 16, color: AppColors.accent)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('DeepSeek API', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))), Text('连接 AI 引擎', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))])),
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: app.apiKey.isNotEmpty ? AppColors.success : AppColors.textTertiary, boxShadow: app.apiKey.isNotEmpty ? [BoxShadow(color: AppColors.success.withAlpha(80), blurRadius: 6)] : null)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(height: 44, child: CupertinoTextField(controller: _apiKeyController, placeholder: 'sk-...', placeholderStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14), padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)), style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 14, fontFamily: 'SF Mono'), obscureText: true, onChanged: (value) { app.setApiKey(value.trim()); _saveApiKey(value.trim()); })),
          const SizedBox(height: 10),
          SizedBox(height: 44, child: CupertinoTextField(controller: _corsProxyController, placeholder: 'CORS 代理 URL（Web 端必填，如 https://corsproxy.io/?）', placeholderStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12), padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)), style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13, fontFamily: 'SF Mono'), onChanged: (value) { app.setCorsProxy(value.trim()); _saveCorsProxy(value.trim()); })),
        ],
      ),
    );
  }

  Widget _buildGlobalBgSection(AppProvider app) {
    final bgPresets = {
      'default': const ['0A0A0C', '0D0D15'],
      'midnight': const ['0C0C1D', '1A1A2E'],
      'sunset': const ['2D132C', '1B1B3A'],
      'forest': const ['0F2027', '203A43'],
      'ocean': const ['0F2027', '2C5364'],
      'mono': const ['000000', '000000'],
      'light': const ['E8E8ED', 'F2F2F7'],
    };
    final bgNames = {'default': '默认暗色', 'midnight': '午夜蓝', 'sunset': '暮光紫', 'forest': '深林绿', 'ocean': '海洋蓝', 'mono': '纯黑', 'light': '浅灰'};

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.warning.withAlpha(25)), child: const Icon(CupertinoIcons.photo_fill_on_rectangle_fill, size: 16, color: AppColors.warning)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('全局背景', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))), Text('影响主界面', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))])),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12,
            children: bgPresets.entries.map((e) {
              final selected = app.globalBgType == e.key;
              final start = Color(int.parse('0xFF${e.value[0]}'));
              final end = Color(int.parse('0xFF${e.value[1]}'));
              return GestureDetector(
                onTap: () { app.setGlobalBgType(e.key); app.setGlobalBgColor1(e.value[0]); app.setGlobalBgColor2(e.value[1]); },
                child: Column(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [start, end]), border: selected ? Border.all(color: AppColors.accent, width: 2.5) : Border.all(color: AppColors.border, width: 0.5), boxShadow: selected ? [BoxShadow(color: AppColors.accent.withAlpha(50), blurRadius: 8)] : null),
                      child: selected ? const Icon(CupertinoIcons.checkmark_alt, color: CupertinoColors.white, size: 20) : null,
                    ),
                    const SizedBox(height: 6),
                    Text(bgNames[e.key] ?? e.key, style: TextStyle(fontSize: 11, color: selected ? AppColors.accent : AppColors.textTertiary, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateSection(AppProvider app) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF30D158).withAlpha(30)), child: const Icon(CupertinoIcons.down_arrow, size: 16, color: Color(0xFF30D158))),
              const SizedBox(width: 10),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('自动更新', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark)), Text('配置更新服务器地址', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))])),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(height: 44, child: CupertinoTextField(
            controller: _updateUrlController,
            placeholder: '更新配置 JSON 地址（如 Gitee/GitHub Raw 链接）',
            placeholderStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)),
            style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13, fontFamily: 'SF Mono'),
            onChanged: (value) { app.setUpdateConfigUrl(value.trim()); },
          )),
          const SizedBox(height: 10),
          const Text('提示：将版本信息 JSON 上传到 Gitee/GitHub 等平台，填入 Raw 链接即可启用自动更新、公告和打赏功能。', style: TextStyle(fontSize: 11, color: AppColors.textTertiary, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildAboutSection(AppProvider app) {
    return GlassContainer(
      padding: const EdgeInsets.all(4),
      child: Column(children: [
        _buildSettingRow(
          icon: CupertinoIcons.news,
          iconColor: AppColors.accent,
          title: '公告',
          subtitle: '查看最新消息',
          onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const AnnouncementScreen())),
        ),
        _buildDivider(),
        _buildSettingRow(
          icon: CupertinoIcons.down_arrow,
          iconColor: const Color(0xFF30D158),
          title: '检查更新',
          subtitle: _updateStatus ?? '当前版本 v${app.updateService.currentVersion}',
          subtitleColor: _updateStatus != null ? AppColors.accent : null,
          onTap: _checkingUpdate ? null : () => _checkUpdate(app),
          trailing: _checkingUpdate
              ? const CupertinoActivityIndicator(radius: 10)
              : const Icon(CupertinoIcons.chevron_right, size: 14, color: AppColors.textTertiary),
        ),
        _buildDivider(),
        _buildSettingRow(
          icon: CupertinoIcons.heart_fill,
          iconColor: const Color(0xFFFF453A),
          title: '支持开发者',
          subtitle: '请我喝杯奶茶吧~',
          onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const DonateScreen())),
        ),
        _buildDivider(),
        _buildSettingRow(
          icon: CupertinoIcons.info_circle,
          iconColor: AppColors.textTertiary,
          title: '关于',
          subtitle: 'v${app.updateService.currentVersion} (build ${app.updateService.currentBuildNumber})',
          onTap: null,
          showChevron: false,
        ),
      ]),
    );
  }

  Future<void> _checkUpdate(AppProvider app) async {
    setState(() {
      _checkingUpdate = true;
      _updateStatus = null;
    });
    final info = await app.checkUpdate(force: true);
    if (!mounted) return;
    setState(() { _checkingUpdate = false; });
    if (info == null) {
      setState(() { _updateStatus = '检查失败，请稍后再试'; });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _updateStatus = null);
      });
      return;
    }
    if (info.hasUpdate) {
      setState(() { _updateStatus = '发现新版本 v${info.latestVersion}'; });
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('发现新版本'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('v${info.latestVersion}'),
              const SizedBox(height: 8),
              if (info.changelog != null && info.changelog!.isNotEmpty)
                Text(info.changelog!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
    } else {
      setState(() { _updateStatus = '已是最新版本'; });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _updateStatus = null);
      });
    }
  }

  Widget _buildSettingRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? subtitleColor,
    VoidCallback? onTap,
    Widget? trailing,
    bool showChevron = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: iconColor.withAlpha(25)), child: Icon(icon, size: 16, color: iconColor)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary(context))),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: subtitleColor ?? AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing
          else if (showChevron)
            const Icon(CupertinoIcons.chevron_right, size: 14, color: AppColors.textTertiary),
        ]),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 60),
      color: AppColors.border,
    );
  }
}
