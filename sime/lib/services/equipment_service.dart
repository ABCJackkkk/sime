import 'package:sime/models/script.dart';

class EquipmentSlot {
  EquipmentSlot();
  ScriptItem? item;
  String itemId = '';
  Map<String, double> savedStats = {};

  Map<String, dynamic> toJson() => {'itemId': itemId, 'savedStats': savedStats};
  factory EquipmentSlot.fromJson(Map<String, dynamic> json) {
    final s = EquipmentSlot();
    s.itemId = json['itemId'] ?? '';
    s.savedStats = (json['savedStats'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {};
    return s;
  }
}

class EquipmentService {
  final Map<String, EquipmentSlot> _slots = {};

  EquipmentService() {
    _slots['head'] = EquipmentSlot();
    _slots['body'] = EquipmentSlot();
    _slots['accessory'] = EquipmentSlot();
    _slots['weapon'] = EquipmentSlot();
  }

  bool equip(String itemId, ScriptItem item) {
    if (item.equipStats.isEmpty || item.slot.isEmpty) return false;
    final slot = _slots[item.slot];
    if (slot == null) return false;
    slot.item = item;
    slot.itemId = itemId;
    slot.savedStats = Map<String, double>.from(item.equipStats);
    return true;
  }

  ScriptItem? unequip(String slotId) {
    final slot = _slots[slotId];
    if (slot == null) return null;
    final item = slot.item;
    slot.item = null;
    slot.itemId = '';
    return item;
  }

  ScriptItem? getEquipped(String slotId) => _slots[slotId]?.item;

  Map<String, double> getStatBonuses() {
    final bonuses = <String, double>{};
    for (final slot in _slots.values) {
      final stats = slot.item?.equipStats ?? slot.savedStats;
      if (stats.isEmpty) continue;
      for (final e in stats.entries) {
        bonuses[e.key] = (bonuses[e.key] ?? 0) + e.value;
      }
    }
    return bonuses;
  }

  double getStatBonus(String statId) {
    double total = 0;
    for (final slot in _slots.values) {
      final stats = slot.item?.equipStats ?? slot.savedStats;
      if (stats.isEmpty) continue;
      total += stats[statId] ?? 0;
    }
    return total;
  }

  Map<String, Map<String, dynamic>> getSlotsAsMap() {
    return _slots.map((k, v) => MapEntry(k, {
      'itemId': v.itemId,
      'itemName': v.item?.name ?? '',
    }));
  }

  Map<String, dynamic> toJson() {
    final slotData = <String, dynamic>{};
    for (final e in _slots.entries) {
      slotData[e.key] = e.value.toJson();
    }
    return {'slots': slotData};
  }

  factory EquipmentService.fromJson(Map<String, dynamic> json) {
    final s = EquipmentService();
    final slotsData = json['slots'] as Map<String, dynamic>?;
    if (slotsData != null) {
      for (final e in slotsData.entries) {
        s._slots[e.key] = EquipmentSlot.fromJson(e.value as Map<String, dynamic>);
      }
    }
    return s;
  }
}
