import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:love_sim/main.dart';
import 'package:love_sim/models/script.dart';
import 'package:love_sim/providers/app_provider.dart';
import 'package:love_sim/screens/chat_screen.dart';
import 'package:love_sim/widgets/crop_screen.dart';

class CharacterProfileScreen extends StatefulWidget {
  final String characterId;
  const CharacterProfileScreen({super.key, required this.characterId});
  @override
  State<CharacterProfileScreen> createState() => _CharacterProfileScreenState();
}

class _CharacterProfileScreenState extends State<CharacterProfileScreen> {
  final _remarkCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppProvider>();
      _remarkCtrl.text = app.getCharRemarkName(widget.characterId);
    });
  }

  @override
  void dispose() { _remarkCtrl.dispose(); super.dispose(); }

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
        context.read<AppProvider>().setCharImageBytes(widget.characterId, cropped);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        final char = app.getCharacter(widget.characterId);
        if (char == null) return const SizedBox.shrink();

        final affection = app.getAffection(widget.characterId);
        final displayName = app.getCharDisplayName(widget.characterId);
        final charImg = app.getCharImageBytes(widget.characterId);

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background,
          navigationBar: CupertinoNavigationBar(
            backgroundColor: AppColors.background,
            border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
            middle: Text(char.basic.name, style: const TextStyle(color: AppColors.textPrimaryDark)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(children: [
                _buildHeader(app, char, displayName, charImg),
                _buildAffectionSection(affection),
                _buildRemarkSection(),
                _buildInfoSection(char),
                _buildBioSection(char),
                _buildChatButton(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(AppProvider app, Character char, String displayName, Uint8List? charImg) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1A1A2E), Color(0xFF0A0A0C)])),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(children: [
        GestureDetector(
          onTap: _pickAvatar,
          child: Container(
            width: 96, height: 96,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), color: AppColors.accent.withAlpha(40), boxShadow: [BoxShadow(color: AppColors.accent.withAlpha(40), blurRadius: 20, offset: const Offset(0, 8))]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: charImg != null
                  ? Image.memory(charImg, width: 96, height: 96, fit: BoxFit.cover)
                  : Center(child: Text(displayName.isNotEmpty ? displayName.characters.first : '?', style: const TextStyle(color: AppColors.accent, fontSize: 40, fontWeight: FontWeight.w700))),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('点击更换头像', style: TextStyle(fontSize: 11, color: AppColors.textTertiary.withAlpha(160))),
        const SizedBox(height: 12),
        Text(displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark)),
        if (displayName != char.basic.name)
          Text(char.basic.name, style: const TextStyle(fontSize: 14, color: AppColors.textTertiary)),
      ]),
    );
  }

  Widget _buildAffectionSection(double affection) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: GlassContainer(padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Icon(CupertinoIcons.heart_fill, size: 18, color: AppColors.error),
          const SizedBox(width: 10),
          const Text('好感度', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimaryDark)),
          const Spacer(),
          Text('${affection.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.accent, fontFamily: 'SF Mono')),
          const SizedBox(width: 4),
          const Text('/ 100.00', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
        ]),
      ),
    );
  }

  Widget _buildRemarkSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassContainer(padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Icon(CupertinoIcons.tag, size: 15, color: AppColors.textTertiary),
          const SizedBox(width: 10),
          const Text('备注', style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
          const SizedBox(width: 10),
          Expanded(
            child: CupertinoTextField(
              controller: _remarkCtrl,
              placeholder: '设置备注名...',
              placeholderStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
              padding: EdgeInsets.zero,
              decoration: const BoxDecoration(),
              style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 15),
              onChanged: (v) => context.read<AppProvider>().setCharRemarkName(widget.characterId, v),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildInfoSection(Character char) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12),
      child: GlassContainer(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), color: AppColors.accent.withAlpha(30)), child: const Icon(CupertinoIcons.person, size: 14, color: AppColors.accent)),
            const SizedBox(width: 10),
            const Text('基础信息', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark)),
          ]),
          const SizedBox(height: 14),
          _infoRow('姓名', char.basic.name),
          if (char.basic.age != 0) _infoRow('年龄', '${char.basic.age}岁'),
          if (char.basic.height != 0) _infoRow('身高', '${char.basic.height}cm'),
          _infoRow('性别', char.basic.gender),
        ]),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 50, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textTertiary))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimaryDark))),
      ]),
    );
  }

  Widget _buildBioSection(Character char) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12),
      child: GlassContainer(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), color: AppColors.accent.withAlpha(30)), child: const Icon(CupertinoIcons.text_justify, size: 14, color: AppColors.accent)),
            const SizedBox(width: 10),
            const Text('角色简介', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark)),
          ]),
          if (char.summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(char.summary, style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withAlpha(200), height: 1.6)),
          ],
          if (char.basic.distinctiveMarks.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: char.basic.distinctiveMarks.map((mark) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.accent.withAlpha(20), border: Border.all(color: AppColors.accent.withAlpha(50), width: 0.5)),
                child: Text(mark, style: const TextStyle(fontSize: 12, color: AppColors.accent)),
              )).toList(),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildChatButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: CupertinoButton(
        onPressed: () { Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ChatScreen(characterId: widget.characterId))); },
        padding: const EdgeInsets.symmetric(vertical: 16),
        borderRadius: BorderRadius.circular(16),
        color: AppColors.accent,
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(CupertinoIcons.chat_bubble_2_fill, size: 18, color: CupertinoColors.white),
          SizedBox(width: 8),
          Text('发送消息', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: CupertinoColors.white)),
        ]),
      ),
    );
  }
}
