# 更新记录 (Changelog)

本项目遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/) 语义化版本规范。

---

## [2.2.0] - 2026-11-07

### 🌟 核心突破与重磅新增 (Major Feature Release)
- **🔌 深度集成 DeepSeek Harness 插件化架构 (Model Plugin Harness)**:
  - 借鉴 [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) 的 **"Everything is a Plugin"** 哲学，将模型端点、本地开发工具与云端平台全部抽象为可插拔的 `ModelServicePlugin`；
  - **本地离线运行时插件 (Local Runtimes)**：并发探查 Ollama (`11434`)、LM Studio (`1234`)、vLLM (`8000`)、LocalAI (`8080`)，实时拉取已安装离线模型清单（如 `deepseek-r1:8b`, `qwen2.5-coder:7b` 等），无需 Key 开箱即用；
  - **主流 AI 软件授权与配置一键导入 (IDE Plugins)**：
    - **Cursor**: 自动扫描 `~/Library/Application Support/Cursor/User/settings.json`，无缝提取已配置的 API Key 与模型；
    - **Continue**: 自动扫描 `~/.continue/config.json`，提取已配置的端点 URL、模型列表与 Key；
    - **Aider**: 自动扫描 `~/.aider.conf.yml` / `~/.env`，提取 DeepSeek / OpenAI 配置；
    - **Claude Desktop**: 自动识别 MCP 配置与客户端生态；
    - **Roo Code / Cline**: 自动提取已授权的模型参数。
  - **主流大模型开放平台授权中心 (Cloud Providers)**：
    - 原生适配 DeepSeek 深度求索（支持 DeepSeek-V3 与 R1 满血思考）、Agnes AI（多 Key 容灾池）、智谱 GLM、阿里云通义千问 (DashScope 百炼)、月之暗面 Kimi、阶跃星辰 StepFun、OpenAI；
    - 提供【一键打开控制台授权】跳转与【一键装配激活】到当前工作环境。
- **🌐 全量多语言国际化全覆盖 (Full i18n Coverage)**:
  - 核心本地化引擎 (`LocalizationManager.swift`) 全面覆盖插件化模型、授权中心、工作台各个面板；
  - 完善中 (`zh-Hans`)、英 (`en`)、日 (`ja`) 三语技术文档与 UI 字典，实时无感切换。
- **🛡️ 界面排版彻底净化与反人类缺陷清零**:
  - 侧边栏宽度增至 248pt，增加 20pt 绝对安全呼吸边距，彻底消灭“亿精灵”、“坚现场”等截断现象；
  - 顶栏分类过滤升级为流式横向胶囊（Chips），彻底消灭被挤压成竖向窄条的问题；
  - 偏好设置采用 macOS 原生 Segmented 胶囊分段导航，彻底消除右上角 `>>` 折叠与黑色悬浮药丸工具栏；
  - 移除突兀的右下角悬浮刷新大按钮，重构为符合 macOS 人机工程学规范的内嵌对齐控制条；
  - 在 SQLite 存储层与上下文层彻底清洗“城堡”、“导游宝”等侧边栏历史标签噪声，确保 AI 回复 100% 忠实于真实工作轨迹。

---

## [2.1.0] - 2026-11-07

### 🌟 新增功能 (Added)
- **🔍 本地模型与软件环境自适应嗅探 (Model Auto-Discovery)**:
  - 自动并发嗅探本地大模型端口（Ollama `11434`、LM Studio `1234`、vLLM `8000`、LocalAI `8080`），实时拉取已安装离线模型列表；
  - 自动检测本地环境变量与 Shell Profiles（`~/.zshrc` / `~/.bash_profile`）中的 `DEEPSEEK_API_KEY`、`OPENAI_API_KEY`、`ZHIPU_API_KEY` 与 `SILICONFLOW_API_KEY`；
  - 自动识别当前系统已安装并运行的 AI 软件与开发者 IDE（Antigravity, Cursor, VS Code, Xcode, Claude Desktop, 微信开发者工具等）；
  - 提供【一键智能装配】，无需手动繁琐复制粘贴，秒级激活模型端点与凭据。
- **🌐 全局多语言国际化支持 (i18n & Multi-Language)**:
  - 引入全局响应式本地化管理器 (`LocalizationManager.swift`)；
  - 首发支持 3 大主流语言：🇨🇳 简体中文 (`zh-Hans`)、🇺🇸 英语 (`en`)、🇯🇵 日本語 (`ja`)；
  - 在【偏好设置 - 外观与主题】中新增语言切换器，支持“跟随系统”或手动单选，全局界面即时刷新；
  - 同步提供全英文版 `README_EN.md` 与全日文版 `README_JA.md`。

---

## [2.0.0] - 2026-11-07

### 🚀 重大重构与突破 (Major Release)
- **🗄️ 工业级 SQLite3 + FTS5 全文检索引擎**:
  - 彻底摒弃脆弱的扁平 JSON 存储，全面迁移至 macOS 原生系统级 `import SQLite3` 关系数据库 (`DatabaseManager.swift`)；
  - 启用 WAL 高并发读写模式与 8MB 内存页缓存，确保高频窗口切换时微秒级写入，永不锁库；
  - 建立 SQLite FTS5 虚拟全文检索倒排索引（基于 `unicode61` 分词器），实现数万条足迹、标题与正文的毫秒级全文秒搜；
  - 规范设计 5 大核心关系表：`context_sessions`、`timeline_events`、`fts_timeline`、`daily_reports` 与 `app_settings`。
- **🎨 阶跃星辰（跃问 StepFun）现代桌面端质感设计**:
  - 全面重构主工作台界面 (`DashboardView.swift`)，默认自适应宽屏排布（`1140 × 740`），元素呼吸通透；
  - 彻底重构设置面板 (`SettingsView.swift`)，消灭怪异悬浮黑条与 `>>` 折叠菜单，改用原生平铺高档胶囊分段导航；
  - 顶部搜索框支持自适应伸缩，横向分类 Chips（`全部`、`💻开发`、`🌐浏览器`、`💬沟通`、`📝文档`）流式横滑，永不被挤断；
  - 右侧深度 Inspector 视窗详情面板，支持一键直达【恢复当时视窗现场】。
- **⚡️ 高可用多 API Key 智能轮换与超时故障转移池 (Failover Pool)**:
  - 支持多行或逗号输入多个 Key 组建容灾池，具备明文/密文安全切换与单通道连通性测试；
  - 多 Key 负载均衡分配并发请求，遇 `429 Too Many Requests` 限流或网络超时无缝自动转移至备用 Key。
- **🛡️ 视窗穿透与防幻觉降噪屏障**:
  - 重构 `WindowInspector.swift`，全面屏蔽 IDE 侧边栏历史会话列表（如旧项目名、聊天列表等干扰噪音）；
  - 将 Antigravity 宿主精准识别并绑定为当前真实研发项目 **全局记忆精灵 (ContextFlow)**；
  - 强化反幻觉边界铁律，实测验证彻底消除了“城堡”、“导游宝”等荒谬幻觉。
- **📊 商业级复盘日报与周报全景大屏**:
  - 今日全景日报：大屏复盘指标看板、攻坚综述、明日重点跟进规划；
  - 本周工作周报：跨 7 天聚合统计各项目投入占比（配可视化百分比进度条）与每日推进脉络；
  - 支持一键导出标准 Markdown 格式。

---

## [1.0.0] - 2026-11-06

### 初始版本 (Initial Release)
- 菜单栏极简常驻图标与微型 Popover 气泡；
- 离开应用瞬间的无感现场捕获与挂起机制；
- 基于 Apple Neural Engine (Vision) 本地离线神经网络 OCR 实体提炼；
- 支持 GitHub 私有仓库归档同步；
- 提供 5 套质感主题色切换。
