import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:sime/main.dart';
import 'package:sime/providers/app_provider.dart';

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  bool _loading = true;
  String? _title;
  String? _content;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnnouncement();
  }

  Future<void> _loadAnnouncement() async {
    final app = context.read<AppProvider>();
    try {
      final info = await app.checkUpdate();
      if (!mounted) return;
      if (info != null && (info.announcement != null || info.announcementTitle != null)) {
        setState(() {
          _title = info.announcementTitle ?? '公告';
          _content = info.announcement;
          _loading = false;
        });
      } else {
        setState(() {
          _title = '公告';
          _content = '暂无公告';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败，请检查网络连接';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_title ?? '公告', style: const TextStyle(color: AppColors.textPrimary)),
        backgroundColor: const Color(0x05000000),
        previousPageTitle: '设置',
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(CupertinoIcons.wifi_exclamationmark, size: 40, color: AppColors.textTertiary),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    const SizedBox(height: 16),
                    CupertinoButton(
                      onPressed: () { setState(() { _loading = true; _error = null; }); _loadAnnouncement(); },
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.accent,
                      child: const Text('重试', style: TextStyle(color: CupertinoColors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ]))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (_title != null && _title != '公告') ...[
                          Text(_title!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 12),
                        ],
                        if (_content != null)
                          Text(_content!, style: const TextStyle(fontSize: 14, height: 1.8, color: AppColors.textPrimary)),
                      ]),
                    ),
                  ),
      ),
    );
  }
}
