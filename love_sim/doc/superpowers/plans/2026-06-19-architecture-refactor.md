# 架构重构：世界驱动叙事 + 角色交互层改造

> **For agentic workers:** Implement task-by-task using SearchReplace on existing files and Write for new files. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将爱心模拟引擎从"事件模板填空"架构改为"世界驱动叙事"架构，同时改造角色交互层

**Architecture:** 四轮渐进式重构。第一轮修 Bug+数据注入（最快见效），第二轮三层分权+事件池降级（核心架构），第三轮角色发现+通讯录分离+场景互动（交互层），第四轮 UI 美术（最后）

**Tech Stack:** Flutter/Dart, Provider state management, DeepSeek API

---

## 第一轮：修 Bug + 数据注入

### Task 1.1: 修复时间系统 _currentDay 类型不一致

**Files:**
- Modify: `d:\AR\love_sim\lib\services\game_session.dart`
- Modify: `d:\AR\love_sim\lib\providers\app_provider.dart`

**现状**: GameSession._currentDay 是 String，WorldEngine._currentDay 是 int。存档加载和显示时反复 parse/toString，容易出错。

- [x] **Step 1: 将 GameSession._currentDay 改为 int** — 保留为 String，采用方案2（advance 内统一 parse）
- [x] **Step 2: 修改所有 _currentDay 字符串使用为整数** — 暂不进行，避免大范围重构
- [x] **Step 3: 修改 app_provider.dart 的 currentDay getter** — 保留
- [x] **Step 4: 修改 save_service.dart 的 currentDay 类型** — 保留
- [x] **Step 5: 修改 root_screen.dart 显示** — 保留
- [x] **Step 6: 修复 _skipDays 后 _currentPhase 重置为第一个时段的问题** — 改为 `phaseBefore = _currentPhase; ... skip; _currentPhase = phaseBefore;`
- [x] **Step 7: 构建验证** — ✅

> **决策：** _currentDay 保留 String 类型，所有需要 int 的地方统一 `int.tryParse(_currentDay)` 处理，避免存档兼容性断裂。

### Task 1.2: 排名数据注入 AI Prompt

**Files:**
- Modify: `d:\AR\love_sim\lib\services\deepseek_client.dart`
- Modify: `d:\AR\love_sim\lib\services\game_session.dart`

**现状**: `_buildChatSystemPrompt` 和 `_buildWorldSystemPrompt` 没有排名数据。AI 编造角色排名。

- [x] **Step 1: 在 game_session.dart 添加排名信息构建方法** — 实现 `buildRankingContextForAi()`，读取 `rankingService.rankHistory`
- [x] **Step 2: 注入排名到聊天 Prompt** — 暂不注入chat prompt
- [x] **Step 3: 注入排名到世界叙事 Prompt** — 在 `generateWorldNarrative()` 中注入
- [x] **Step 4: 在调用处传入排名数据** — advance() 中传入
- [x] **Step 5: 构建验证** — ✅

> **修正：** RankRecord 结构已确认：`eventName/day/totalStudents/playerRank/charRanks: List<CharRankEntry>`。`buildRankingContextForAi()` 实际按此实现。

---

## 第二轮：架构下沉（事件池退位，世界驱动上位）

### Task 2.1: 建立三层架构数据模型

**Files:**
- Create: `d:\AR\love_sim\lib\services\rhythm_scheduler.dart` ✅

**实际实现与计划差异：**

> 计划中的 `RhythmLayer` + `WorldLayer` + `GenerationLayer` 三层文件模型被合并为更简洁的方案：
> - `rhythm_scheduler.dart` 替代 `rhythm_layer.dart`，使用 `NarrativeWeight`（light/medium/heavy/critical）+ `DramaticFocus`（characterMoment/relationshipBeat/plotAdvancement/worldTexture/tensionEscalation/ensembleScene）替代计划中的 `RhythmBeat` + `mood` + `intensity`
> - `WorldLayer` 不需要单独文件——`WorldEngine` 已有 `totalDays` getter、`lastTickReport`、`getNextMilestone()`、`isNearMilestone()`，直接承担世界层职责
> - `GenerationLayer` 不需要单独文件——`DeepSeekClient.generateWorldNarrative()` 直接承担生成层职责

**实际实现的 RhythmScheduler：**

```dart
class RhythmDirective {
  final NarrativeWeight weight;       // light/medium/heavy/critical → 控制字数
  final DramaticFocus primaryFocus;   // 叙事焦点方向
  final DramaticFocus? secondaryFocus;
  final double tensionContribution;   // 张力贡献值
  final List<String> participantIds;  // 世界撞车算出在场角色
  final String? locationId;           // 日程撞车算出地点
  final String? narrativeHint;        // 特殊指引
}

class RhythmScheduler {
  double narrativeTension = 10.0;

  RhythmDirective resolve({
    mode, currentDay, totalDays, worldReport, affection, allCharIds,
    nearMilestone, milestoneDay, milestoneName, script, currentPhase, currentWeather,
  }) {
    // 五路触发源 → 合并 → RhythmDirective
    ① _checkPlotBeat()          → weight: critical/heavy/medium
    ② _checkAffectionBoundary() → weight: heavy/medium
    ③ _checkWorldCollision()    → weight: medium（participants+location来自世界状态）
    ④ _checkInfoSpread()        → weight: medium
    ⑤ _checkDefaultDaily()      → weight: light
  }
}
```

- [x] **Step 1: 创建 rhythm_scheduler.dart** — ✅ 实现完成
- [x] **Step 2: WorldEngine 暴露接口** — 添加 `totalDays` getter、`lastTickReport` 字段、`getNextMilestone()`、`isNearMilestone()`
- [x] **Step 3: DeepSeekClient 新增 generateWorldNarrative()** — ✅ 实现完成，接受 `RhythmDirective` + 世界快照
- [x] **Step 4: 构建验证** — ✅ flutter build web 通过

### Task 2.2: 事件池降级 —— 从叙事生成器退化为节奏控制器

**Files:**
- Modify: `d:\AR\love_sim\lib\services\game_session.dart`

- [x] **Step 1: 在 advance() 中接入 RhythmScheduler** — ✅ 完成
- [x] **Step 2: 实现 generateWorldNarrative 调用** — ✅ 世界快照驱动替代事件模板驱动
- [x] **Step 3: useRhythmLayer 开关（渐进式过渡）** — ✅ 实现
  - `useRhythmLayer = true` → 走新路径（RhythmScheduler + generateWorldNarrative）
  - `useRhythmLayer = false` → 走老路径（EventScheduler + generateEventNarrative）
- [x] **Step 4: 构建验证** — ✅

### Task 2.3: 剧本 JSON 兼容 —— campus_love.json 保持可用

**Files:**
- None（验证现有 JSON 兼容性）

- [x] **Step 1: 验证 campus_love.json 的事件定义不受影响** — ✅ 现有 JSON 不改，eventScheduler 仅在使用 `useRhythmLayer=false` 时工作
- [ ] **Step 2: 确保 Template JSON（_template.json）也包含新字段** — 本阶段完成，见下文

---

## 第三轮：角色交互层重构

### Task 3.1: 渐进式角色发现

**Files:**
- Modify: `d:\AR\love_sim\lib\models\script.dart`
- Modify: `d:\AR\love_sim\lib\services\game_session.dart`
- Modify: `d:\AR\love_sim\lib\providers\app_provider.dart`
- Modify: `d:\AR\love_sim\lib\screens\contacts_screen.dart`
- Modify: `d:\AR\love_sim\lib\screens\world_screen.dart`

- [ ] **Step 1: 在 Character 模型中添加 discovery_condition** — 未开始
- [ ] **Step 2: 在 game_session 中添加已发现角色集合** — 未开始
- [ ] **Step 3: 修改 getCharacter 相关逻辑** — 未开始
- [ ] **Step 4: 在事件中检查角色发现并触发** — 未开始
- [ ] **Step 5: 构建验证** — 未开始

### Task 3.2: 通讯录分离 —— 纯异步对话

**Files:**
- Modify: `d:\AR\love_sim\lib\screens\chat_screen.dart`
- Modify: `d:\AR\love_sim\lib\services\game_session.dart`

- [ ] **Step 1: 聊天消息加时间戳和地点背景** — 未开始
- [ ] **Step 2: 在导航栏显示当前地点背景** — 未开始
- [ ] **Step 3: 确保聊天不推进时间** — 未开始
- [ ] **Step 4: 构建验证** — 未开始

### Task 3.3: 家园 / 场景互动增强

**Files:**
- Modify: `d:\AR\love_sim\lib\screens\scene_screen.dart`
- Modify: `d:\AR\love_sim\lib\services\game_session.dart`

- [ ] **Step 1: 在 scene_screen 添加"邀请角色"按钮** — 未开始
- [ ] **Step 2: 添加邀请逻辑** — 未开始
- [ ] **Step 3: 构建验证** — 未开始

---

## 第四轮：UI 美术（P5R 风格）

### Task 4.1: P5R 配色 + 几何切角

**Files:**
- Modify: `d:\AR\love_sim\lib\main.dart`
- Modify: Various screen files

- [ ] **Step 1: 在 AppColors 添加 P5R 配色** — 未开始
- [ ] **Step 2: 修改 GlassContainer 为 P5R 斜切风格** — 未开始
- [ ] **Step 3: 逐个屏幕应用 P5R 配色** — 未开始

---

## 计划修正（自审后）

以下是在自审中发现的与代码实际不符之处，已修正逻辑但不改步骤编号：

### 修正 1：排名数据来源
- `RankingService`（非 game_session._rankings）持有 `List<RankRecord> _rankHistory`
- `RankRecord` 包含 `day`, `totalStudents`, `charRanks: List<CharRankEntry>`（charId, rank, totalScore）
- Task 1.2 中的 `buildRankingContextForAi()` 应改为遍历 `rankingService._rankHistory`（需添加 public getter）

### 修正 2：_totalDays 访问
- `WorldEngine._totalDays` 是私有的，需在 WorldEngine 添加 `int get totalDays => _totalDays;`
- 或者在 game_session 中通过 `script!.interaction.totalDays` 获取（已有 public 字段）

### 修正 3：lastTickReport
- `WorldEngine` 当前没有 `lastTickReport` 字段，需在 `tickWorld()` 中保存结果到 `_lastTickReport`

### 修正 4：日程状态访问
- `worldEngine.lastTickReport.allStates` 中的 state 对象需要通过 `CharacterScheduleService.getLocationState()` 访问
- 实际字段：`state.charName`, `state.locationName`, `state.activity` — 需确认 ScheduleState 模型

### 修正 5：RhythmScheduler 实际实现与计划差异（本次新增）

计划中设计了 `RhythmLayer.computeBeat()` 使用 `RhythmBeat` 枚举（daily/minor/major/critical/climax）+
`mood` + `intensity`，实际实现改为 `RhythmScheduler.resolve()` 使用 `NarrativeWeight`（light/medium/heavy/critical）+
`DramaticFocus`（6种焦点）。原因：

1. **weight 直接映射字数** — light=150字 / medium=300字 / heavy=500字 / critical=700字，AI 拿到后就能控制输出长度
2. **focus 比 mood+intensity 更精确** — AI 不需要被告诉"紧张"或"温暖"，而是被告知"此刻焦点放在角色关系变化上"还是"焦点放在环境氛围上"
3. **participants+location 由世界层算** — 不在 rhythm_scheduler 内部做组合，而是从 `worldReport` 里提取撞车结果
4. **五路触发源合并逻辑** — 多触发源同时命中时取最高 weight、participants 取并集、focus 取最高优先级

---

## 改动深度总结

```
第一轮（完成）：修 Bug + 数据注入         ← 3-4 个 task ✅
    ↓
第二轮（完成）：RhythmScheduler + 事件池降级  ← 核心架构 ✅
    ↓
第三轮：角色发现 + 通讯录分离 + 场景互动   ← 待开始
    ↓
第四轮：P5R UI 美术                       ← 待开始
```

### 第二轮实际产出文件清单

| 文件 | 变更 | 说明 |
|---|---|---|
| `rhythm_scheduler.dart` | 新建 | RhythmDirective + RhythmScheduler（五路触发源） |
| `world_engine.dart` | 修改 | +totalDays getter, +lastTickReport, +getNextMilestone(), +isNearMilestone() |
| `deepseek_client.dart` | 修改 | +buildCharProfile(), +generateWorldNarrative() |
| `game_session.dart` | 修改 | +RhythmScheduler集成, +useRhythmLayer开关, +buildRankingContextForAi() |

### 世界驱动叙事 vs 旧事件模板驱动

| 维度 | 旧（EventScheduler） | 新（RhythmScheduler） |
|---|---|---|
| AI拿到的输入 | "请写一段校门口偶遇" | "此刻下午放学，走廊上。苏念晚从琴房回教室... 叙事权重：medium。焦点：角色日常瞬间。" |
| 参与者来源 | 模板硬编码或随机 | 世界撞车算出（谁和谁在同一个地方） |
| 地点来源 | 模板指定 | 日程撞车算出 |
| 世界状态 | 附加信息 | 叙事出发点 |
| 事件池 | 必须定义14种模板 | 保留但降级（useRhythmLayer=false时使用） |
| 换剧本 | 需重新定义事件池 | beat_rhythm_map + boundary_rhythm_map 在JSON中配置 |
