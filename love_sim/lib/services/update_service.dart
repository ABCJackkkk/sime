import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:love_sim/models/update_info.dart';

class UpdateService {
  static const String defaultConfigUrl = 'https://gitee.com/api/v5/repos/yourname/yourrepo/releases/latest';

  String configUrl;
  UpdateInfo? _cachedInfo;
  PackageInfo? _packageInfo;

  UpdateService({this.configUrl = defaultConfigUrl});

  Future<void> init() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  String get currentVersion => _packageInfo?.version ?? '1.0.0';
  int get currentBuildNumber => int.tryParse(_packageInfo?.buildNumber ?? '1') ?? 1;

  UpdateInfo? get cachedInfo => _cachedInfo;

  Future<UpdateInfo?> checkUpdate({bool force = false}) async {
    if (_cachedInfo != null && !force) return _cachedInfo;
    if (configUrl.isEmpty) return null;

    try {
      final uri = Uri.parse(configUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        _cachedInfo = UpdateInfo.fromJson(json);
        return _cachedInfo;
      }
    } catch (_) {}
    return null;
  }

  bool hasNewVersion(UpdateInfo info) {
    return info.hasNewVersion(currentVersion, currentBuildNumber);
  }

  Future<void> openDownloadPage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
