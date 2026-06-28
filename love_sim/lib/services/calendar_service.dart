import 'package:love_sim/models/script.dart';

/// 日历服务 —— 管理周几、特殊日、考试周期
/// 天数由 WorldEngine 提供，不独立维护计数器
class CalendarService {
  int _totalDays = 365;
  List<Map<String, dynamic>> _specialDays = [];
  Map<String, dynamic>? _examConfig;

  int get totalDays => _totalDays;

  List<Map<String, dynamic>> _phases = [];
  List<Map<String, dynamic>> get allPhases => _phases;

  void initFromScript(GameScript script) {
    _totalDays = script.interaction.totalDays;
    _specialDays = [];
    final raw = script.gameInteraction?.timeConfig?['special_days'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          _specialDays.add(Map<String, dynamic>.from(item));
        }
      }
    }
    // 从剧本读取时段
    _phases = [];
    final rawPhases = script.gameInteraction?.timeConfig?['phases'];
    if (rawPhases is List) {
      for (final p in rawPhases) {
        if (p is Map) {
          _phases.add(Map<String, dynamic>.from(p));
        }
      }
    }
    if (_phases.isEmpty) {
      _phases = [
        {'id':'lingchen','name':'凌晨','hour':'00-06','mood':'万籁俱寂','skippable':true},
        {'id':'qingchen','name':'清晨','hour':'06-08','mood':'日出晨起','skippable':false},
        {'id':'shangwu','name':'上午','hour':'08-11','mood':'上午课程','skippable':false},
        {'id':'zhongwu','name':'中午','hour':'11-13','mood':'午休午餐','skippable':false},
        {'id':'xiawu','name':'下午','hour':'13-17','mood':'下午课程','skippable':false},
        {'id':'bangwan','name':'傍晚','hour':'17-19','mood':'黄昏归家','skippable':false},
        {'id':'yewan','name':'夜晚','hour':'19-24','mood':'晚间自由','skippable':false},
      ];
    }
    final ranking = script.dataLayer?.ranking;
    if (ranking != null && ranking.events.isNotEmpty) {
      _examConfig = {
        'total_students': ranking.totalStudents,
        'events': ranking.events.map((e) => {
          'id': e.id, 'name': e.name, 'interval_days': e.intervalDays,
        }).toList(),
      };
    }
  }

  /// 当前天数（由外部传入）
  int currentDay = 1;

  /// 0=周一, 6=周日
  int weekday(int day) => (day - 1) % 7;
  bool isWeekend(int day) => weekday(day) >= 5;
  String weekdayName(int day) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[weekday(day)];
  }

  /// 当前是否有特殊日
  Map<String, dynamic>? getSpecialDay(int day) {
    for (final sd in _specialDays) {
      if (sd?['day'] == day) return sd;
    }
    return null;
  }

  int daysUntilNextSpecialDay(int day) {
    int best = _totalDays;
    for (final sd in _specialDays) {
      final d = sd?['day'] as int? ?? 0;
      if (d > day && d - day < best) best = d - day;
    }
    return best;
  }

  bool isExamReviewPeriod(int day) {
    if (_examConfig == null) return false;
    final events = _examConfig!['events'] as List;
    for (final evt in events) {
      final interval = evt['interval_days'] as int;
      int nextExam = ((day ~/ interval) + 1) * interval;
      if (nextExam - day <= 14 && nextExam - day > 0) return true;
    }
    return false;
  }

  int daysUntilNextExam(int day) {
    if (_examConfig == null) return -1;
    int best = _totalDays * 2;
    final events = _examConfig!['events'] as List;
    for (final evt in events) {
      final interval = evt['interval_days'] as int;
      int nextExam = ((day ~/ interval) + 1) * interval;
      if (nextExam - day < best && nextExam - day > 0) best = nextExam - day;
    }
    return best > _totalDays ? -1 : best;
  }

  List<String> getPhaseNames(int day) {
    if (_phases.isEmpty) return ['凌晨','清晨','上午','中午','下午','傍晚','夜晚'];
    return _phases.map((p) => p['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
  }

  bool isPhaseSkippable(int phaseIndex) {
    if (phaseIndex < 0 || phaseIndex >= _phases.length) return false;
    return _phases[phaseIndex]['skippable'] == true;
  }

  Map<String, dynamic> getDateContext(int day) {
    return {
      'day': day,
      'weekday': weekdayName(day),
      'is_weekend': isWeekend(day),
      'is_special_day': getSpecialDay(day) != null,
      'special_day': getSpecialDay(day),
      'exam_review': isExamReviewPeriod(day),
      'days_until_exam': daysUntilNextExam(day),
    };
  }
}
