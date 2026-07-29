import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sime/main.dart';
import 'package:sime/providers/app_provider.dart';
import 'package:sime/screens/script_creator_screen.dart';

class ScriptsScreen extends StatefulWidget {
  const ScriptsScreen({super.key});

  @override
  State<ScriptsScreen> createState() => _ScriptsScreenState();
}

class _ScriptsScreenState extends State<ScriptsScreen> {
  bool _isLoading = false;
  final _nameCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _birthdayCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppProvider>();
      _nameCtrl.text = app.userName;
      _heightCtrl.text = app.userHeight;
      _birthdayCtrl.text = app.userBirthday;
    });
  }

  @override
  void dispose() { _nameCtrl.dispose(); _heightCtrl.dispose(); _birthdayCtrl.dispose(); super.dispose(); }

  Future<void> _pickScriptFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = File(file.path!).readAsBytesSync();
      }
      if (bytes == null) return;
      final jsonString = utf8.decode(bytes);
      final app = context.read<AppProvider>();
      await app.loadScriptFromJsonString(jsonString);
    } catch (e) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('导入失败'),
          content: Text('请检查文件是否为有效的 .json 格式：$e'),
          actions: [CupertinoDialogAction(child: const Text('确定'), onPressed: () => Navigator.pop(context))],
        ),
      );
    }
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Text('剧本管理', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context), letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Text('加载 .json 格式剧本包', style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withAlpha(200))),
                  const SizedBox(height: 28),
                  _buildProtagonistSection(app),
                  const SizedBox(height: 16),
                  _buildCurrentScript(app),
                  const SizedBox(height: 16),
                  _buildImportSection(),
                  const SizedBox(height: 16),
                  _buildScriptLibrary(app),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProtagonistSection(AppProvider app) {
    return GlassContainer(padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.warning.withAlpha(25)), child: const Icon(CupertinoIcons.person_fill, size: 16, color: AppColors.warning)),
          const SizedBox(width: 10),
          Text('主角设定', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
          const Spacer(),
          Text('会写入模拟上下文', style: TextStyle(fontSize: 11, color: AppColors.textTertiary.withAlpha(180))),
        ]),
        const SizedBox(height: 16),
        _fieldRow('名字', _nameCtrl, '主角名', (v) => app.setUserName(v)),
        const SizedBox(height: 10),
        Row(children: [
          const SizedBox(width: 56, child: Text('性别', style: TextStyle(fontSize: 14, color: AppColors.textSecondary))),
          const SizedBox(width: 10),
          Expanded(child: CupertinoSegmentedControl<String>(selectedColor: AppColors.accent, unselectedColor: const Color(0x0AFFFFFF), borderColor: AppColors.border, pressedColor: AppColors.accent.withAlpha(60), groupValue: app.userGender, onValueChanged: (v) => app.setUserGender(v), children: const {'男': Text('男', style: TextStyle(fontSize: 13)), '女': Text('女', style: TextStyle(fontSize: 13))})),
        ]),
        const SizedBox(height: 10),
        _fieldRow('身高', _heightCtrl, '如: 175cm', (v) => app.setUserHeight(v)),
        const SizedBox(height: 10),
        _fieldRow('生日', _birthdayCtrl, '如: 3月21日', (v) => app.setUserBirthday(v)),
      ]),
    );
  }

  Widget _fieldRow(String label, TextEditingController ctrl, String hint, Function(String) onChange) {
    return Row(children: [
      SizedBox(width: 56, child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary))),
      const SizedBox(width: 10),
      Expanded(child: SizedBox(height: 40, child: CupertinoTextField(controller: ctrl, placeholder: hint, placeholderStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13), padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border, width: 0.5)), style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14), onChanged: onChange))),
    ]);
  }

  Widget _buildCurrentScript(AppProvider app) {
    return GlassContainer(padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: app.hasScript ? AppColors.success.withAlpha(30) : AppColors.textTertiary.withAlpha(30)), child: Icon(app.hasScript ? CupertinoIcons.book_fill : CupertinoIcons.book, size: 16, color: app.hasScript ? AppColors.success : AppColors.textTertiary)),
          const SizedBox(width: 10),
          Text('当前剧本', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
        ]),
        const SizedBox(height: 16),
        if (app.hasScript && app.script != null) ...[
          Text(app.script!.meta.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
          const SizedBox(height: 6),
          Text('${app.script!.meta.genre} · ${app.script!.meta.author}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('${app.script!.characters.where((c) => c.fullCharacter).length} 个可攻略角色', style: TextStyle(fontSize: 12, color: AppColors.textTertiary.withAlpha(200))),
        ] else
          Text('尚未加载任何剧本', style: TextStyle(fontSize: 14, color: AppColors.textTertiary.withAlpha(180))),
      ]),
    );
  }

  Widget _buildImportSection() {
    return GlassContainer(padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.accent.withAlpha(30)), child: const Icon(CupertinoIcons.square_arrow_down_fill, size: 16, color: AppColors.accent)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('导入剧本', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))), const Text('从本地文件加载 .json 剧本', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))])),
        ]),
        const SizedBox(height: 16),
        CupertinoButton(
          onPressed: _pickScriptFile,
          padding: const EdgeInsets.symmetric(vertical: 14),
          borderRadius: BorderRadius.circular(14),
          color: AppColors.accent,
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(CupertinoIcons.doc_fill, size: 18, color: CupertinoColors.white),
            SizedBox(width: 8),
            Text('选择 .json 文件', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CupertinoColors.white)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildScriptLibrary(AppProvider app) {
    return GlassContainer(padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.accent.withAlpha(30)), child: const Icon(CupertinoIcons.square_stack_3d_up_fill, size: 16, color: AppColors.accent)),
          const SizedBox(width: 10),
          Expanded(child: Text('剧本库', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)))),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            onPressed: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ScriptCreatorScreen())),
            borderRadius: BorderRadius.circular(8),
            color: AppColors.accent,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(CupertinoIcons.add_circled, size: 15, color: CupertinoColors.white),
              SizedBox(width: 4),
              Text('创作', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CupertinoColors.white)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        _buildScriptCard(
          name: '十七岁的坐标系', genre: '校园成长',
          desc: '高一下到高考结束，两个转校生、两个青梅竹马——四个人，两年半，一个关于没说完的话和终将告别的故事。',
          characters: 4, days: 1065, endings: 5,
          isActive: app.hasScript && app.script?.meta.id == 'campus_love',
          isLoading: _isLoading,
          onTap: () => _loadCampusScript(app),
        ),
        _buildScriptCard(
          name: '被拉黑后，千金大小姐疯了', genre: '现代都市',
          desc: '追了两年半的富家千金，终于等到她妈拿五百万来赶人。收钱拉黑跑路——然后她疯了。',
          characters: 6, days: 90, endings: 5,
          isActive: app.hasScript && app.script?.meta.id == 'blacklist_heiress',
          isLoading: _isLoading,
          onTap: () => _loadHeiressScript(app),
        ),
        if (app.customScripts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('已导入剧本', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary.withAlpha(200))),
          const SizedBox(height: 8),
          ...List.generate(app.customScripts.length, (i) {
            final s = app.customScripts[i];
            final name = (s['name'] ?? '未命名').toString();
            final isActive = app.hasScript && app.script?.meta.name == name;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildImportedScriptCard(app: app, index: i, name: name, isActive: isActive, isLoading: _isLoading),
            );
          }),
        ],
      ]),
    );
  }

  Widget _buildImportedScriptCard({required AppProvider app, required int index, required String name, required bool isActive, required bool isLoading}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: isActive ? AppColors.accent.withAlpha(15) : const Color(0x08FFFFFF), border: Border.all(color: isActive ? AppColors.accent.withAlpha(60) : AppColors.border, width: 0.5)),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.accent.withAlpha(25)), child: const Icon(CupertinoIcons.doc_text, size: 18, color: AppColors.accent)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)), overflow: TextOverflow.ellipsis, maxLines: 1)),
            const SizedBox(width: 4),
            if (isActive) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: AppColors.success.withAlpha(25)), child: const Text('已加载', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 2),
          Text('自定义导入剧本', style: TextStyle(fontSize: 11, color: AppColors.textTertiary.withAlpha(180)), overflow: TextOverflow.ellipsis, maxLines: 1),
        ])),
        const SizedBox(width: 6),
        CupertinoButton(onPressed: isLoading ? null : () => app.loadCustomScript(index), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minSize: 0, borderRadius: BorderRadius.circular(6), color: isActive ? null : AppColors.accent.withAlpha(80), child: Text(isActive ? '运行中' : '加载', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? AppColors.textTertiary : CupertinoColors.white))),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _confirmDeleteScript(app, index, name),
          child: Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.error.withAlpha(20)), child: const Icon(CupertinoIcons.trash, size: 16, color: AppColors.error)),
        ),
      ]),
    );
  }

  void _confirmDeleteScript(AppProvider app, int index, String name) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('删除剧本'),
        content: Text('确定要删除「$name」吗？此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(child: const Text('取消'), onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () { app.removeCustomScript(index); Navigator.pop(context); }, child: const Text('删除')),
        ],
      ),
    );
  }

  Widget _buildScriptCard({required String name, required String genre, required String desc, required int characters, required int days, required int endings, required bool isActive, required bool isLoading, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: isActive ? AppColors.accent.withAlpha(15) : const Color(0x08FFFFFF), border: Border.all(color: isActive ? AppColors.accent.withAlpha(60) : AppColors.border, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.accent, Color(0xFF64D2FF)])), child: const Icon(CupertinoIcons.heart, size: 22, color: CupertinoColors.white)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)), overflow: TextOverflow.ellipsis, maxLines: 1)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: AppColors.accent.withAlpha(30)), child: Text(genre, style: const TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w600)))]),
              const SizedBox(height: 4),
              Text('$characters 个可攻略角色 · $days 天剧情 · $endings 个结局', style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            ])),
          ]),
          const SizedBox(height: 12),
          Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(children: [
            if (isActive) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: AppColors.success.withAlpha(25)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(CupertinoIcons.checkmark_alt, size: 12, color: AppColors.success), SizedBox(width: 4), Text('已加载', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600))])),
            const Spacer(),
            if (isLoading) const CupertinoActivityIndicator(radius: 8) else CupertinoButton(onPressed: isActive ? null : onTap, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), minSize: 0, borderRadius: BorderRadius.circular(8), color: isActive ? null : AppColors.accent, child: Text(isActive ? '运行中' : '加载', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? AppColors.textTertiary : CupertinoColors.white))),
          ]),
        ]),
      ),
    );
  }

  Future<void> _loadCampusScript(AppProvider app) async {
    setState(() => _isLoading = true);
    final error = await app.loadScript('assets/scripts/campus_love.json');
    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('加载失败'),
            content: Text(error),
            actions: [CupertinoDialogAction(child: const Text('确定'), onPressed: () => Navigator.pop(context))],
          ),
        );
      }
    }
  }

  Future<void> _loadHeiressScript(AppProvider app) async {
    setState(() => _isLoading = true);
    final error = await app.loadScript('assets/scripts/blacklist_heiress.json');
    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('加载失败'),
            content: Text(error),
            actions: [CupertinoDialogAction(child: const Text('确定'), onPressed: () => Navigator.pop(context))],
          ),
        );
      }
    }
  }
}
