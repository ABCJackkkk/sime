import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:love_sim/main.dart';
import 'package:love_sim/providers/app_provider.dart';
import 'package:love_sim/widgets/crop_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _bioController = TextEditingController();
  final _appearanceController = TextEditingController();
  final _personalityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppProvider>();
      _nameController.text = app.userName;
      _heightController.text = app.userHeight;
      _birthdayController.text = app.userBirthday;
      _bioController.text = app.userBio;
      _appearanceController.text = app.userAppearance;
      _personalityController.text = app.userPersonality;
    });
  }

  @override
  void dispose() {
    _nameController.dispose(); _heightController.dispose(); _birthdayController.dispose();
    _bioController.dispose(); _appearanceController.dispose(); _personalityController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) return;
      Uint8List? bytes = result.files.first.bytes;
      if (bytes == null) return;
      if (!mounted) return;
      final cropped = await Navigator.of(context).push<Uint8List>(
        CupertinoPageRoute(fullscreenDialog: true, builder: (_) => CropScreen(imageBytes: bytes, aspectRatio: 1.0)),
      );
      if (cropped != null && mounted) {
        context.read<AppProvider>().setUserImageBytes(cropped);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Consumer<AppProvider>(
          builder: (context, app, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 12),
                Text('我的', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context), letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text('设置你的身份信息', style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withAlpha(200))),
                const SizedBox(height: 28),
                _buildAvatarSection(app),
                const SizedBox(height: 20),
                _buildInfoSection(app),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatarSection(AppProvider app) {
    return GlassContainer(padding: const EdgeInsets.all(20),
      child: Column(children: [
        GestureDetector(
          onTap: _pickAvatar,
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: AppColors.accent.withAlpha(30), boxShadow: [BoxShadow(color: AppColors.accent.withAlpha(40), blurRadius: 20, offset: const Offset(0, 8))]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: app.userImageBytes != null
                  ? Image.memory(app.userImageBytes!, width: 80, height: 80, fit: BoxFit.cover)
                  : Center(child: Text(app.userName.isNotEmpty ? app.userName.characters.first : '?', style: const TextStyle(color: AppColors.accent, fontSize: 32, fontWeight: FontWeight.w700))),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('点击更换头像', style: TextStyle(fontSize: 11, color: AppColors.textTertiary.withAlpha(160))),
        const SizedBox(height: 12),
        Text(app.userName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
      ]),
    );
  }

  Widget _buildInfoSection(AppProvider app) {
    return GlassContainer(padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionHeader(CupertinoIcons.person_fill, '基础信息', AppColors.accent),
        const SizedBox(height: 16),
        _buildField('昵称', _nameController, '输入你的名字...', (v) => app.setUserName(v)),
        const SizedBox(height: 12),
        _buildField('身高', _heightController, '如: 175cm', (v) => app.setUserHeight(v)),
        const SizedBox(height: 12),
        _buildField('生日', _birthdayController, '如: 3月21日', (v) => app.setUserBirthday(v)),
        const SizedBox(height: 14),
        Row(children: [
          const SizedBox(width: 50, child: Text('性别', style: TextStyle(fontSize: 14, color: AppColors.textSecondary))),
          const SizedBox(width: 12),
          Expanded(child: CupertinoSegmentedControl<String>(selectedColor: AppColors.accent, unselectedColor: const Color(0x0AFFFFFF), borderColor: AppColors.border, pressedColor: AppColors.accent.withAlpha(60), groupValue: app.userGender, onValueChanged: (v) => app.setUserGender(v), children: const {'男': Text('男', style: TextStyle(fontSize: 13)), '女': Text('女', style: TextStyle(fontSize: 13)), '其他': Text('其他', style: TextStyle(fontSize: 13))})),
        ]),
        const SizedBox(height: 16),
        _buildSectionHeader(CupertinoIcons.person_2_fill, '角色形象', const Color(0xFFFF9500)),
        const SizedBox(height: 12),
        SizedBox(height: 70, child: CupertinoTextField(controller: _appearanceController, placeholder: '描述你的外貌特征: 身高、发型、穿着风格...', placeholderStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13), padding: const EdgeInsets.all(14), maxLines: 2, decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)), style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14), onChanged: (v) => app.setUserAppearance(v))),
        const SizedBox(height: 12),
        SizedBox(height: 70, child: CupertinoTextField(controller: _personalityController, placeholder: '描述你的性格特点: 沉默寡言、开朗外向...', placeholderStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13), padding: const EdgeInsets.all(14), maxLines: 2, decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)), style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14), onChanged: (v) => app.setUserPersonality(v))),
        const SizedBox(height: 20),
        _buildSectionHeader(CupertinoIcons.text_justify, '个人简介', const Color(0xFF64D2FF)),
        const SizedBox(height: 12),
        SizedBox(height: 80, child: CupertinoTextField(controller: _bioController, placeholder: '介绍一下自己...', placeholderStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14), padding: const EdgeInsets.all(14), maxLines: 3, decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)), style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14), onChanged: (v) => app.setUserBio(v))),
      ]),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(children: [
      Container(width: 28, height: 28, decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), color: color.withAlpha(30)), child: Icon(icon, size: 14, color: color)),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark)),
    ]);
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, Function(String) onChange) {
    return Row(children: [
      SizedBox(width: 50, child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary))),
      const SizedBox(width: 12),
      Expanded(child: SizedBox(height: 40, child: CupertinoTextField(controller: ctrl, placeholder: hint, placeholderStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13), padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border, width: 0.5)), style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14), onChanged: onChange))),
    ]);
  }
}
