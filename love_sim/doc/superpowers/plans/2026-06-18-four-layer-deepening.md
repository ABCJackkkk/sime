# 四层深化：让角色活、让世界有戏、让 AI 不扁、让节奏有呼吸

> **For agentic workers:** Implement task-by-task using SearchReplace on existing files and Write for new files. Steps use checkbox (`- [ ]`) syntax.

**动机：** v2.4 节奏层解决的是"AI 不被事件模板框住"。但世界驱动只是换了输入方式——角色还是扁的、世界还是背景板、AI 偶尔写得平、张力是单值节拍器。四层深化让引擎从"能跑"到"有质"。

**原则：** 每层只砍最该用力的一刀。不改架构，在现有骨架上长肉。

---

## 角色层：记忆层次化

### 要解决的问题

现在的 `character_memory_service.dart` 是扁平事件日志。角色没有"记得住"的东西——昨天食堂吃什么和青梅竹马的约定混在一起，同等对待。AI 拿到的 memory 是一串无差别的日期序列。

### 设计方案

```
MemoryLayer
├── core     — 核心记忆（创伤、誓言、自我认知锚点）  ← 永不清洗，权重最高
├── episodic — 情景记忆（和你做过的事、重要对话）    ← 按叙事密度保留
└── decay    — 衰减记忆（日常琐事、随机事件）        ← 自动沉淀/遗忘
```

**三层不同的生命周期：**

| 层 | 来源 | 衰减规则 | prompt 中怎么放 |
|---|---|---|---|
| core | 剧本定义 + 游戏过程中"core"标记事件 | 永不清洗，数量上限 5-8 条 | 放最前面，标签 `【她的记忆锚点】` |
| episodic | 事件叙事中检测到的关键互动 + affect≥60 的对话 | 超过 10 条时，最旧的降级到 decay | `【你们之间的重要时刻】` |
| decay | 日常推进的 trivial 事件 + episodic 降级 | 上限 20 条，超出自动丢弃最旧的 | `【最近的日常】` |

### 具体步骤

- [ ] **Step 1: 在 CharacterMemoryService 中定义三层数据结构** — `coreMemories` / `episodicMemories` / `decayMemories`，每条含 `content`, `dayRecorded`, `sourceTag`
- [ ] **Step 2: 在 recordEvent 中按 severity 分层** — critical/heavy → core，medium → episodic，light → decay
- [ ] **Step 3: 添加 core 记忆上限 8 条 + 溢出淘汰最旧** — 保证不会无限膨胀
- [ ] **Step 4: 添加 episodic 上限 10 条 + 溢出降级到 decay**
- [ ] **Step 5: 添加 decay 上限 20 条 + 溢出丢弃**
- [ ] **Step 6: 修改 buildMemoryContext() 按三层结构输出** — core → episodic → decay，每段有明确的 section 标签
- [ ] **Step 7: 存档支持** — save/load 时序列化三层结构
- [ ] **Step 8: 构建验证**

### 产出文件

| 文件 | 变更 | 说明 |
|---|---|---|
| `character_memory_service.dart` | 修改 | 三层数据结构 + 分层回收逻辑 |
| `save_service.dart` | 修改 | 存档三层结构 |
| `deepseek_client.dart` | 修改 | prompt 中按三层输出 |

---

## 世界层：地点的叙事属性

### 要解决的问题

地点现在是纯背景——`sceneLocations` 有 name 和 desc，撞车检测只算好感度。天台和走廊在叙事上没有区别。

### 设计方案

```dart
class LocationNarrativeProfile {
  final String locationId;
  final Map<DramaticFocus, double> eventAffinity;  // 对不同叙事焦点的加成系数
  final List<String> narrativeKeywords;              // 地点特有的叙事关键词
}
```

**事件倾向权重示例：**

| 地点 | characterMoment | relationshipBeat | tensionEscalation | ensembleScene |
|---|---|---|---|---|
| 天台 | 0.6 | **0.9** | 0.3 | 0.4 |
| 走廊 | 0.3 | 0.4 | **0.7** | **0.6** |
| 图书馆 | **0.7** | 0.5 | 0.1 | 0.2 |
| 旧球场 | **0.8** | 0.6 | 0.4 | 0.3 |
| 食堂 | 0.3 | 0.2 | 0.1 | **0.9** |

**撞车检测改造：** 当前 `pickDramaticCollision` 只按好感度差距排序。加上地点加成——同样两个人在天台撞上比在走廊撞上更重。

**剧本 JSON 配置：**

```json
"scene_locations": [
  {
    "id": "rooftop", "name": "天台", "desc": "风很大，视野开阔",
    "narrative_profile": {
      "event_affinity": { "relationshipBeat": 0.9, "characterMoment": 0.6 },
      "keywords": ["风", "天空", "远方", "围栏", "夕阳"]
    }
  }
]
```

### 具体步骤

- [ ] **Step 1: 在 script.dart 添加 LocationNarrativeProfile 模型** — eventAffinity + keywords
- [ ] **Step 2: 在 script_loader.dart 解析 narrative_profile 字段**
- [ ] **Step 3: 修改 pickDramaticCollision 加入地点加成** — dramaScore = 好感度冲突 * (1.0 + locationAffinity[碰撞对应的 focus])
- [ ] **Step 4: 在 tickWorld 中注入地点 narrative profile 到碰撞结果** — 让 generateWorldNarrative 拿到地点关键词
- [ ] **Step 5: 更新 _template.json 和 campus_love.json 的场景定义**
- [ ] **Step 6: 构建验证**

### 产出文件

| 文件 | 变更 | 说明 |
|---|---|---|
| `script.dart` | 修改 | LocationNarrativeProfile 模型 |
| `script_loader.dart` | 修改 | 解析 narrative_profile |
| `character_schedule.dart` | 修改 | pickDramaticCollision 加地点加成 |
| `_template.json` + `campus_love.json` | 修改 | 添加 narrative_profile |
| `deepseek_client.dart` | 修改 | prompt 中注入地点关键词 |

---

## 生成层：Prompt 动态权重

### 要解决的问题

现在 System Prompt 是一次拼好全塞进去。日常推进时 AI 也看到冗长的 plot 背景和完整人物关系网——信息噪声让 AI 写得"散"。

### 设计方案

**Prompt 组装改为三明治结构：**

```
[常驻底座]     — 角色身份、绝对规则（约 30% 固定）
[动态夹层]     — 按叙事焦点切换权重（约 50% 可调）
[当刻注入]     — 世界此刻 + 日程 + 排名（约 20% 每次不同）
```

**动态夹层按 DramaticFocus 分配权重：**

| focus | speech+humanity | relationship | characterArc | plot | world |
|---|---|---|---|---|---|
| characterMoment | **35%** | 15% | **30%** | 5% | 15% |
| relationshipBeat | 15% | **40%** | 10% | 15% | 20% |
| plotAdvancement | 5% | 10% | 10% | **60%** | 15% |
| worldTexture | 10% | 5% | 5% | 5% | **75%** |
| tensionEscalation | 15% | 20% | 15% | **35%** | 15% |
| ensembleScene | **25%** | **25%** | 5% | 20% | **25%** |

**实现方式：** 不改变 segment 内容，只改变每个 segment 塞进 prompt 的长度。relationshipBeat 下，角色间关系的段落从 300 字扩到 800 字；worldTexture 下，世界描述的段落扩到 800 字，plot 缩减为 100 字。

### 具体步骤

- [ ] **Step 1: 定义 FocusWeightConfig** — 每种 DramaticFocus 对应的各维度权重表
- [ ] **Step 2: 给每个 Prompt segment 加"可伸缩"能力** — 每段有 `minLength` / `maxLength`，按权重映射到实际长度
- [ ] **Step 3: 修改 _buildChatSystemPrompt 接受 focus 参数** — 按权重裁剪各段
- [ ] **Step 4: 修改 generateWorldNarrative 接受 focus 参数** — 同上
- [ ] **Step 5: 聊天和世界叙事调用处传入当前 focus**
- [ ] **Step 6: 构建验证**

### 产出文件

| 文件 | 变更 | 说明 |
|---|---|---|
| `deepseek_client.dart` | 修改 | FocusWeightConfig + 动态裁剪逻辑 |
| `rhythm_scheduler.dart` | 修改 | resolve() 返回 focus 给调用方 |
| `game_session.dart` | 修改 | 传 focus 给 prompt 构建 |

---

## 节奏层：三维张力拆解

### 要解决的问题

`narrativeTension` 是单值——涨了就涨了，降了就降了。但好的叙事是三维的：关系紧张但主线平和、角色内心崩塌但外部无事发生……单值张力把这些全压扁了。

### 设计方案

```dart
class TensionVector {
  double relational;   // 玩家与角色之间的张力（好感度临界/三角关系/信任动摇）
  double narrative;    // 主线情节的张力（揭秘临近/倒计时/事件累积）
  double emotional;    // 角色的内在情绪张力（焦虑累积/失落/愤怒）
  
  double get composite => (relational + narrative + emotional) / 3.0;
  bool get isClimaxThreshold => relational > 0.7 && narrative > 0.7;  // 双维交叉 = 爆发点
}
```

**各维度驱动源：**

| 维度 | 涨什么 | 降什么 |
|---|---|---|
| relational | 好感临界、三角关系事件、吃醋事件、拒绝行动 | 连续3次日常无冲突、主动修复行动 |
| narrative | 剧情节拍推进、信息揭露、截止日临近 | 情节目标达成、长事件收束 |
| emotional | 排斥行动、被忽略、角色个人目标受阻 | 正向互动、好感突破、角色自主行动完成 |

**反节奏检测：** `tickTension()` 不再是每个回合加 5。改为：
- 连续日常推进时，relational 缓慢下降（审美疲劳）
- 但 emotional 持续小幅上升（被冷落的累积）
- 当 emotional > 0.6 且 relational 突然触临界 → 爆发式推进（反节奏）

**在 RhythmScheduler 中的应用：** 原 `_tickTension()` 替换为 `TensionVector.tick()`，在 `resolve()` 的合并逻辑中增加维度交叉检测。

### 具体步骤

- [ ] **Step 1: 创建 tension_vector.dart** — TensionVector 类 + tick/decay/gate 方法
- [ ] **Step 2: 在 RhythmScheduler 中集成 TensionVector** — 替换单值 narrativeTension
- [ ] **Step 3: 在各事件/行动中驱动三维张力** — advance 结尾、customAction、好感度变化时
- [ ] **Step 4: 添加反节奏检测逻辑** — 双维交叉 → 输出 tensionEscalation focus + critical weight
- [ ] **Step 5: 在 generateWorldNarrative prompt 中注入三维张力快照** — "此刻：关系紧绷 0.82，情节蓄势 0.45，她内心不安 0.61"
- [ ] **Step 6: 存档支持** — save/load TensionVector
- [ ] **Step 7: 构建验证**

### 产出文件

| 文件 | 变更 | 说明 |
|---|---|---|
| `tension_vector.dart` | 新建 | TensionVector 模型 |
| `rhythm_scheduler.dart` | 修改 | 集成 TensionVector + 交叉检测 |
| `game_session.dart` | 修改 | 事件/行动驱动三维张力 |
| `deepseek_client.dart` | 修改 | prompt 注入张力快照 |
| `save_service.dart` | 修改 | 存档 TensionVector |

---

## 执行顺序

```
① 角色层：记忆层次化      ← 不依赖其他层，独立实施
② 世界层：地点的叙事属性    ← 不依赖其他层，独立实施
③ 生成层：Prompt 动态权重   ← 依赖节奏层输出 focus
④ 节奏层：三维张力拆解      ← 可以并行开始，但需要在生成层之前完成
```

**建议实际顺序：① → ② → ④ → ③**（④完成后 ③ 的 focus 来源才完整）

---

## 改动深度总结

```
v2.4 节奏层（已完成）：EventScheduler → RhythmScheduler，世界快照替代事件模板
  ↓
v2.5 四层深化：
  ├── 角色层 ─ 记忆层次化 → 角色不再扁，对话有"重量"
  ├── 世界层 ─ 地点叙事属性 → 天台和走廊不是同一个地方
  ├── 生成层 ─ Prompt 动态权重 → AI 注意力不散焦
  └── 节奏层 ─ 三维张力拆解 → 反节奏才是真节奏
```
