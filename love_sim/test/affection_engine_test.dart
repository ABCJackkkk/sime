import 'package:flutter_test/flutter_test.dart';
import 'package:love_sim/services/affection_engine.dart';
import 'package:love_sim/models/script.dart';

GameScript _makeTestScript(List<Character> chars) {
  return GameScript(
    meta: ScriptMeta(
      id: 'test',
      name: '测试剧本',
      version: '1.0',
      author: '测试',
      genre: '校园',
      tone: '轻松',
      mode: 'single',
      summary: '测试用剧本',
    ),
    player: ScriptPlayer(
      background: '普通学生',
      currentState: '正常',
    ),
    world: ScriptWorld(
      summary: '一个普通学校',
      setting: '现代校园',
      atmosphere: {},
      locations: [],
      specialRules: {},
      memory: WorldMemory(
        currentTime: WorldCurrentTime(day: 1, phase: '上午'),
        locationChanges: [],
        worldHistory: {},
        worldSummary: '',
      ),
    ),
    characters: chars,
    items: ScriptItems(gifts: [], shopItems: []),
    interaction: InteractionConfig(totalDays: 60, startDay: 1, endDay: 60, season: '春', phases: ['上午', '下午', '晚上']),
  );
}

Character _makeChar(String id, String name) {
  return Character(
    fullCharacter: true,
    summary: '测试角色$name',
    basic: CharacterBasic(
      id: id,
      name: name,
      gender: '女',
      age: 17,
      height: '165cm',
      weight: '50kg',
      avatarDesc: '长发',
      distinctiveMarks: [],
    ),
  );
}

void main() {
  late GameScript script;

  setUp(() {
    script = _makeTestScript([_makeChar('c1', '测试角色')]);
  });

  group('好感度基础操作', () {
    test('初始化', () {
      final engine = AffectionEngine(script: script);
      engine.init('c1', 30);
      expect(engine.getAffection('c1'), 30.0);
    });

    test('modifyAffectionByEvent 在低区间正常增长', () {
      final engine = AffectionEngine(script: script);
      engine.init('c1', 20);
      engine.modifyAffectionByEvent('c1', 10);
      expect(engine.getAffection('c1'), greaterThan(20));
      expect(engine.getAffection('c1'), lessThan(31));
    });

    test('modifyAffectionByEvent 在高区间几乎不增长', () {
      final engine = AffectionEngine(script: script);
      engine.init('c1', 90);
      engine.modifyAffectionByEvent('c1', 10);
      expect(engine.getAffection('c1'), lessThan(91));
    });

    test('modifyAffectionByEvent 不低于 0', () {
      final engine = AffectionEngine(script: script);
      engine.init('c1', 2);
      engine.modifyAffectionByEvent('c1', -10);
      expect(engine.getAffection('c1'), greaterThanOrEqualTo(0));
    });

    test('modifyAffectionByEvent 不高于 100（无锁定）', () {
      final engine = AffectionEngine(script: script);
      engine.init('c1', 95);
      engine.modifyAffectionByEvent('c1', 10);
      expect(engine.getAffection('c1'), lessThanOrEqualTo(100));
    });
  });

  group('好感区间标签', () {
    test('0-10 死敌', () {
      final engine = AffectionEngine(script: script);
      engine.init('c1', 5);
      expect(engine.getCurrentTier('c1').label, '死敌');
    });
    test('10-20 仇恨', () {
      final engine = AffectionEngine(script: script);
      engine.init('c1', 15);
      expect(engine.getCurrentTier('c1').label, '仇恨');
    });
    test('50-60 陌生人', () {
      final engine = AffectionEngine(script: script);
      engine.init('c1', 55);
      expect(engine.getCurrentTier('c1').label, '陌生人');
    });
    test('80-90 喜欢', () {
      final engine = AffectionEngine(script: script);
      engine.init('c1', 85);
      expect(engine.getCurrentTier('c1').label, '喜欢');
    });
    test('100 永恒唯一', () {
      final engine = AffectionEngine(script: script);
      engine.init('c1', 100);
      expect(engine.getCurrentTier('c1').label, '永恒唯一');
    });
  });

  group('modifyAffectionByChat 边界锁', () {
    test('59.97 处聊天不再增加', () {
      final engine = AffectionEngine(script: script);
      engine.init('c1', 59.97);
      engine.modifyAffectionByChat('c1', 2.0);
      expect(engine.getAffection('c1'), 59.99);
    });

    test('80 以上聊天不掉破 80', () {
      final engine = AffectionEngine(script: script);
      engine.init('c1', 82);
      engine.modifyAffectionByChat('c1', -5.0);
      expect(engine.getAffection('c1'), 80.0);
    });

    test('80 以下聊天可自由滑落', () {
      final engine = AffectionEngine(script: script);
      engine.init('c1', 79);
      engine.modifyAffectionByChat('c1', -10.0);
      expect(engine.getAffection('c1'), lessThan(79));
    });
  });

  group('modifyAffectionByEvent 不受锁限制', () {
    test('事件可跨 60 边界', () {
      final engine = AffectionEngine(script: script);
      engine.init('c1', 59);
      engine.modifyAffectionByEvent('c1', 5.0);
      expect(engine.getAffection('c1'), greaterThan(60));
    });
  });

  group('唯一羁绊', () {
    test('第一个人 100 后其他人锁 98', () {
      final script2 = _makeTestScript([
        _makeChar('c1', '一号'),
        _makeChar('c2', '二号'),
      ]);
      final engine = AffectionEngine(script: script2);
      engine.init('c1', 99.9);
      engine.init('c2', 99);
      engine.modifyAffectionByEvent('c1', 0.2);
      engine.modifyAffectionByEvent('c2', 2.0);
      expect(engine.getAffection('c1'), 100.0);
      expect(engine.getAffection('c2'), lessThan(100));
    });
  });
}
