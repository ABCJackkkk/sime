# LoveSim PRD — 剧本驱动恋爱模拟引擎

> **当前版本：v2.9** — 世界驱动统一 + 场景交互改造 + 被动/互斥张力 · 编译通过 ✅ · 2026-06-22

## 一、项目定位

这是一个**剧本驱动的恋爱模拟引擎**。核心思路：

- 写一份符合规范的 JSON 剧本 → 模拟器自动跑出一个完整世界
- 不局限于校园恋爱——换一个结构一致的剧本就能模拟古风、科幻、悬疑等任何题材
- DeepSeek API 驱动 AI 叙事，人物行为不靠脚本硬写，而是靠角色模型约束 AI 生成

---

## 二、工程铁律

```
              ╔═══════════════════════════════╗
              ║  换剧本不改一行Dart代码        ║
              ║  Script ≠ Code               ║
              ╚═══════════════════════════════╝
```

**核心原则：引擎与剧本严格分离。** 游戏逻辑的所有参数、配置、公式、ID 映射、阈值、成长率，全部来自 JSON 数据层——不在任何 `.dart` 文件中硬编码具体剧本的角色名、科目名、属性名、事件名、地点名。

### 引擎职责（不关心剧本内容）
- JSON 解析为 Dart 模型
- 公式执行（代入 JSON 参数，不代值）
- 存档/读档
- UI 渲染（数据驱动，不预设固定列表）

### 剧本 JSON 职责
- 角色定义（含 stat/grades 初始值）
- 属性池和成绩池（id/name/min/max/initial）
- 排名体系（总人数/事件间隔）
- **grade_formulas**（每科成绩的属性加成映射 + 方差参数）
- **natural_growth_rate**（全局自然成长速率）

---

## 三、三层架构

| 层 | 是什么 | 谁改 | 什么时候改 |
|---|---|---|---|
| **sim-script.json** | 工业模板——定义所有字段的数据结构和语义 | 策划 / 剧本作者 | 引擎需要新的数据维度时 |
| **模拟器** | Dart/Flutter 代码——JSON→对象→引擎运转→UI | 开发 | 修 bug、加引擎功能、改 UI |
| **剧本** (.json) | 按 sim-script 格式填写的具体剧本内容 | 剧本作者 | 写新剧本、调平衡 |

---

## 四、数据层规范 (data_layer)

### 4.1 属性池 (stats)
```json
"stats": [
  {"id": "intelligence", "name": "智商", "category": "talent", "min": 0, "max": 100, "initial": 55}
]
```
- `id` 必须在该剧本内唯一，并与 `grade_formulas.stat_bonuses` 中引用的 key 一致
- `category` 用于 UI 分组，可自定义

### 4.2 成绩池 (grades)
```json
"grades": [
  {"id": "chinese", "name": "语文", "min": 0, "max": 150, "initial": 108}
]
```
- `id` 必须与 `grade_formulas` 的 key 和 ranking `affects` 数组中引用的 ID 一致

### 4.3 成绩公式 (grade_formulas)
```json
"grade_formulas": {
  "chinese": {
    "base_weight": 0.70,
    "variance": 10,
    "stat_bonuses": {"intelligence": 0.07, "charisma": 0.05}
  }
}
```

### 4.4 成长率 (natural_growth_rate)
- 每次考试前，所有 stat/grade 按 `(max - current) × rate` 自然成长

### 4.5 排名体系 (ranking)
```json
"ranking": {
  "total_students": 750,
  "events": [
    {"id": "monthly_exam", "name": "月考", "interval_days": 30, "affects": ["chinese","math","english","science"]}
  ]
}
```

### 4.6 养成训练系统 (training)
```json
"training": {
  "actions": [
    {"id":"study_lib","name":"图书馆自习","target_stat":"intelligence","gain":3,
     "target_grade":"chinese","grade_gain":1,
     "phases":["辰时","巳时","未时","申时","戌时"],
     "locations":["library_3f"]}
  ]
}
```

### 4.7 工业化示例

| 校园剧本 | 修仙剧本 |
|---|---|
| stats: 智商/颜值/体能/魅力 | stats: 灵根/悟性/根骨/神识/气运 |
| grades: 语文/数学/英语/理综 | grades: 修为/丹道/剑法/阵法/符箓 |
| ranking: 月考(30天)/期末(90天) | ranking: 宗门大比(60天)/渡劫(180天) |

---

## 五、剧本结构（十一层）

### 5.1 meta — 元信息
剧本的身份证：id、名称、版本、作者、类型、基调、模式(endings/sandbox)、摘要。

### 5.2 player — 主角
- **剧本只定义背景和处境**：`background`（成长史）和 `current_state`（开局心境）
- **基础信息来自玩家角色卡**：名字、性别、身高、生日、外貌描述、性格描述 → 由玩家在「我的」页编辑
- `playerCardForAi` 运行时拼接：玩家角色卡 + 剧本 background + 剧本 current_state → 注入 AI System Prompt

### 5.3 world — 世界观
```
world
├── summary        — 世界快照（约200-300字）
├── setting        — 完整世界观（直接注入 AI System Prompt）
├── atmosphere     — 氛围（base_mood / color_palette / hint）
├── locations[]    — 地点列表（id/name/desc/visibility/可用时段/场景氛围/narrative_profile）
├── special_rules  — 剧本类型差异化规则
└── memory         — 运行时状态（当前时间/地点变化/世界历史/世界摘要）
```

### 5.4 characters — 角色
角色分两种：
- **立体角色**（full_character=true）：27 个子字段，全面控制 AI 行为
- **平面角色**（full_character=false）：一段 summary，只出现在叙事中

立体角色的关键字段：

| 字段 | 对 AI 的影响 |
|---|---|
| **basic** | 外貌、身高、体型——AI 描述外观的依据 |
| **background** | 出身、成长史——AI 理解角色动机 |
| **soul** | 核心价值观、欲望、创伤、恐惧、矛盾、双模式 |
| **speech** | 大五人格、语音学、词汇风格、互动模式、双模式 |
| **humanity** | 反AI规则、写作姿态、非语言行为列表 |
| **evolution** | 好感度11个区间各阶段描述、成长弧线 |
| **schedule** ★ | 角色独立日程（weekday/weekend，时段→地点→活动+优先级+条件） |
| **boundary** | 身体距离、情感边界、话题禁区、亲密度节奏 |
| **memory** | 情景记忆、聊天日志、印象 |
| **memory_tags** ★v2.8 | 记忆标签配置（default/affection_breakthrough/conflict/triangular） |

### 5.4A inter_character_relationships — 角色间关系 ★
不再只有玩家↔角色好感度。角色之间也有数据：
- `initial_attitudes[]` — 初始角色间态度（from/to/affinity/label/history）
- `affinity_states` — 8级亲和力标签（死对头→挚友，-100~100）
- `triggers` — 变化触发器（on_player_event / on_schedule_collision / on_witness / on_info_spread）

### 5.4B information_system — 信息传播系统 ★
- `encryption_styles` — 5种加密风格(honest/joke/gossip/cold/speculation)
- `visibility_rules` — 事件可见度决定谁自动成为见证人
- `fragment_schema` — 信息碎片结构(source_event/witness/content/encryption/spread_radius/known_by/trustworthiness)

**传播流程**：事件发生 → 旁观者成为见证人 → 信息碎片创建 → 每次推进扩散1步 → 内容被加密扭曲 → 可信度衰减。

### 5.5 plot — 剧情
不是预写的故事，是给 AI 的"方向指令"：
- `acts[]` — 幕（id/名称/描述/阶段区间/出入条件/叙事方向/基调/节拍列表/节奏权重）
- `beats[]` — 剧情节拍（触发条件+AI方向+结果+优先级）
- `endings[]` — 结局定义
- `narrative_tension` — 叙事张力曲线
- `branch_system` / `foreshadow_system` — 路线追踪 / 伏笔系统

### 5.6 events — 事件

| 类型 | duration | 行为 |
|---|---|---|
| **短事件** | `"short"` (默认) | 生成叙事 → 弹出选项 → 选择后自动续 2 回合 → 自然结束 |
| **长事件** | `"long"` | 生成叙事 → 弹出选项 → 选择后继续 → 直到 `max_steps` 轮结束 |

**v2.8 起所有事件都是多回合**：不再是"选完就结束"。玩家在任何事件中至少有 2 次继续推进的机会，让事件有"对话感"而不是"选择题"。

14 种事件池：plot / boundary / daily / sweet_minor / sweet_major / love_triangle / reversal / echo / misunderstanding / ensemble / world_shift / forced_choice / resource / dialogue_trigger

### 5.7 dialogue — 对话
- **world_sim** — 主世界叙事引擎
- **character_chat** — 角色对话引擎
- **compressor** — 上下文压缩

### 5.8 items — 物品
- currency：货币系统（多币种支持）
- list：物品列表（gift/key_item/consumable/collectible 四类）
- shop：商店 + gifting：送礼规则 + crafting：合成（可选）

### 5.9 interaction — 交互
- `time_config` — 时间推进配置（十二时辰）
- `advance_modes` — 三种推进模式（daily / major / free）
- `affection` — 好感度系统（核心）
  - 精度 0.01，范围 1-100。区间内自由浮动，跨区间必须通过对应层级的事件
  - 80 以下：临界事件通过即可跨。80：必须重要推进+长剧情事件。90：必须重要推进+剧情事件。100：终极事件，只能一人
- `seasons[]` / `weather_system` — 季节/天气

---

## 六、模拟器代码结构

```
love_sim/lib
├── main.dart
├── models/
│   └── script.dart              — 所有 Dart 数据模型（约2000行）
├── services/
│   ├── script_loader.dart       — JSON→GameScript 解析
│   ├── deepseek_client.dart     — DeepSeek API 调用+Prompt 构建（Two-step Prompting）
│   ├── world_engine.dart        — 世界时间/天气/季节推进+世界驱动
│   ├── rhythm_scheduler.dart    — ★节奏调度器（五路触发源→RhythmDirective + 反节奏检测）
│   ├── tension_vector.dart      — ★三维张力向量（relational/narrative/emotional）
│   ├── character_schedule.dart   — ★角色独立日程（查表/撞车/戏剧性评分+地点加成）
│   ├── character_memory_service.dart — ★角色记忆（core/episodic/decay 三层）
│   ├── inter_character_relationship.dart — ★角色间关系（亲和力/态度/嫉妒）
│   ├── information_propagation.dart — ★信息传播（碎片/加密/扩散）
│   ├── affection_engine.dart    — 好感度计算引擎
│   ├── relationship_engine.dart  — 关系状态机（8状态）
│   ├── event_scheduler.dart     — 事件调度（useRhythmLayer=false 时使用）
│   ├── game_session.dart        — 游戏会话主协调器
│   ├── phase_action_service.dart — 时段行动服务
│   ├── ranking_service.dart     — 排名系统
│   ├── plot_service.dart        — 剧情节拍判定
│   ├── calendar_service.dart    — 日历服务
│   ├── save_service.dart        — 存档读写
│   ├── initiative_service.dart   — 角色主动消息
│   └── narrative_compressor.dart — 叙事压缩
├── providers/
│   └── app_provider.dart        — 状态中枢
├── screens/
│   ├── sim_screen.dart          — 模拟主界面
│   ├── world_screen.dart        — 世界场景
│   ├── contacts_screen.dart     — 通讯录
│   ├── chat_screen.dart         — 1v1 聊天
│   ├── shop_screen.dart         — 商店
│   ├── settings_screen.dart     — 设置
│   └── ...                      — 其他屏幕
└── assets/
    └── scripts/
        └── campus_love.json     — 默认剧本「春日未央」
```

---

## 七、核心流程

### 7.1 应用启动
```
main() → AppProvider.init() → 从 SharedPreferences 恢复 API Key → 创建 DeepSeekClient
```

### 7.2 加载剧本
```
ScriptLoader.loadFromAsset() → json.decode() → GameScript.fromJson() → _initScript():
  ├── 初始化时间/天气/季节/十二时辰
  ├── 初始化 AffectionEngine（所有立体角色好感度=50）
  ├── 初始化 WorldEngine / RhythmScheduler / CharacterMemory
  ├── 初始化 RankingService / RelationshipEngine
  └── 加载世界摘要到叙事历史
```

### 7.3 日常推进 (daily) — v2.9 世界驱动统一

```
玩家点 [推进]
  → advanceTime() → 仅跳天数，不生成叙事
  → tickWorld()（每次推进都运行）
    ├── 日程撞车检测
    ├── 信息传播推进
    ├── 角色间关系动态
    └── LocationFrequencyTracker
  → worldReport = buildWorldReport(worldTick)（每次推进都生成）
  → _buildCoolingHints(day) →【关系冷却】注入 worldReport（v2.9 新增）
  → _buildMissedConnectionHints(tickReport) →【暗流·错过】注入 worldReport（v2.9 新增）
  → 选事件（可选种子，降级为可选输入）
  → rhythmScheduler.resolve() → RhythmDirective（每次都运行，不走旧裸路径）
  → DeepSeekClient.generateWorldNarrative ← Two-step Prompting
    ├── Step 1: _routeNarrative() → 路由决策 JSON
    └── Step 2: 裁剪后的 Prompt + 冷却提示 + 错过提示 → AI 生成叙事
  → 叙事返回 + modifyAffectionByEvent() + _recordInteractions(participants)
  → charMemory.recordEvent(tags 打标) → 记忆持久化
  → _longEventStepsRemaining > 0：继续生成选项
```

> **v2.9 关键变更**：旧版有两条路径（eventTemplate 路径和裸路径），裸路径跳过 rhombusScheduler 和 generateWorldNarrative。v2.9 统一为单一路径——eventTemplate 降级为可选种子，tickWorld + rhythmScheduler + generateWorldNarrative 每次都运行。

### 7.4 角色聊天
```
用户发消息 → _generateAiReply():
  → buildChatSystemPrompt(角色卡+好感度+世界状态+对话历史+memoryContext+rankingContext)
  → DeepSeekClient.generateChatReplyStreaming → 流式 AI 回复
  → modifyAffectionByChat() → recordChat()
```

### 7.5 自定义行动 (free)
```
用户输入行动 → customAction():
  → DeepSeekClient.generateCustomActionConsequence()
  → _parseCustomActionAffection() → modifyAffectionByEvent()
```

### 7.6 养成训练 (v2.7)
- 玩家点击「锻炼」→ 列出当前时辰可做的训练 → 选择 → 消耗 1 时段 → 属性/成绩增加 → AI 简述效果

### 7.7 跳过天数 (v2.7)
- 时间栏「跳过」按钮 → 输入 N 天 → 引擎逐天推进 → AI 生成摘要叙事 → 好感度自然漂移

### 7.8 十二时辰 (v2.7)
- 时段列表完全由剧本 `time_config.phases` 定义。每个时辰 = 1 行动点
- `skippable` 标记可跳过的睡眠时段。换修仙剧本只需改 JSON

---

## 八、好感度系统核心规则

- 精度 0.01，范围 1-100
- 区间内自由浮动，跨区间必须通过对应层级的事件
- 80 以下：临界事件通过即可跨
- 80：必须重要推进+长剧情事件
- 90：必须重要推进+剧情事件
- 100：终极事件，只能一人
- `difficulty_curve`：增益/衰减乘数
- `freeFallThreshold`：衰减下限保护
- `uniqueBond`：唯一羁绊（100 仅一人）

---

## 九、关系状态机（RelationshipEngine）

**8个状态**：none→stranger→acquaintance→friend→close_friend→crush→lover→partner

| 特性 | 机制 |
|------|------|
| 状态来源 | 好感度驱动，但破80需要告白事件 |
| 多恋人 | 支持，tracked：每个恋人 who knows about whom |
| 修罗场检测 | `hasMultiLovers()` + `characterKnowsAbout()` |
| 暴露惩罚 | 80-90区间: -10~-20; 90+区间: -15~-30 |

---

## 十、配置热替换

引擎通过 `ScriptRegistry` 管理多剧本：
```dart
ScriptRegistry().register('my_wuxia', 'assets/scripts/wuxia_world.json');
ScriptRegistry().activate('my_wuxia');
```
切换剧本即重新解析 JSON → 所有公式/属性池/角色池即时更新。存档按剧本 ID 隔离。

---

## 十一、存档兼容性

- 存档中携带 `scriptId` + `scriptName`
- 存档加载时校验剧本版本，不匹配则提示
- 剧本升级时需维护向后兼容的 `data_layer` 迁移

---

## 十二、改动影响分析速查

| 你想改什么 | 改哪里 | 要不要动代码 |
|---|---|---|
| 加一个新角色字段 | sim-script.json → script.dart | 是 |
| 改角色日程（几点去哪） | 剧本的 character.schedule | 否 |
| 改角色间初始关系 | 剧本的 inter_character_relationships | 否 |
| 调好感度曲线数值 | 剧本的 interaction.affection | 否 |
| 调礼物价格/好感加成 | 剧本的 items.list | 否 |
| 加一个新事件类型 | sim-script + script.dart + engine | 是 |
| 改信息加密风格/传播半径 | 剧本的 information_system | 否 |
| 改角色对话风格约束 | 剧本的 character.speech/humanity | 否 |
| 修 UI bug | 模拟器代码 | 是 |
| 加新功能 | 模拟器代码 + 可能需要 sim-script | 是 |
| 换一个完全不同的剧本 | 写新 JSON | 否 |

---

## 十三、已知技术细节

### 13.1 JSON 解析健壮性
- `_parseStringList()` 兜底：String 自动包成单元素 List
- `_safeParse()` / `_safeParseTop()` 兜底：任何层解析失败返回 null 不崩全局
- `GameInteraction.fromJson` 兼容 `advance_modes` 为数组或对象两种格式

### 13.2 DeepSeek API
- 端点：`https://api.deepseek.com/chat/completions`
- 模型：`deepseek-chat`
- 认证：`Bearer {apiKey}` Header
- API Key 存储在 SharedPreferences，应用启动时恢复

### 13.3 Flutter Web 构建
- 命令：`flutter build web --no-tree-shake-icons --no-source-maps`
- 静态资源在 `build/web/assets/assets/scripts/` 下

---

## 十四、世界驱动引擎（v2.3）

**核心概念：从"事件驱动"升级为"世界驱动"。**

| 事件驱动（旧） | 世界驱动（新） |
|---|---|
| 引擎等着玩家点"推进"，从池里选一个事件模板 | 角色在后台活着——有日程、有关系、有记忆、有信息差 |
| 修罗场 = 调度器选中了三角事件 | 修罗场 = 两个角色的日程撞上了同一条走廊 |

### 第一层：角色独立日程（CharacterScheduleService）
```
getCharacterLocation() → 返回角色此刻在哪个地点做什么
getAllLocations() → 所有立体角色此刻位置
detectCollisions() → 按地点分组检测撞车
pickDramaticCollision() → 按(好感度A×好感度B)/100 计算戏剧性分数
```

### 第二层：角色间关系（InterCharRelationshipService）
- 8级亲和力标签（死对头→挚友）
- onPlayerEvent / onWitness / onScheduleCollision → 自动亲和偏移

### 第三层：信息传播（InformationPropagationService）
- 5种加密风格（honest/joke/gossip/cold/speculation）
- 每次推进扩散1步 → 可信度衰减 ×0.85

### 引擎集成：WorldEngine.tickWorld()
每次推进时自动调用日程→撞车→角色间关系→信息传播，生成 WorldTickReport 注入 AI Prompt。

---

## 十五、v2.5 四层深化

### 15.1 角色层：记忆三层化
| 层 | 上限 | 衰减规则 | Prompt标签 |
|---|---|---|---|
| core（核心）| 8条 | 永不清洗 | 【她的记忆锚点】 |
| episodic（情景）| 10条 | 溢出→降级到decay | 【你们之间的重要时刻】 |
| decay（衰减）| 20条 | 溢出→自动丢弃 | 【最近的日常】 |

### 15.2 世界层：地点叙事属性
`SceneLocation` 新增 `LocationNarrativeProfile`：eventAffinity 加成系数 + narrativeKeywords。天台 × relationshipBeat=0.9，走廊 × tensionEscalation=0.7。

### 15.3 节奏层：三维张力拆解
`TensionVector` 三轴：relational / narrative / emotional。反节奏检测：`emotional > 0.6 && relational < 0.4` → 爆发。

### 15.4 生成层：Prompt 动态权重
`_trimForFocus` 按焦点裁剪角色档案段落长度。

---

## 十六、v2.6 时段行动系统

- 十二时辰，每时段 = 1 行动点
- 去别处 / 互动 / 度过 / 自定义 四种行动
- 渐进式角色发现（discovery_condition）
- 场景互动（每个地点有 narrative_profile → AI 生成场景描述）

---

## 十七、v2.7 十二时辰 + 养成系统 + 跳过天数

### 17.1 十二时辰
时段列表完全由剧本 `time_config.phases` 定义，每个时辰 = 1 行动点，`skippable` 标记可跳过时段。

### 17.2 养成训练系统
`data_layer.training.actions` 定义训练动作，玩家点击「锻炼」→ 选择训练 → 消耗时段 → 属性/成绩增加 + AI 简述效果。

### 17.3 跳过天数
输入 N 天 → 引擎逐天推进 → AI 生成摘要叙事 → 好感度自然漂移。

---

## 十八、v2.8 叙事质量提升 — 六项增量改进

> 前置：v2.7 核心闭环已打通（RhythmScheduler + TensionVector + CharacterMemory + generateWorldNarrative 全部接入 advance 流程）
> 目标：不改架构，在现有骨架上做增量提升，让 AI 叙事质量从"能看"到"有质"

### 18.1 Two-step Prompting（A+ 级）✅ 已实现

当前一次性把 3000+ 字数据塞进一个 Prompt，DeepSeek 注意力在长文本中不可靠。改为两阶段：

**Step 1：路由**（短 Prompt，~150 tokens 输出）
- 输入：情境摘要（2 行）+ 三维张力快照 + 最近事件
- 输出：主焦点 + 各角色意图（≤15 字）+ 叙事形状 + 基调 + 记忆标签
- 返回 JSON 结构化决策

**Step 2：生成**（用 Step 1 的决策裁剪 Prompt）
- 按焦点裁剪 Prompt 段落长度
- 注入叙事形状指令 + 张力快照 + 角色意图
- 路由失败时自动 fallback 到单步模式

### 18.2 Prompt 加权裁剪（A+ 级）✅ 已实现

根据 `RhythmDirective.primaryFocus` 动态调整各 Prompt 段落的字符配额：

| focus | 角色档案 | 世界状态 | 记忆 | 排名 | 信息传播 |
|-------|:--------:|:--------:|:----:|:----:|:--------:|
| characterMoment | 60% | 20% | 15% | 0% | 5% |
| relationshipBeat | 40% | 15% | 30% | 5% | 10% |
| plotAdvancement | 20% | 30% | 10% | 20% | 20% |
| worldTexture | 10% | 60% | 5% | 5% | 20% |
| tensionEscalation | 30% | 20% | 25% | 10% | 15% |
| ensembleScene | 35% | 25% | 15% | 5% | 20% |

### 18.3 三维张力注入 Prompt（A 级）✅ 已实现

`generateWorldNarrative` 新增 `tensionSnapshot` 参数，Prompt 中注入 TensionVector 快照：

```
【三维张力】
关系张力: 72/100 (↑ 上升 — 最近两次互动中好感度波动较大)
情节张力: 45/100 (→ 平稳)
情绪张力: 61/100 (↑ 上升 — 她被冷落了三天)
整体: 暗流涌动 [反节奏风险 — 情绪累积但关系冷淡]
```

### 18.4 日程频率感知（A 级）✅ 已实现

`LocationFrequencyTracker` 独立文件：
- **重复故意检测**：主角连续 N 天出现在某角色的常去地点 → 生成叙事钩子
- **规律打破检测**：某角色今天没有去她的日常地点 → 生成叙事钩子
- 数据通过 `world_engine.tickWorld()` 录制 → `buildFrequencyHooks()` → 注入 Prompt

### 18.5 记忆标签过滤（B+ 级）✅ 已实现

记忆条目增加 `tags` 字段，`buildMemoryContext` 增加 `filterTags` 参数：
优先返回含匹配 tag 的记忆，不足时用无 tag 的补齐。

| 标签 | 来源 |
|------|------|
| 考试 | ranking 事件 |
| 暧昧 | 好感度突破事件 |
| 吃醋 | interCharRel.onWitness |
| 共同经历 | 撞车事件 |
| 第三方提及 | 信息传播 |
| 冲突 | 好感度下降事件 |
| 日常 | decay 层默认 |
| 核心记忆 | core 层默认 |

路由 AI 输出 `relevant_tags` → `buildMemoryContext` 按标签过滤 → 注入到生成阶段 Prompt。

### 18.6 信息传播作为事件触发源（B 级）✅ 已实现

`RhythmScheduler._checkInfoSpread` 三层阈值触发：
1. 信息传播深度 ≥ 3
2. 信息包含敏感关键词（分数/排名/绯闻/秘密等）
3. 传播到好感度 ≥ 60 的角色
→ 触发 weight: medium，focus: relationshipBeat

敏感关键词从 `rhythm_config.info_spread_trigger.sensitive_keywords` 读取（JSON 可配置）

### 18.7 叙事形状指令（B- 级）✅ 已实现

路由决策中包含 `narrative_shape` 字段，Step 2 Prompt 中注入形状指令：

| 形状 | 适用场景 |
|------|----------|
| dialogue-heavy | 撞车、冲突、亲密 |
| montage | 跳过天数、日常推进 |
| reveal | 信息传播触发、秘密揭露 |
| tension-escalation | 冲突升级、反节奏 |
| quiet | 好感度平稳期的日常 |
| action-reaction | 突发场景事件 |

### 18.8 叙事格式重构（A 级）✅ 已实现

**核心问题**：AI 用"第二人称你"替玩家写了意图和动作，玩家只是旁观者。固定字数强制凑字数，叙事缺乏节奏感。

**重构后的格式规则**（在 `_buildWorldSystemPrompt` 注入到所有叙事生成的 System Prompt）：

| 规则 | 说明 |
|------|------|
| **不替玩家写意图** | 只写世界/环境/角色的行为与反应。不写"你决定走过去"、"你假装没看见"这类玩家还没说要做的事 |
| **可以写玩家动作的后果** | 允许写"你的脚步声在走廊里回响"、"你的巴掌十分大力"——这些是客观结果描写，不是意图 |
| **场景描写放括号** | 环境、氛围、动作描写放在 `（）` 里，与对白区分 |
| **对话单独成行** | 每个角色的对白占一行或多行，清晰可读 |
| **篇幅由情境决定** | 取消所有"300-500字"、"200-300字"等固定字数要求。简短反应可以只 2-3 行，复杂冲突写较长 |
| **宁短不凑** | 没东西可写就少写，不要为凑字数而写空洞描写 |

**影响范围**：`generateWorldNarrative` / `generateChoiceResponse` / `generateCustomActionConsequence` / `generateSceneEventNarrative` / `_buildWorldUserPrompt`（skip_days）全部同步。

### 18.9 全事件多回合（B+ 级）✅ 已实现

| 改动前 | 改动后 |
|--------|--------|
| `duration=short` → 选完就结束 | **所有事件**至少给 2 回合的选项循环 |
| 事件感 = 选择题 | 事件感 = 有来有回的"对话"|

实现：`game_session.dart` 中 `pickChoice` 后不再根据 `duration` 区分，所有事件统一走循环逻辑。普通事件默认 `_longEventStepsRemaining=2`，长事件用剧本定义的 `max_steps`。

---

**v2.8 汇总表（9 项增量改进，全部落地）**：

| # | 项目 | 等级 | 效果 |
|---|------|------|------|
| 18.1 | Two-step Prompting（路由→生成） | A+ | AI 不再被 3000 字淹没，先做决策再生成 |
| 18.2 | Prompt 加权裁剪 | A+ | 按 focus 动态分配字符配额 |
| 18.3 | 三维张力注入 | A | 张力快照注入 Prompt |
| 18.4 | 日程频率感知 | A | 检测主角重复/角色打破规律 |
| 18.5 | 记忆标签过滤 | B+ | 路由输出 relevant_tags → 过滤记忆 |
| 18.6 | 信息传播→事件触发 | B | 深度+关键词+高好感三层触发 |
| 18.7 | 叙事形状指令 | B- | 6 种形状指导写作风格 |
| 18.8 | 叙事格式重构 | A | 不替玩家写意图，括号+分行，灵活篇幅 |
| 18.9 | 全事件多回合 | B+ | 任何事件至少 2 回合循环 |

---

## 十九、v2.8 数据层扩展

### 19.1 剧本级 rhythm_config

```json
{
  "rhythm_config": {
    "narrative_shape_weights": {
      "dialogue_heavy": 0.3, "montage": 0.2, "reveal": 0.15,
      "tension_escalation": 0.2, "quiet": 0.1, "action_reaction": 0.05
    },
    "info_spread_trigger": {
      "min_depth": 3,
      "sensitive_keywords": ["分数", "排名", "好感", "绯闻", "秘密"],
      "high_affection_threshold": 60
    }
  }
}
```

### 19.2 剧本级 memory_config

```json
{
  "memory_config": {
    "tags": ["考试", "暧昧", "吃醋", "共同经历", "第三方提及", "冲突", "日常", "核心记忆"],
    "tag_match_boost": 2.0
  }
}
```

### 19.3 角色级 memory_tags

```json
{
  "characters": [{
    "memory_tags": {
      "default": ["日常"],
      "affection_breakthrough": ["暧昧"],
      "conflict": ["冲突"],
      "triangular": ["吃醋", "第三方提及"]
    }
  }]
}
```

---

## 二十、v2.9 世界驱动统一

> **动机**：v2.8 的 `advance()` 存在两条路径——有事件时走世界驱动全路径（tickWorld + rhythmScheduler + generateWorldNarrative），无事件时走旧裸路径（直接拿 result.narrative，没有世界数据注入）。导致日常推进中很多回合的叙事质量断崖下降。

### 20.1 核心改动

| 改动 | 旧 | 新 |
|------|----|----|
| 时间推进 | `worldEngine.advance()` 内部生成叙事 | `advanceTime()` 纯跳天数，叙事由 game_session 统一驱动 |
| tickWorld | 有事件时 2 次，无事件时 1 次 | **每次 1 次** |
| rhythmScheduler | 有事件时运行 | **每次都运行** |
| 叙事生成 | eventTemplate 路径 / 裸路径 二选一 | **统一走 generateWorldNarrative** |
| eventTemplate | 主驱动（决定用哪条路径） | 降级为可选种子（有则注入事件名和参与者） |

### 20.2 新增 WorldEngine 方法

```dart
AdvanceTimeResult advanceTime(String mode);
```

与 `advance()` 的时间跳转逻辑完全一致，但不生成叙事。`AdvanceTimeResult` 仅含 `dayBefore / dayAfter / daysSkipped`。

---

## 二十一、v2.9 场景交互改造

> **动机**：场景页签之前是摆设——角色是随机抽的（好感度 >50 随机选），点击角色弹窗看一眼就没了，没有"进入场景"的体验。

### 21.1 架构

```
SceneScreen（工具箱页签）
  ├── 数据源：events.sceneLocations（类型化 SceneLocation）
  ├── 在场角色：worldEngine.getCharactersAtLocation(locId)（日程实时查询，不再随机）
  └── 点击卡片 → Navigator.push → SceneInteractionScreen（全屏）

SceneInteractionScreen（新文件）
  ├── enterScene() → AI 生成场景氛围开场 + _generateChoices
  ├── actInScene() → AI 回应 + 追加全局叙事 [场景·地名] 前缀 + 好感度 + 记忆
  ├── leaveScene() → advancePhase() 消耗 1 时段 → Navigator.pop
  └── 场景内叙事：generateChoiceResponse / generateCustomActionConsequence
       （不走 generateWorldNarrative，场景是小空间对话张力）
```

### 21.2 四条设计原则

| 原则 | 实现 |
|------|------|
| **记忆全局存储** | 场景叙事加 `[场景·琴房]` 前缀写入 `_narrativeHistory`，好感度走 `charMemory.recordEvent` |
| **离开消耗时段** | `leaveScene()` → `worldEngine.advancePhase()` + 时间同步 |
| **日程感知** | 角色出现由日程引擎实时查，不再是随机缓存 |
| **入口在工具箱** | SceneScreen 页签不变，点击卡片进入全屏交互页 |

### 21.3 现有入口

- SceneScreen：全部 `events.sceneLocations`，日程引擎实时查人
- WorldScreen "去别处"：仍然用 `world.locations`（字典列表），预览 + 行动
- 邀请横幅：角色随机约你去某地（好感度 >65）

### 21.4 新增文件

| 文件 | 用途 |
|------|------|
| [scene_interaction_screen.dart](file:///d:/AR/love_sim/lib/screens/scene_interaction_screen.dart) | 全屏场景交互页面（~380 行）|
| [deepseek_client.dart](file:///d:/AR/love_sim/lib/services/deepseek_client.dart) 的 `generateSceneAtmosphere()` | 场景氛围开场生成（~55 行）|
| [game_session.dart](file:///d:/AR/love_sim/lib/services/game_session.dart) 的 `enterScene/actInScene/leaveScene` | 场景交互三剑客（~160 行）|

---

## 二十二、v2.9 被动张力 + 互斥张力

> **动机**：现有惩罚体系（行为界限 -5、表白界限 -3、话题禁忌 -3）只覆盖"做错"，不覆盖"不做"和"选了 A 没选 B"。

### 22.1 被动张力：关系自然冷却

`_buildCoolingHints(day)` — 每次推进扫描所有角色：

| 条件 | 衰减 | 叙事提示 |
|------|:--:|------|
| ≥6 天未互动 | -0.3 | "你有 N 天没见过 XX 了" |
| ≥12 天未互动 | -0.5 | "XX 已经太久没有出现在你的视线里了。你们之间隔了 N 天" |

冷却不影响 ≤5 天内的互动记录。提示注入 `worldReport`，随 `generateWorldNarrative` 进入 Prompt。

### 22.2 互斥张力：在场未遇

`_buildMissedConnectionHints(tickReport)` — 每次推进扫描日程引擎：

- 好感度 >20 且 >3 天未互动的角色
- 该角色此刻在一个有日程碰撞的地点
- 但你不在那个碰撞中 → **角色在同一个地方，你的注意力在别处**

提示："XX 也在琴房，但你的注意力在别处。"

### 22.3 互动登记

与好感度系统解耦的**独立记录机制**：`_lastInteractionDay[charId]`。在 6 个入口登记：`advance` / `pickChoice` / `customAction` / `sendMessage` / `sendGift` / `actInScene`。

### 22.4 数据流

```
每次推进：
  tickWorld → worldReport
    → _buildCoolingHints: 检查所有人的冷却 → 注入 worldReport
    → _buildMissedConnectionHints: 检查错过 → 注入 worldReport
    → rhythmScheduler + generateWorldNarrative
    → AI 在叙事里自然吸收这些提示

每次互动：
  pickChoice / customAction / chat / gift / scene
    → _recordInteraction(id) 重置冷却计时
```

---

## 二十三、创建新剧本检查清单

- [ ] 定义 `data_layer.stats`（属性池）
- [ ] 定义 `data_layer.grades`（成绩池）
- [ ] 定义 `data_layer.grade_formulas`（每科公式）
- [ ] 定义 `data_layer.natural_growth_rate`
- [ ] 定义 `data_layer.ranking`（总人数 + 考试事件）
- [ ] 定义 `rhythm_config`（节奏层配置）
- [ ] 定义 `memory_config`（记忆系统配置）
- [ ] 为每个 full_character 填写 `stats`、`grades`、`memory_tags`
- [ ] 确保所有 ID 在 stat/grades/formula 三层之间一致引用
- [ ] **不要修改任何 .dart 文件**

---

## 二十四、文件索引

| 文件 | 用途 |
|---|---|
| [sim-script.json](file:///d:/AR/sim-script.json) | 工业模板——所有字段定义和注释 |
| [script.dart](file:///d:/AR/love_sim/lib/models/script.dart) | Dart 数据模型（约2000行） |
| [game_session.dart](file:///d:/AR/love_sim/lib/services/game_session.dart) | 游戏会话主协调器 |
| [deepseek_client.dart](file:///d:/AR/love_sim/lib/services/deepseek_client.dart) | AI 调用 + Two-step Prompting + generateSceneAtmosphere |
| [world_engine.dart](file:///d:/AR/love_sim/lib/services/world_engine.dart) | 世界时间/天气/推进 + WorldTickReport + advanceTime |
| [rhythm_scheduler.dart](file:///d:/AR/love_sim/lib/services/rhythm_scheduler.dart) | ★节奏调度器 — 五路触发源 + 反节奏检测 |
| [tension_vector.dart](file:///d:/AR/love_sim/lib/services/tension_vector.dart) | ★三维张力向量 |
| [affection_engine.dart](file:///d:/AR/love_sim/lib/services/affection_engine.dart) | 好感度计算引擎 |
| [relationship_engine.dart](file:///d:/AR/love_sim/lib/services/relationship_engine.dart) | 关系状态机 |
| [character_memory_service.dart](file:///d:/AR/love_sim/lib/services/character_memory_service.dart) | ★角色记忆三层化 |
| [character_schedule.dart](file:///d:/AR/love_sim/lib/services/character_schedule.dart) | ★角色日程服务 |
| [inter_character_relationship.dart](file:///d:/AR/love_sim/lib/services/inter_character_relationship.dart) | ★角色间关系服务 |
| [information_propagation.dart](file:///d:/AR/love_sim/lib/services/information_propagation.dart) | ★信息传播服务 |
| [phase_action_service.dart](file:///d:/AR/love_sim/lib/services/phase_action_service.dart) | 时段行动服务 |
| [ranking_service.dart](file:///d:/AR/love_sim/lib/services/ranking_service.dart) | 排名系统 |
| [plot_service.dart](file:///d:/AR/love_sim/lib/services/plot_service.dart) | 剧情节拍判定 |
| [script_loader.dart](file:///d:/AR/love_sim/lib/services/script_loader.dart) | JSON 解析入口 |
| [save_service.dart](file:///d:/AR/love_sim/lib/services/save_service.dart) | 存档服务 |
| [app_provider.dart](file:///d:/AR/love_sim/lib/providers/app_provider.dart) | 状态中枢 |
| [scene_interaction_screen.dart](file:///d:/AR/love_sim/lib/screens/scene_interaction_screen.dart) | ★v2.9 场景交互全屏页面 |
| [campus_love.json](file:///d:/AR/love_sim/assets/scripts/campus_love.json) | 默认剧本「春日未央」 |
| [_template.json](file:///d:/AR/love_sim/assets/scripts/_template.json) | 剧本模板 |

---

## 二十五、待实施项目

> v2.8 的 9 项增量改进 + v2.9 的 3 项架构改进已全部落地。

```
✅ 世界驱动统一 — advance() 统一为单一路径，裸路径已删除
✅ 场景交互改造 — SceneInteractionScreen 全屏交互 + 日程实时查询 + 记忆全局存储
✅ 被动/互斥张力 — 关系冷却（6/12天阈值）+ 在场未遇（日程碰撞感知）
```

**下一个版本（v2.10）考虑方向**（讨论中，待确定）：
- 叙事模板化：为高频场景（偶遇、独处、第三方介入）提供可复用的 JSON 叙事骨架
- 角色主动消息优化（目前 initiative_service 只有简单触发）
- 信息碎片发现系统：JSON 里埋秘密，unlock_condition 驱动玩家从不知道到知道