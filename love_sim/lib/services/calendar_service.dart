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
      // 兜底：十二时辰
      _phases = [
        {'id':'zi','name':'子时','hour':'23-01','mood':'夜深人静','skippable':true},
        {'id':'chou','name':'丑时','hour':'01-03','mood':'万籁俱寂','skippable':true},
        {'id':'yin','name':'寅时','hour':'03-05','mood':'黎明之前','skippable':true},
        {'id':'mao','name':'卯时','hour':'05-07','mood':'日出晨起','skippable':false},
        {'id':'chen','name':'辰时','hour':'07-09','mood':'朝食上学','skippable':false},
        {'id':'si','name':'巳时','hour':'09-11','mood':'上午课程','skippable':false},
        {'id':'wu','name':'午时','hour':'11-13','mood':'午休午餐','skippable':false},
        {'id':'wei','name':'未时','hour':'13-15','mood':'下午课程','skippable':false},
        {'id':'shen','name':'申时','hour':'15-17','mood':'放学社团','skippable':false},
        {'id':'you','name':'酉时','hour':'17-19','mood':'黄昏归家','skippable':false},
        {'id':'xu','name':'戌时','hour':'19-21','mood':'晚间自由','skippable':false},
        {'id':'hai','name':'亥时','hour':'21-23','mood':'就寝之前','skippable':false},
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
    if (_phases.isEmpty) return ['子时','丑时','寅时','卯时','辰时','巳时','午时','未时','申时','酉时','戌时','亥时'];
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
