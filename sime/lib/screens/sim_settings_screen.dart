import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sime/main.dart';
import 'package:sime/providers/app_provider.dart';
import 'package:sime/screens/crop_screen.dart';
import 'package:sime/screens/announcement_screen.dart';
import 'package:sime/screens/donate_screen.dart';

class SimSettingsScreen extends StatefulWidget {
  const SimSettingsScreen({super.key});
  @override
  State<SimSettingsScreen> createState() => _SimSettingsScreenState();
}

class _SimSettingsScreenState extends State<SimSettingsScreen> {
  bool _checkingUpdate = false;
  String? _updateStatus;

  Future<void> _pickBgImage(AppProvider app) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;
      Uint8List? bytes = result.files.first.bytes;
      if (bytes == null) {
        final path = result.files.first.path;
        if (path != null && path.isNotEmpty) {
          bytes = await File(path).readAsBytes();
        }
      }
      if (bytes == null) return;
      final safeBytes = bytes;
      final cropped = await Navigator.of(context).push<Uint8List>(
        CupertinoPageRoute(fullscreenDialog: true, builder: (_) => CropScreen(imageBytes: safeBytes, aspectRatio: 9/16)),
      );
      if (cropped != null) {
        app.setSimBgType('image');
        app.setSimBgImageBytes(cropped);
      }
    } catch (_) {}
  }

  Future<void> _checkUpdate(AppProvider app) async {
    setState(() {
      _checkingUpdate = true;
      _updateStatus = null;
    });

    final info = await app.checkUpdate(force: true);

    if (!mounted) return;

    setState(() {
      _checkingUpdate = false;
    });

    if (info == null) {
      setState(() {
        _updateStatus = '检查失败，请稍后再试';
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _updateStatus = null);
      });
      return;
    }

    if (app.updateService.hasNewVersion(info)) {
      _showUpdateDialog(app, info);
    } else {
      setState(() {
        _updateStatus = '已是最新版本 v${app.updateService.currentVersion}';
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _updateStatus = null);
      });
    }
  }

  void _showUpdateDialog(AppProvider app, dynamic info) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('v${info.latestVersion}'),
            const SizedBox(height: 8),
            if (info.changelog != null && info.changelog.isNotEmpty)
              Text(info.changelog, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Consumer<AppProvider>(
          builder: (ctx, app, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const Text('模拟设置', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  const Text('仅影响当前模拟界面', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  _buildImageUpload(app),
                  const SizedBox(height: 16),
                  _buildAboutSection(app),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildImageUpload(AppProvider app) {
    return GlassContainer(padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.warning.withAlpha(25)), child: const Icon(CupertinoIcons.camera_fill, size: 16, color: AppColors.warning)),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('自定义背景图', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Text('从相册选择图片作为模拟背景', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
        ]),
        const SizedBox(height: 14),
        if (app.simBgImageBytes != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(height: 120, width: double.infinity, child: Image.memory(app.simBgImageBytes!, fit: BoxFit.cover)),
            ),
          ),
        CupertinoButton(
          onPressed: () => _pickBgImage(app),
          padding: const EdgeInsets.symmetric(vertical: 12),
          borderRadius: BorderRadius.circular(12),
          color: AppColors.accent.withAlpha(30),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(CupertinoIcons.photo, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(app.simBgImageBytes != null ? '更换背景图' : '选择背景图', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.accent)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAboutSection(AppProvider app) {
    return GlassContainer(padding: const EdgeInsets.all(4),
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
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: subtitleColor ?? AppColors.textSecondary)),
            ],
          ])),
          if (trailing != null)
            trailing
          else if (showChevron && onTap != null)
            const Icon(CupertinoIcons.chevron_right, size: 14, color: AppColors.textTertiary),
        ]),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(margin: const EdgeInsets.only(left: 60), height: 0.5, color: AppColors.border);
  }
}
