# Sime - AI 互动叙事模拟引擎

AI 驱动的互动叙事游戏，支持自定义剧本、角色养成、多角色关系与世界探索。基于 Flutter 构建，接入 DeepSeek API 实时生成剧情与对话。

## 功能

- **AI 剧情生成** — 根据剧本设定实时生成叙事文本，支持多场景切换、时间推进、事件触发
- **角色对话** — 与剧本角色自由聊天，AI 根据角色设定、好感度、当前氛围生成回复
- **自定义剧本** — 内置剧本编辑器，可自定义角色、场景、事件、文风
- **关系系统** — 好感度动态变化，影响角色行为和对话选项
- **记忆系统** — 会话级记忆隔离 + AI 摘要压缩 + 关键词召回，角色不会"失忆"
- **世界探索** — 场景切换、地点互动、锻炼/训练等日常行动
- **通讯录** — 查看所有角色状态、好感度，支持自定义头像和备注
- **存档管理** — 多存档槽位，支持导出/导入

## 技术栈

| 层 | 技术 |
|---|---|
| 框架 | Flutter 3.2+ |
| 状态管理 | Provider |
| AI 接口 | DeepSeek API (Chat Completions) |
| 本地存储 | SharedPreferences |
| 平台 | Web / Android / iOS / Windows |

核心依赖：`provider` / `http` / `shared_preferences` / `file_picker` / `uuid` / `intl`

## 快速开始

### 1. 环境要求

- Flutter SDK >= 3.2.0
- DeepSeek API Key（[获取地址](https://platform.deepseek.com)）

### 2. 运行

```bash
cd sime
flutter pub get
flutter run -d chrome
```

### 3. 配置

首次启动后在设置页填入 DeepSeek API Key。Web 端还需配置 CORS 代理地址（如 `https://corsproxy.io/?`）。

## 项目结构

```
sime/
├── lib/
│   ├── screens/          # 页面：世界、通讯录、聊天、设置等
│   ├── services/         # 核心逻辑：AI 客户端、会话管理、记忆、关系引擎等
│   ├── providers/        # 状态管理
│   ├── models/           # 数据模型
│   └── widgets/          # 通用组件
├── assets/
│   ├── scripts/          # 内置剧本 JSON
│   └── images/           # 图片资源
├── web/                  # Web 构建输出
└── pubspec.yaml
```

## License

MIT