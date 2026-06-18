# LoveSim PRD — 剧本驱动恋爱模拟引擎

## 1. 工程铁律

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

## 2. 数据层规范 (data_layer)

### 2.1 属性池 (stats)
```json
"stats": [
  {"id": "intelligence", "name": "智商", "category": "talent", "min": 0, "max": 100, "initial": 55}
]
```
- `id` 必须在该剧本内唯一，并与 `grade_formulas.stat_bonuses` 中引用的 key 一致
- `category` 用于 UI 分组，可自定义
- 属性的本地化名称在 JSON 中定义，Dart 代码不硬编码任何属性名

### 2.2 成绩池 (grades)
```json
"grades": [
  {"id": "chinese", "name": "语文", "min": 0, "max": 150, "initial": 108}
]
```
- `id` 必须与 `grade_formulas` 的 key 和 ranking `affects` 数组中引用的 ID 一致

### 2.3 成绩公式 (grade_formulas)  ⭐ 新增
```json
"grade_formulas": {
  "chinese": {
    "base_weight": 0.70,
    "variance": 10,
    "stat_bonuses": {"intelligence": 0.07, "charisma": 0.05}
  }
}
```
- `base_weight` — 基准分权重（当前分数 × 此项，保留位供未来扩展）
- `variance` — 考试随机浮动范围（±variance）
- `stat_bonuses` — 属性到分数的加成系数映射。key 是 stat.id，value 是系数
- 每一项成绩**必须**有对应 formula 条目；缺失的科目 statBonus=0

### 2.4 成长率 (natural_growth_rate)
```json
"natural_growth_rate": 0.02
```
- 每次考试前，所有 stat/grade 按 `(max - current) × rate` 自然成长
- 0 = 无自然成长，0.05 = 快速成长

### 2.5 排名体系 (ranking)
```json
"ranking": {
  "total_students": 750,
  "events": [
    {"id": "monthly_exam", "name": "月考", "interval_days": 30, "affects": ["chinese","math","english","science"]}
  ]
}
```
- `affects` 引用的 grade ID 必须存在于 `grades` 和 `grade_formulas` 中

## 3. 角色规范

### 3.1 stats/grades 字段（可选）
每个 full_character 可携带 `stats` 和 `grades` 数组定义初始值：

```json
"stats": [
  {"id": "intelligence", "name": "智商", "value": 70, "max": 100}
],
"grades": [
  {"id": "chinese", "name": "语文", "value": 110, "max": 150}
]
```
- 如果 JSON 中角色未填 stats/grades，引擎自动生成通用均匀分布初始值（基于 statDef.initial ± 浮动的确定性格回退，完全不需要代码层知道任何角色 ID）

## 4. 创建新剧本检查清单

- [ ] 定义 `data_layer.stats`（属性池）
- [ ] 定义 `data_layer.grades`（成绩池）
- [ ] 定义 `data_layer.grade_formulas`（每科公式）
- [ ] 定义 `data_layer.natural_growth_rate`
- [ ] 定义 `data_layer.ranking`（总人数 + 考试事件）
- [ ] 定义 `rhythm_config`（节奏层：weight/focus指引 + beat/boundary映射 + 剧本类型修正）
- [ ] 为每个 full_character 填写 `stats` 和 `grades`（可选——不填则自动回退）
- [ ] 确保所有 ID 在 stat/grades/formula 三层之间一致引用
- [ ] **不要修改任何 .dart 文件**

## 5. 配置热替换

引擎通过 `ScriptRegistry` 管理多剧本：
```dart
ScriptRegistry().register('my_wuxia', 'assets/scripts/wuxia_world.json');
ScriptRegistry().activate('my_wuxia');
```
切换剧本即重新解析 JSON → 所有公式/属性池/角色池即时更新。存档按剧本 ID 隔离。

## 6. 存档兼容性

- 存档中携带 `scriptId` + `scriptName`
- 存档加载时校验剧本版本，不匹配则提示
- 剧本升级时需维护向后兼容的 `data_layer` 迁移
