# Love Sim — 工业化剧本模拟器 项目策划文档

## 一、项目定位

这是一个**剧本驱动的恋爱模拟引擎**。核心思路：

- 写一份符合规范的 JSON 剧本 → 模拟器自动跑出一个完整世界
- 不局限于校园恋爱——换一个结构一致的剧本就能模拟古风、科幻、悬疑等任何题材
- DeepSeek API 驱动 AI 叙事，人物行为不靠脚本硬写，而是靠角色模型约束 AI 生成

---

## 二、三层架构

| 层 | 是什么 | 谁改 | 什么时候改 |
|---|---|---|---|
| **sim-script.json** | 工业模板——定义所有字段的数据结构和语义 | 策划 / 剧本作者 | 引擎需要新的数据维度时（如"角色现在需要体型数据"） |
| **模拟器** | Dart/Flutter 代码——JSON→对象→引擎运转→UI | 开发 | 修 bug、加引擎功能、改 UI |
| **剧本** (.sim / .json) | 按 sim-script 格式填写的具体剧本内容 | 剧本作者 | 写新剧本、调平衡 |

**关键原则**：
1. 换剧本不需要改一行代码——只要 JSON 结构对齐 `sim-script.json`
2. 改模板结构必须同步改 Dart 模型和引擎
3. 调数值（好感度曲线、物品价格等）只改剧本，不动代码

---

## 三、剧本结构（十一层）

### 3.1 meta — 元信息
剧本的身份证：id、名称、版本、作者、类型、基调、模式(endings/sandbox)、摘要。

### 3.2 player — 主角
- **剧本只定义背景和处境**：`background`（成长史）和 `current_state`（开局心境）
- **基础信息来自玩家角色卡**：名字、性别、身高、生日、外貌描述、性格描述 → 由玩家在「我的」页编辑
- 名字/外貌/性格**不在剧本 JSON 中预设**
- `playerCardForAi` 运行时拼接：玩家角色卡 + 剧本 background + 剧本 current_state → 注入 AI System Prompt

### 3.3 world — 世界观
```
world
├── summary        — 世界快照（约200-300字）
├── setting        — 完整世界观（1000-3000字，直接注入 AI System Prompt）
├── atmosphere     — 氛围（base_mood / color_palette / hint）
├── locations[]    — 地点列表（id/name/desc/visibility/可用时段/场景氛围/事件提示）
├── special_rules  — 剧本类型差异化规则（校园空、诡异有限制、系统有面板）
└── memory         — 运行时状态（当前时间/地点变化/世界历史/世界摘要）
```

### 3.4 characters — 角色
角色分两种：
- **立体角色**（full_character=true）：27 个子字段，全面控制 AI 行为
- **平面角色**（full_character=false）：一段 summary，只出现在叙事中

立体角色的 27 个字段及其对 AI 的影响：

| 字段 | 对 AI 的影响 | 类型 |
|---|---|---|
| **basic** | 外貌、身高、体型、标记——AI 描述外观的依据 | 事实 |
| **background** | 出身、成长史、当前处境——AI 理解角色动机 | 事实 |
| **details** | 习惯、日常、癖好、秘密爱好——AI 写日常行为的依据 | 行为 |
| **soul** | 核心价值观、欲望、创伤、恐惧、矛盾、双模式(对生人/对熟人)——AI 把握角色本质 | 内核 |
| **speech** | 大五人格、语音学(音高/语速/重音/停顿)、词汇(风格/句式/禁用词/软化词)、互动(话轮/礼貌/提问/话题控制)、双模式 | 语言 |
| **relations** | 固定关系(flat) + 维度关系(dimensional,按好感度区间变化) | 关系 |
| **agent** | 角色定位、行动目标、双模式行为 | 行为 |
| **humanity** | 反AI规则(不自我解释/不情感标注/不安全包裹/非结构化/非均匀注意力)、写作姿态(沉默即言语/允许偏见/允许不完整/情感藏于动作)、非语言行为列表 | 人性 |
| **appearance** | 默认穿着、特殊穿着、风格描述 | 外观 |
| **preferences** | 喜欢/厌恶/才能 | 偏好 |
| **mood_triggers** | 喜怒哀惊妒的触发器 | 情绪 |
| **gift_response** | love/like/neutral/dislike/hate 五档礼物反应 | 礼物 |
| **boundary** | 身体距离、情感边界、话题禁区、亲密度节奏 | 边界 |
| **conduct** | 红线、性命攸关规则、灰色地带(嫉妒/沮丧/试探)、自我纠正方式 | 行为规则 |
| **evolution** | 好感度11个区间各阶段描述、成长弧线 | 进化 |
| **memory** | 情景记忆、聊天日志、印象（关键词/趋势）| 记忆 |
| **schedule** ★新增 | 角色独立日程（weekday/weekend，时段→地点→活动+优先级+条件）| 世界 |

### 3.4A inter_character_relationships — 角色间关系 ★新增★
不再只有玩家↔角色好感度。角色之间也有数据：

```
inter_character_relationships
├── initial_attitudes[]  — 初始角色间态度（from/to/affinity/label/history）
├── affinity_states      — 8级亲和力标签（死对头→挚友，-100~100）
└── triggers             — 变化触发器
    ├── on_player_event   — 玩家事件涉及2+角色→角色间亲和偏移
    ├── on_schedule_collision — 日程撞车→微小亲和偏移
    ├── on_witness        — 目睹亲密互动→嫉妒→降低对被目击方的亲和力
    └── on_info_spread    — 信息传播→加密风格影响亲和偏移方向
```

**关键原理**：苏念晚对温辞从友善变成疏离、温辞察觉后回避走廊、陆迟和江屿川在球场上有了关于你的对话——全是连锁反应，全由数据驱动。

### 3.4B information_system — 信息传播系统 ★新增★
不是所有人都立刻知道所有事。消息有延迟、失真、加密：

```
information_system
├── encryption_styles    — 5种加密风格(honest/joke/gossip/cold/speculation)
├── visibility_rules     — 事件可见度决定谁自动成为见证人
└── fragment_schema      — 信息碎片结构(source_event/witness/content/encryption/
                           spread_radius/known_by/trustworthiness/spread_count)
```

**传播流程**：事件发生 → 旁观者成为见证人 → 信息碎片创建 → 每次推进扩散1步 → 已知者→未知者 → 内容被加密扭曲 → 可信度衰减。

### 3.5 plot — 剧情
不是预写的故事，是给 AI 的"方向指令"：

```
plot
├── summary / premise      — 剧情快照 + 一句话故事前提
├── acts[]                 — 幕（id/名称/描述/阶段区间/出入条件/叙事方向/基调/节拍列表/节奏权重）
├── beats[]                — 剧情节拍（触发条件+AI方向+结果+优先级+是否一次性+是否记忆）
├── endings[]              — 结局定义（条件+AI方向+类型）
├── narrative_tension      — 叙事张力曲线（低/中/高张力→AI不同写法）
├── branch_system          — 路线追踪（不同角色线）
├── foreshadow_system      — 伏笔系统（埋→回收）
├── post_ending            — 结局后世界（继续日常但无主线）
└── memory                 — 运行时（当前幕/已触发节拍/伏笔/结局进度）
```

### 3.6 events — 事件

事件分两种长度：

| 类型 | duration | 行为 |
|---|---|---|
| **短事件** | `"short"` (默认) | 生成叙事 → 弹出选项 → 选完结束 |
| **长事件** | `"long"` | 生成叙事 → 弹出选项 → 选完继续 → 再弹选项 → 直到 `max_steps` 轮结束 |

`EventTemplate` 新增字段：
- `duration`：`"short"` 或 `"long"`，默认 `"short"`
- `max_steps`：长事件的最大选择轮数（1-5，默认3）

14 种事件池，每种有不同的触发逻辑：

| 池 | 说明 | 触发条件 |
|---|---|---|
| **plot** | 剧情事件 | 重要推进主导 |
| **boundary** | 临界好感事件 | 好感度到达区间边界时 |
| **daily** | 日常事件 | 日常推进高频 |
| **sweet_minor** | 小甜蜜 | 好感≥80 |
| **sweet_major** | 大甜蜜里程碑 | 好感≥80 + 冷却 |
| **love_triangle** | 修罗场 | ≥2个角色好感≥60 |
| **reversal** | 反转 | chaos≥0.5 |
| **echo** | 回声（callback旧记忆）| 有相关记忆时 |
| **misunderstanding** | 误会 | 信息不对称 |
| **ensemble** | 群像 | ≥2角色在场 |
| **world_shift** | 世界变迁 | 季节/地点/节日变化 |
| **forced_choice** | 强制选择 | 关键剧情节点 |
| **resource** | 资源获得 | 日常推进 |
| **dialogue_trigger** | 对话触发 | 事件后/好感里程碑 |

辅助系统：butterfly（蝴蝶效应种子）/ tension_field（关系张力场）/ conditions（条件匹配）/ chains（事件链）

### 3.7 dialogue — 对话
三个引擎驱动：
- **world_sim** — 主世界叙事引擎（用户点推进→生成事件叙事）
- **character_chat** — 角色对话引擎（用户和角色1v1聊天）
- **compressor** — 上下文压缩（定期压缩长历史为摘要）

每类角色按好感度分双模式（对生人/对熟人），注入完整角色卡 + speech 字段约束。

### 3.8 items — 物品
- currency：货币系统（多币种支持）
- list：物品列表（gift/key_item/consumable/collectible 四类）
- shop：商店（商品池+刷新规则+特殊商品）
- gifting：送礼规则（冷却/五档反应/唯一礼物/连续送礼衰减）
- crafting：合成（可选）

### 3.9 interaction — 交互

```
interaction
├── time_config       — 时间推进配置（时段列表/单位/特殊日）
├── advance_modes     — 三种推进模式
│   ├── daily  — 日常推进（1时段，轻量事件，好感自由浮动）
│   ├── major  — 重要推进（2-4时段，剧情事件，破阶关键）
│   └── free   — 自定义行动（玩家自由输入，AI裁定后果，0-1时段）
├── seasons[]         — 季节阶段（天气池/持续天数）
├── weather_system    — 天气概率/效果
├── affection         — 好感度系统（核心）
│   ├── boundery_events   — 临界事件机制
│   ├── tier_breakthrough — 破阶规则
│   ├── difficulty_curve  — 难度曲线（增益/衰减乘数）
│   ├── decline_rules     — 衰减规则
│   ├── tiers_desc        — 梯度描述
│   └── unique_bond       — 唯一羁绊（100仅一人）
├── chat              — 聊天好感参数
├── messages          — 消息系统配置
├── pace              — 节奏
├── context_management — 上下文窗口管理
└── memory            — 运行时状态
```

**好感度核心规则**：
- 精度 0.01，范围 1-100
- 区间内自由浮动，跨区间必须通过对应层级的事件
- 80 以下：临界事件通过即可跨
- 80：必须重要推进+长剧情事件
- 90：必须重要推进+剧情事件
- 100：终极事件，只能一人

---

## 四、模拟器代码结构

```
love_sim/lib
├── main.dart                    — 入口+主题+全局组件
├── models/
│   └── script.dart              — 所有 Dart 数据模型（约1700行）
├── services/
│   ├── script_loader.dart       — JSON→GameScript 解析
│   ├── deepseek_client.dart     — DeepSeek API 调用+所有 System Prompt 构建
│   ├── world_engine.dart        — 世界时间/天气/季节推进+叙事生成+世界驱动
│   ├── character_schedule.dart   — ★角色独立日程（查表/撞车/戏剧性评分）
│   ├── inter_character_relationship.dart — ★角色间关系（亲和力/态度/嫉妒）
│   ├── information_propagation.dart — ★信息传播（碎片/加密/扩散）
│   ├── affection_engine.dart     — 好感度计算引擎（破阶/衰减/难度曲线）
├── providers/
│   └── app_provider.dart        — 状态中枢（约800行，协调所有引擎+UI状态）
├── screens/
│   ├── root_screen.dart         — 底部导航框架
│   ├── scripts_screen.dart      — 剧本管理（加载/导入/删除）
│   ├── sim_screen.dart          — 模拟主界面（推进+叙事展示）
│   ├── world_screen.dart        — 世界观/场景总览
│   ├── contacts_screen.dart     — 通讯录（角色列表+快捷交流）
│   ├── chat_screen.dart         — 1v1 聊天
│   ├── shop_screen.dart         — 商店
│   ├── settings_screen.dart     — 设置（API Key/外观/背景）
│   ├── character_profile_screen.dart — 角色档案
│   ├── scene_screen.dart        — 场景事件
│   └── sim_profile_screen.dart  — 玩家状态
└── assets/
    └── scripts/
        └── campus_love.json     — 默认剧本「春日未央」
```

---

## 五、核心流程

### 5.1 应用启动
```
main() → AppProvider.init() → 从 SharedPreferences 恢复 API Key → 创建 DeepSeekClient
```

### 5.2 加载剧本
```
用户点击剧本 → ScriptLoader.loadFromAsset()
  → json.decode() → 逐层解析（meta/player/world/characters/items/interaction...）
  → GameScript.fromJson()
  → _initScript():
      ├── 初始化时间/天气/季节
      ├── 初始化 AffectionEngine（所有立体角色好感度=50）
      ├── 初始化 WorldEngine（如果 DeepSeekClient 存在）
      ├── 初始化货币（金币=50）
      └── 加载世界摘要到叙事历史
```

### 5.3 日常推进 (daily)
```
用户点击"日常推进"
  → tickTension() — 更新叙事张力
  → checkBeatTriggers() — 检查剧情节拍触发条件
  → selectEventTemplate() — 从 daily 事件池中选一个事件
  → DeepSeekClient.generateEventNarrative() — AI 生成叙事
  → 存入 narrativeHistory / narrativeSegments
  → 更新世界状态（时间/天气/好感度）
```

### 5.4 重要推进 (major)
```
用户点击"重要推进"
  → 类似日常推进，但从 major 事件池选事件
  → 可触发 plot / forced_choice / world_shift 等
  → 可突破好感度 80 边界
```

### 5.5 角色聊天
```
用户发消息 → ChatMessage 添加到历史
  → _generateAiReply():
      检查 DeepSeekClient 是否存在
      → _buildChatSystemPrompt(角色卡+当前好感度+世界状态+对话历史)
      → _callApi(userPrompt=用户消息)
      → analyzeAffectionDelta() — AI 分析本次互动的好感度变化
      → 更新好感度
```

### 5.6 自定义行动 (free)
```
用户输入行动（如"给林晓雨写一封信"）
  → app.customAction(action)
  → DeepSeekClient.generateCustomActionConsequence()
      输入：玩家角色卡 + 世界观 + 当前场景 + 角色好感度 + 完整角色档案 + 最近剧情
      输出：300-500字叙事 + [affection:角色id:+或-数字] 标记
  → _parseCustomActionAffection() 解析标记
  → 修改好感度
  → 自动存档
```

### 5.7 好感度变化
```
modifyAffectionByChat() — 聊天变化（不破阶，区间内浮动）
modifyAffectionByEvent() — 事件变化（可破阶）
  → 查 difficulty_curve 乘数
  → 应用盈亏
  → 检查是否到达临界点
  → 到达→触发 boundery_event
```

### 5.8 长事件多轮选择
```
短事件: advance → narrative → choices → pick → 结束
长事件: advance → narrative → choices → pick → continue → choices → pick → ...(max_steps轮) → 结束
```
长事件由 `EventTemplate.duration == 'long'` + `max_steps` 控制。
`generateChoiceResponse(isContinuation: true)` 让 AI 在叙事末尾留悬念，
`pickChoice()` 在第 N 轮后自动调用 `_generateChoices()` 生成下一轮选项。

### 5.9 模拟页操作栏
```
┌────────────────────────────────────────┐
│ [晓] [雨] [薇] │ [日常] [推进] [✎]  │
│ (输入自定义行动…)  [执行]           │  ← 点击 ✎ 展开
└────────────────────────────────────────┘
```
角色头像 + 操作按钮合并为一行紧凑操作栏，不再拆分三层。

---

## 六、改动影响分析速查

| 你想改什么 | 改哪里 | 要不要动代码 |
|---|---|---|
| 加一个新角色字段（如"星座"） | sim-script.json → script.dart | 是 |
| 改角色日程（几点去哪） | 剧本的 character.schedule | 否 |
| 改角色间初始关系 | 剧本的 inter_character_relationships.initial_attitudes | 否 |
| 调好感度曲线数值 | 剧本的 interaction.affection | 否 |
| 调礼物价格/好感加成 | 剧本的 items.list | 否 |
| 加一个新事件类型（如"噩梦"） | sim-script + script.dart + world_engine/app_provider | 是 |
| 改信息加密风格/传播半径 | 剧本的 information_system | 否 |
| 改角色对话风格约束 | 剧本的 character.speech/humanity | 否 |
| 修 UI bug（按钮不生效等） | 模拟器代码 | 是 |
| 加新功能（如日记系统） | 模拟器代码 + 可能需要 sim-script | 是 |
| 换一个完全不同的剧本 | 写新 JSON | 否（结构对齐即可） |
| 剧本中某字段是字符串但模型要数组 | 改 sim-script 统一规范，或加 _parseStringList 兜底 | 视情况 |

---

## 七、已知技术细节

### 7.1 JSON 解析健壮性
- 剧本来自不同作者，格式可能不完全一致
- `_parseStringList()` 兜底：String 自动包成单元素 List
- `_safeParse()` / `_safeParseTop()` 兜底：任何层解析失败返回 null 不崩全局
- `GameInteraction.fromJson` 兼容 `advance_modes` 为数组或对象两种格式

### 7.2 Flutter Web 构建
- 命令：`flutter build web --no-tree-shake-icons --no-source-maps`
- 静态资源在 `build/web/assets/assets/scripts/` 下
- 本地服务器：`serve.ps1`（PowerShell HTTP Listener，端口 8765）

### 7.3 DeepSeek API
- 端点：`https://api.deepseek.com/chat/completions`
- 模型：`deepseek-chat`
- 认证：`Bearer {apiKey}` Header
- API Key 存储在 SharedPreferences，应用启动时恢复

### 7.4 Provider 状态管理
- `AppProvider` 是全局唯一状态中枢
- `notifyListeners()` → Consumer Widget 刷新
- 所有引擎和状态变量都在 AppProvider 内部

---

## 八、文件索引

| 文件 | 用途 |
|---|---|
| [sim-script.json](file:///d:/AR/sim-script.json) | 工业模板——所有字段定义和注释 |
| [script.dart](file:///d:/AR/love_sim/lib/models/script.dart) | Dart 数据模型（~1000行） |
| [app_provider.dart](file:///d:/AR/love_sim/lib/providers/app_provider.dart) | 状态中枢（~1200行） |
| [deepseek_client.dart](file:///d:/AR/love_sim/lib/services/deepseek_client.dart) | AI 调用 + Prompt 构建（~720行） — generateEventNarrative 支持 freeform 参数 |
| [world_engine.dart](file:///d:/AR/love_sim/lib/services/world_engine.dart) | 世界时间/天气/推进（~300行） |
| [affection_engine.dart](file:///d:/AR/love_sim/lib/services/affection_engine.dart) | 好感度系统（~370行） |
| [relationship_engine.dart](file:///d:/AR/love_sim/lib/services/relationship_engine.dart) | 关系状态机（~210行） |
| [event_scheduler.dart](file:///d:/AR/love_sim/lib/services/event_scheduler.dart) | 事件调度引擎（~310行） — 含 pickFreeformContext |
| [character_schedule.dart](file:///d:/AR/love_sim/lib/services/character_schedule.dart) | ★角色日程服务 — 日程查表/撞车检测/戏剧性评分（~140行） |
| [inter_character_relationship.dart](file:///d:/AR/love_sim/lib/services/inter_character_relationship.dart) | ★角色间关系服务 — 亲和力追踪/态度标签/嫉妒触发（~180行） |
| [information_propagation.dart](file:///d:/AR/love_sim/lib/services/information_propagation.dart) | ★信息传播服务 — 信息碎片/5种加密风格/传播扩散（~170行） |
| [script_loader.dart](file:///d:/AR/love_sim/lib/services/script_loader.dart) | JSON 解析入口（含逐层诊断） |
| [save_service.dart](file:///d:/AR/love_sim/lib/services/save_service.dart) | 存档服务（读写+ChatMessage模型） |
| [plot_service.dart](file:///d:/AR/love_sim/lib/services/plot_service.dart) | 剧情节拍判定服务 |
| [initiative_service.dart](file:///d:/AR/love_sim/lib/services/initiative_service.dart) | 角色主动消息+邀请服务 |
| [campus_love.json](file:///d:/AR/love_sim/assets/scripts/campus_love.json) | 默认剧本「十七岁的坐标系」 |

---

## 八、游戏引擎底层实现

### 8.1 整体架构（v2.3 — 世界驱动引擎）

```
UI层（屏幕/Widget）
    ↓
Provider层（AppProvider）— UI状态 + 服务引用
    ↓
┌───────────────── 服务层（lib/services/） ──────────────────────┐
│                                                                  │
│  WorldEngine        EventScheduler     AffectionEngine          │
│  时间/天气/世界驱动  事件选择/节拍      好感度区间/突破           │
│                                                                  │
│  CharacterSchedule  InterCharRel       InfoPropagation          │
│  ★角色独立日程      ★角色间关系         ★信息传播               │
│                                                                  │
│  RelationshipEngine  DeepSeekClient     PlotService             │
│  关系状态机           AI调用+P构建      剧情节拍判定             │
│                                                                  │
│  SaveService         InitiativeService  ScriptLoader             │
│  存档读写            角色主动消息        剧本解析                │
│                                                                  │
│  NarrativeCompressor                                                 │
│  叙事压缩/上下文管理                                                │
│                                                                  │
└──────────────────────────┬───────────────────────────────────────┘
                           ↓
AI层（DeepSeek 大模型 → 生成叙事/对话/选项）
```

**协议统一（2026-06-13）：**
- `sim-script.json` 是字段名唯一标准，campus_love.json 和 script.dart 严格遵循
- 模板字段 `non_verbal / physical / emotional / topic_taboo / pace_hint` 三者一致
- `CharacterDetails` 扩展为双格式兼容（campus_love 的 goals/fears/secrets/quirks 全量保留）
- `CharacterAppearance` 扩展为详细格式（body/face/hair/eyes/clothing 不再丢失）
- fromJson 中移除了所有 `?? json['旧字段名']` fallback 代码
- `ChatMessage` 移到 save_service.dart，app_provider 从服务导入

**职责分层（2026-06-13）：**
- `SaveService` 替代 app_provider 内嵌的存档逻辑
- `PlotService` 替代 app_provider 内嵌的节拍判定/张力管理
- `InitiativeService` 替代 app_provider 内嵌的角色主动消息/邀请系统
- `EventScheduler.pickParticipants` 计算结果注入 AI Prompt，大模型知道场上角色

### 8.1A 世界驱动引擎（World-Driven Engine）— v2.3 ★新增★

**核心概念：从"事件驱动"升级为"世界驱动"。**

| 事件驱动（旧） | 世界驱动（新） |
|---|---|
| 引擎等着玩家点"推进"，从池里选一个事件模板 | 角色在后台活着——有日程、有关系、有记忆、有信息差 |
| 丰富度上限 = 事件池里的模板数量 | 丰富度 = 角色日程 × 关系状态 × 信息传播网络的组合 |
| 修罗场 = 调度器选中了三角事件 | 修罗场 = 两个角色的日程撞上了同一条走廊 |
| "被安排的场景" | "汇报此刻世界正在发生的最值得看的事" |

#### 第一层：角色独立日程（CharacterScheduleService）

```
character_schedule.dart
├── CharacterScheduleService.getCharacterLocation(角色, 天, 时段, 季节, 天气) → 返回该角色此刻在哪个地点做什么
├── getAllLocations() → 查所有立体角色此刻的位置
├── detectCollisions() → 按地点分组，检测撞车(≥2角色同地点)
├── pickDramaticCollision() → 按(好感度A×好感度B)/100计算戏剧性分数，选最值得写的撞车
└── findCollision() → 如果玩家在当前地点，检测是否有角色也在这里
```

**日程数据结构**（在 character.schedule 中定义）：
```json
{
  "weekday": [{"phase":"放学","location":"piano_room","activity":"练琴","priority":90,"conditions":["weekday"]}],
  "weekend": [{"phase":"上午","location":"library_3f","activity":"自习","priority":60}]
}
```
每个角色有 weekday（工作日）和 weekend（周末）两套日程。时段名与 `time_config.phases` 对齐。

**撞车示例**：
- 放学·校门口：苏念晚(等) + 江屿川(闲聊) → 青梅竹马撞车
- 课间·走廊：苏念晚(巡查) + 江屿川(活跃) → 高频
- 傍晚·旧球场：陆迟(打球) + 江屿川(经过) → 体育系撞车

#### 第二层：角色间关系（InterCharRelationshipService）

```
inter_character_relationship.dart
├── InterCharRelationshipService
│   ├── initFromScript() → 初始化所有角色对之间的态度(默认"无感")
│   ├── shiftAffinity(from, to, delta) → 修改亲和力(-100~100)
│   ├── onPlayerEvent(参与角色, 好感度, 记录) → 玩家事件中涉及的2+角色间自动产生互动
│   ├── onWitness(目击者, 角色A, 角色B, 好感度) → 目睹亲密互动→嫉妒→亲和下降
│   ├── detectDrama() → 输出当前关系动态文案
│   └── buildContextForPrompt() → 注入AI Prompt
│
├── InterCharAttitude (数据模型)
│   ├── fromCharId / toCharId → 方向
│   ├── affinity → 亲和力 (-100~100)
│   ├── label → 自动计算标签(死对头/厌恶/疏离/无感/认识/友善/好友/挚友)
│   └── history → 互动历史摘要
```

**亲和力分级**：
| 标签 | 亲和力范围 |
|---|---|
| 死对头 | -100 ~ -60 |
| 厌恶 | -60 ~ -30 |
| 疏离 | -30 ~ -10 |
| 无感 | -10 ~ 10 |
| 认识 | 10 ~ 30 |
| 友善 | 30 ~ 60 |
| 好友 | 60 ~ 85 |
| 挚友 | 85 ~ 100 |

**触发机制**：
- `onPlayerEvent`：玩家事件涉及2+角色 → 角色间亲和偏移±(0~5)。两人都对玩家好感>70时偏移更大。
- `onWitness`：目睹亲密互动 → 嫉妒 → 对被目击方亲和下降。
- `onScheduleCollision`：日程撞车 → 微小亲和偏移。

#### 第三层：信息传播（InformationPropagationService）

```
information_propagation.dart
├── InformationPropagationService
│   ├── createFragment() → 每次事件后从见证人创建信息碎片
│   ├── propagate() → 每次推进推进1步扩散：已知者→未知者
│   ├── buildKnowledgeReport() → 输出"各角色此刻知道什么"
│   └── _distort(content, encryption, affinity) → 按加密风格扭曲信息
│
├── InformationFragment (数据模型)
│   ├── witnessCharId → 首次见证人
│   ├── content → 原始信息
│   ├── encryption → 加密风格
│   ├── spreadRadius → 传播半径
│   ├── knownBy → 已知此信息的角色ID
│   └── trustworthiness → 可信度(每次传播×0.85)
```

**五种加密风格**：
| 风格 | 可信度 | 效果 |
|---|---|---|
| honest（如实） | 1.0 | 如实转述，不加修饰 |
| joke（玩笑） | 0.7 | 用玩笑/阴阳怪气加密，真义埋藏在玩笑里 |
| cold（冷淡） | 0.8 | 轻描淡写，故意压低重要性 |
| gossip（八卦） | 0.5 | 添油加醋，放大戏剧性 |
| speculation（揣测） | 0.4 | 把自己的揣测包装成事实 |

**传播流程**：事件发生 → 见证人创建信息碎片 → 每次推进1步扩散 → 随机已知者传播给随机未知者 → 内容被加密风格扭曲 → 可信度衰减 → 达到传播半径后停止。

#### 引擎集成：`WorldEngine.tickWorld()`

每次推进时自动调用：
```dart
WorldTickReport tickWorld({Map<String,double> playerAffections}) {
  1. 查所有角色此刻在哪里（日程）
  2. 检测撞车 → 计算戏剧性分数
  3. 查角色间关系 → 输出动态(detectDrama)
  4. 推进1步信息传播
  5. 拼成 WorldTickReport → 注入 AI Prompt
}

String buildWorldReport(WorldTickReport report) {
  // 输出结构化文本，直接注入 AI 叙事 Prompt
  // AI 在生成叙事时能看到"此刻世界正在发生什么"——
  // 这些是事实，不是事件模板选择
}
```

**数据模型新增**（script.dart）：
- `CharacterScheduleSlot` — 单个日程槽位（时段/地点/活动/优先级/条件）
- `CharacterSchedule` — 工作日+周末两套日程
- `InterCharAttitude` — 角色对角色态度（亲和力/标签/历史/暗恋标记）
- `InformationFragment` — 信息碎片（见证人/内容/加密/可信度/传播半径）
- `WorldTickReport` — 推进报告（撞车列表/戏剧撞车/角色间动态/信息传播/知识状态）

### 8.2 一次"推进"的完整流程（v2.3 — 世界驱动 + freeform 事件系统）

```
玩家点 [推进]
  → app.advance('major')
    → 1. tickTension — 叙事张力+5
    → 2. checkBeatTriggers — 检查是否触发剧情节拍
    → 3. checkCharacterInitiative — 角色是否主动发消息
    → 4. WorldEngine.tickWorld() ★世界驱动★
         ├ scheduleService.getAllLocations() → 所有角色此刻在哪里
         ├ scheduleService.pickDramaticCollision() → 最值得写的撞车
         ├ interCharRel.detectDrama() → 角色间关系动态
         └ infoProp.propagate() → 推进1步信息扩散
    → 5. EventScheduler.selectEvent
         ├ _passesVarietyRule — 连续3次不重复，同类型每天不超过2次
         ├ _passesPacingRule — 高情感事件后冷却2回合
         ├ _passesConditionCheck — 好感度门槛，修罗场条件
         └ 加权随机（chaos_factor + 三角权重）
    → 5.5 如果事件 ai_rule == "freeform":
         ├ pickFreeformContext — 从 daily_scenes 池随机抽场景
         └ 不传 ai_hint，改为传场景参数 + 角色实时状态
    → 6. DeepSeekClient.generateEventNarrative
         ├ 注入 WorldTickReport（撞车/关系动态/信息传播）
         ├ fixed模式：按 ai_hint 生成叙事
         └ freeform模式：根据场景/好感度/角色状态 + 世界状态自主发挥
         输入：完整角色档案 + 在场角色好感度/关系/区间 + 场景参数 + 世界驱动报告
         输出：300-500字叙事
    → 7. 拼接叙事 → narrativeHistory
    → 8. interCharRel.onPlayerEvent() → 记录角色间互动
    → 9. _generateChoices — AI生成3个行动选项
    → 10. 通知UI刷新
```

**事件双模式（2026-06-13）：**

| 模式 | `ai_rule` | 叙事方向来源 | 适用池 |
|------|-----------|-------------|--------|
| 固定模板 | `"fixed"`（默认） | 剧本作者的 `ai_hint` | plot/boundary/reversal/love_triangle/sweet/echo/ensemble |
| 自由叙事 | `"freeform"` | DS 根据场景参数 + 角色实时状态自主创作 | daily |

**daily_scenes 场景种子池：** 7个地点 × 5个时段 × 4种情绪 × C(4,2)角色组合 = 理论 560 种不重复日常。

> 例如：`{location: rooftop, phase: 放学, mood: 微风, participants: [温辞, 苏念晚]}` → DS 根据温辞好感35/熟人 + 苏念晚好感68/好友的状态，自行决定天台上谁先开口、对话走向。

玩家选选项
  → app.pickChoice
    → 1. DeepSeekClient.generateChoiceResponse
         输入：完整1200字剧情记录
         输出：300-500字后续叙事
    → 2. modifyAffectionByEvent — 好感度变化（可破阶）
    → 3. RelationshipEngine.syncFromAffection — 关系状态同步
    → 4. 长事件→自动再生选项
    → 5. autoSave → localStorage

通讯录聊天
  → DeepSeekClient.generateChatReply
     输入：角色档案 + 当前好感度 + 最近300字剧情 + 代码层dualMode选择
     输出：AI回复
  → analyzeAffectionDelta → modifyAffectionByChat
```

### 8.3 关系状态机（RelationshipEngine）

**8个状态**：none→stranger→acquaintance→friend→close_friend→crush→lover→partner

| 特性 | 机制 |
|------|------|
| 状态来源 | 好感度驱动，但**不是纯数学**——破80需要告白事件 |
| 确立恋人 | `confirmLover(charId)` 由关键事件触发 |
| 多恋人 | 支持，tracked：每个恋人 who knows about whom |
| 修罗场检测 | `hasMultiLovers()` + `characterKnowsAbout()` → 触发 jealousy 事件 |
| 暴露惩罚 | 80-90区间: -10~-20; 90+区间: -15~-30 |
| 持久化 | save/load 时随存档存储和恢复 |

### 8.4 事件调度引擎（EventScheduler）

**相比旧版 `_selectEventTemplate`（millisecond % pool）的改进：**

| 规则 | 旧版 | 新版 |
|------|------|------|
| variety_rule | ❌ 未实现 | ✅ 连续3次不重复，同类型日限2次 |
| pacing_rule | ❌ 未实现 | ✅ 高情感事件后冷却2回合 |
| chaos_factor | ❌ 未实现 | ✅ 权重乘数 + 加权随机 |
| 修罗场检测 | ❌ 无 | ✅ 多恋人→三角事件权重×3 |
| 破阶事件优先 | ❌ 无 | ✅ boundary 池权重×2 |

### 8.5 说话模式硬规则

Chat System Prompt 构建时：
- `affection < 60` → 只写入 `dualMode.toStranger`（语音、用词、例句）
- `affection >= 60` → 只写入 `dualMode.toClose`
- `关系状态 = lover/partner` → toClose 模式 + 亲密行为提升

**不再把两套例句都发给AI让它自己选**。

### 8.6 聊天/场景/世界的一致性

| Prompt 层 | 叙事历史 | 关系状态 |
|-----------|---------|---------|
| 世界推进 | ✅ 1200字 | ✅ 自动注入（playerCard） |
| 选项续写 | ✅ 1200字 | ✅ 自动注入 |
| 通讯录聊天 | ✅ 300字（新增） | ✅ 代码层dualMode |
| 场景偶遇 | ✅ 400字（新增） | ⚠ prompt无但好感已融入 |
| 自定义行动 | ✅ 600字 | ✅ 自动注入 |

### 8.7 剧本工业化能力

**引擎完全通用，换 JSON 换剧本：**

| 剧本类型 | 改什么 |
|---------|--------|
| 校园纯爱 | 世界观=校园，角色=学生，事件=学业/社团/天台 |
| 修仙修真 | 世界观=修真，角色=修士/魔族，事件=秘境/渡劫/双修 |
| 都市职场 | 世界观=都市，角色=同事/上司，事件=加班/出差/暧昧 |
| 末日废土 | 世界观=废土，角色=幸存者/变异者，事件=搜索/逃亡/信任 |

所有引擎代码不动，只换 JSON 数据。

---

## 九、数据层（Data Layer）—— v2.0 新增

### 9.1 设计动机

当前系统缺失玩家自身的"可量化状态"。主角姓名、外貌、属性、成绩、排名——这些信息：
- 没有存储位置
- 没有更新机制
- AI 每次问"主角叫什么"乱编
- 无法支撑"月考排名 → 角色反应"这种关键剧情

### 9.2 数据层结构

在 `sim-script.json` 中新增 `data_layer` 段，与 `characters`、`events` 同级：

```
data_layer
├── player_profile     — 玩家基础信息（名字/性别/外貌/性格，由玩家编辑）
├── stats[]            — 通用属性（id/name/category/min/max/initial）
├── grades[]           — 成绩/技能（id/name/min/max/initial）
├── ranking            — 排名系统配置
│   ├── total_students  — 总人数
│   └── events[]        — 排名事件（月考/期末/大比/渡劫）
└── memory
    ├── stat_values     — 当前属性值
    ├── grade_values    — 当前成绩值
    ├── grade_history   — 历次排名记录
    └── last_ranking_day
```

### 9.3 工业化示例

| 校园剧本 | 修仙剧本 |
|---|---|
| stats: 智商/颜值/体能/魅力 | stats: 灵根/悟性/根骨/神识/气运 |
| grades: 语文/数学/英语/理综 | grades: 修为/丹道/剑法/阵法/符箓 |
| ranking: 月考(30天)/期末(90天) | ranking: 宗门大比(60天)/渡劫(180天) |

### 9.4 数据层驱动什么

1. **System Prompt 注入**：`playerCardForAi` 拼接姓名+属性+成绩→AI 知道主角是谁
2. **排名事件**：到达 ranking 间隔日自动触发 → 生成排名叙事 → 角色对排名变化做出反应
3. **事件条件**：`require: {stat: "intelligence", min: 70}` 可解锁选项
4. **角色认知**：AI 根据主角属性调整角色行为（"她注意到你数学最近进步了"）

---

## 十、时间系统 v2.0 — Milestone 跳转

### 10.1 设计动机

旧系统：1 次日常 = 1 个时段，1 天 = 8 次推进。对于两年半（900+ 天）剧本，玩家需要点击 7200+ 次日常，不可能。

### 10.2 新推进模型

| 概念 | 旧（60天） | 新（两年半） |
|---|---|---|
| 基础推进单位 | 时段（一天8段） | 天（一天1段，日常跳2-4天） |
| 日常推进 | 推进1个时段 | 跳过 2-4 天，生成"这几天发生了什么"摘要 |
| 重要推进 | 推进2-4时段 | 跳到下一个 milestone 日期 |
| 时间上限 | 无 | `total_days` 由引擎读取并校验 |
| 特殊日 | 定义了没用 | milestone 自动拦截——到达时触发长事件 |

### 10.3 Milestone 类型

在 `time_config.special_days` 中定义，引擎自动检测：

| 类型 | 示例 | 效果 |
|---|---|---|
| `exam` | 月考、期中考、期末考 | 触发排名事件 + 角色反应 |
| `event` | 运动会、文化祭、修学旅行 | 触发长事件（多轮选择） |
| `transition` | 转学日、开学日 | 触发世界观变更叙事 |
| `ending` | 毕业典礼 | 触发结局判定 |

### 10.4 推进流程

```
用户点 [日常推进]
  → 计算距下一个 milestone 的天数
  → 如果 < 3天：直接跳到 milestone 前一天
  → 如果 ≥ 3天：跳过 2-4 天，生成摘要叙事
  → AI 生成"这几天的日常"摘要（200-400字）
  → 更新属性（成绩微调、好感度微调）

用户点 [重要推进]
  → 直接跳到下一个 milestone
  → 触发 milestone 对应的长事件
  → 如果是考试类：生成排名 + 角色反应
  → 如果是活动类：触发多轮选择长事件
```

---

## 十一、剧情灵活化 v2.0

### 11.1 设计动机

旧系统：`plot.beats` 有 `mandatory` 节拍，`_checkBeatTriggers()` 硬触发，无论角色关系实际状态如何，AI 被强制写特定场景。

### 11.2 新设计

节拍从"剧本命令"降级为"AI 可选素材"：

1. **移除 `mandatory/optional` 区分** → 所有节拍改为 `relevance` 权重（0-100）
2. **`_checkBeatTriggers()` 改为收集** → 把满足条件的节拍打包为 `available_beats` 列表
3. **AI 决定是否使用** → System Prompt 中注入"以下节拍方向可供参考，但不强制"，AI 自行判断当前上下文是否需要
4. **节拍触发后记录** → 已用过的节拍 `relevance` 降为 0，避免重复

---

## 十二、多角色参与引擎

### 12.1 设计动机

当前事件模板的 `required_chars` 要么硬编码某角色，要么为空随机选一个。没有"当前谁和谁之间最有张力"的判断。

### 12.2 EventScheduler 新增 `_pickParticipants()`

```
选事件模板 → 检查 required_chars：
  ├── 为空 → 动态选择：
  │   ├── 计算每个角色的"出场权重"（好感度 × 最近未出场天数 × 关系状态加分）
  │   ├── 如果多个角色好感度 ≥ 60 → 优先选 ensemble / love_triangle 事件
  │   └── 加权随机选 1-3 个角色
  ├── 有硬编码 → 使用硬编码角色
  └── 修罗场检测：如果有 2+ 恋人且互相知道 → 权重 × 3
```

---

## 十三、场景事件记忆闭环

### 13.1 当前问题

场景事件只生成一段叙事，不产生好感度变化、不写记忆、不影响后续。

### 13.2 改进

场景事件结束后：
1. 写入角色 `memory.episodic`（标记 importance=5）
2. 产生微小好感度变化（±0.1~0.5）
3. 成为聊天话题素材（AI 聊天时注入最近场景记忆）
4. 新增"邀请角色到场景"功能：玩家选场景 → 选角色 → 触发双人场景事件
