import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:love_sim/main.dart';
import 'package:love_sim/providers/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _corsProxyController = TextEditingController();
  bool _isInitializing = true;

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
                  _buildAppearanceSection(app),
                  const SizedBox(height: 16),
                  _buildGlobalBgSection(app),
                  const SizedBox(height: 16),
                  _buildAboutSection(),
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

  Widget _buildAppearanceSection(AppProvider app) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF64D2FF).withAlpha(30)), child: const Icon(CupertinoIcons.eye_fill, size: 16, color: Color(0xFF64D2FF))),
              const SizedBox(width: 10),
              Text('外观', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
            ],
          ),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('暗色模式', style: TextStyle(fontSize: 15, color: AppColors.textPrimaryDark)), CupertinoSwitch(value: app.isDarkMode, activeColor: AppColors.accent, onChanged: (v) => app.setDarkMode(v))]),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('字体大小', style: TextStyle(fontSize: 15, color: AppColors.textPrimaryDark)), Text(_fontSizeLabel(app.fontSizeLevel), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))]),
              const SizedBox(height: 10),
              CupertinoSlider(value: app.fontSizeLevel.toDouble(), min: 0, max: 4, divisions: 4, activeColor: AppColors.accent, onChanged: (v) => app.setFontSizeLevel(v.round())),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('A', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)), Text('A', style: TextStyle(fontSize: 14, color: AppColors.textTertiary)), Text('A', style: TextStyle(fontSize: 16, color: AppColors.textTertiary)), Text('A', style: TextStyle(fontSize: 18, color: AppColors.textTertiary)), Text('A', style: TextStyle(fontSize: 20, color: AppColors.textTertiary))]),
            ],
          ),
        ],
      ),
    );
  }

  String _fontSizeLabel(int level) { switch (level) { case 0: return '特小'; case 1: return '小'; case 2: return '标准'; case 3: return '大'; case 4: return '特大'; default: return '标准'; } }

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

  Widget _buildAboutSection() {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF64D2FF).withAlpha(30)), child: const Icon(CupertinoIcons.info, size: 16, color: Color(0xFF64D2FF))),
              const SizedBox(width: 10),
              Text('关于', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
            ],
          ),
          const SizedBox(height: 16),
          const Text('基于 DeepSeek V4 Pro 百万字上下文的 AI 恋爱模拟引擎。\n加载 .sim 格式剧本，角色卡驱动 AI 生成动态叙事。', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6)),
          const SizedBox(height: 12),
          Text('v1.0.0 · Flutter', style: TextStyle(fontSize: 12, color: AppColors.textTertiary.withAlpha(180))),
        ],
      ),
    );
  }
}
