class UpdateInfo {
  final String latestVersion;
  final int latestBuildNumber;
  final String downloadUrl;
  final String? changelog;
  final bool forceUpdate;
  final String? announcement;
  final String? announcementTitle;
  final String? donateQrUrl;
  final String? donateTip;

  UpdateInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.downloadUrl,
    this.changelog,
    this.forceUpdate = false,
    this.announcement,
    this.announcementTitle,
    this.donateQrUrl,
    this.donateTip,
  });

  bool get hasUpdate => latestBuildNumber > 0;

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      latestVersion: json['latestVersion'] ?? '0.0.0',
      latestBuildNumber: json['latestBuildNumber'] ?? 0,
      downloadUrl: json['downloadUrl'] ?? '',
      changelog: json['changelog'],
      forceUpdate: json['forceUpdate'] ?? false,
      announcement: json['announcement'],
      announcementTitle: json['announcementTitle'],
      donateQrUrl: json['donateQrUrl'],
      donateTip: json['donateTip'],
    );
  }

  bool hasNewVersion(String currentVersion, int currentBuild) {
    if (latestBuildNumber > currentBuild) return true;
    return _compareVersion(latestVersion, currentVersion) > 0;
  }

  int _compareVersion(String a, String b) {
    final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av > bv) return 1;
      if (av < bv) return -1;
    }
    return 0;
  }
}
