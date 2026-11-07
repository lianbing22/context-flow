# 全局记忆精灵 ⚡️ (ContextFlow) 深度功能与架构详解手册

本文档面向开发者、高阶效率追求者与开源贡献者，全面解析 ContextFlow 的底层架构设计、技术实现原理与核心算法逻辑。

---

## 目录
1. [DeepSeek Harness 插件化模型与授权架构](#1-deepseek-harness-插件化模型与授权架构)
2. [SQLite3 WAL 关系数据库与 FTS5 全文检索引擎](#2-sqlite3-wal-关系数据库与-fts5-全文检索引擎)
3. [主流开发工具 (IDE) 配置提取与授权导入机制](#3-主流开发工具-ide-配置提取与授权导入机制)
4. [高可用多 API Key 智能轮换池与 Failover 故障转移](#4-高可用多-api-key-智能轮换池与-failover-故障转移)
5. [毫秒级视窗穿透与 IDE 侧边栏防幻觉降噪屏障](#5-毫秒级视窗穿透与-ide-侧边栏防幻觉降噪屏障)
6. [ContextFlow 现代化原生 macOS 桌面端 UI 与多语言国际化 (i18n)](#6-contextflow-现代化原生-macos-桌面端-ui-与多语言国际化-i18n)
7. [工作全景复盘日报与周报投入占比算法](#7-工作全景复盘日报与周报投入占比算法)
8. [端侧隐私与长效权限锁定机制](#8-端侧隐私与长效权限锁定机制)

---

## 1. DeepSeek Harness 插件化模型与授权架构

### 1.1 架构理念：Everything is a Plugin
参考官方 [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) 的核心设计哲学，ContextFlow 在 v2.2.0 中彻底摆脱了传统大模型客户端的“写死提供商列表”硬编码模式，全面实现了 **“一切皆插件（Everything is a Plugin）”** 的适配器模型体系。

```
┌────────────────────────────────────────────────────────────────────────┐
│                   ModelPluginHarness 综合调度中心                       │
├────────────────────┬────────────────────┬──────────────────────────────┤
│ 1. 本地离线运行时  │ 2. IDE 软件配置    │ 3. 主流云端开放平台           │
│  - OllamaPlugin    │  - CursorPlugin    │  - DeepSeek (V3/R1 满血思考) │
│  - LMStudioPlugin  │  - ContinuePlugin  │  - Agnes AI (高可用容灾池)    │
│  - vLLMPlugin      │  - AiderPlugin     │  - 智谱 GLM-4-Flash          │
│  - LocalAIPlugin   │  - Claude Desktop  │  - 阿里通义千问 (DashScope)  │
│                    │  - Roo Code/Cline  │  - 月之暗面 Kimi / 标准云端   │
└────────────────────┴────────────────────┴──────────────────────────────┘
```

### 1.2 插件生命周期与自适应探测
1. **非阻塞并发探查**：利用 Swift 结构化并发 `async let` 同时向本地默认模型端口发送探针；
2. **离线模型动态枚举**：对于本地运行中的 Ollama，直接请求 `/api/tags` 提取已拉取完成的本地量化大模型列表（如 `deepseek-r1:8b`、`qwen2.5-coder:7b`），无需人工配置；
3. **一键装配激活 (One-Click Adopt)**：将选中的插件配置（Base URL、Model Name、已授权 Key）秒级注入运行时配置，并触发连通性验证。

---

## 2. SQLite3 WAL 关系数据库与 FTS5 全文检索引擎

### 2.1 工业级原生 SQLite 架构
ContextFlow 全面依托 macOS 系统原生 `import SQLite3`（无需任何第三方重型依赖库），落盘于 `~/.contextflow/contextflow.sqlite3`，并预先配置了高性能运行参数：

```sql
PRAGMA journal_mode = WAL;          -- 开启 Write-Ahead Logging 机制，高并发读写互不阻塞
PRAGMA synchronous = NORMAL;        -- 兼顾断电安全性与微秒级磁盘写入性能
PRAGMA cache_size = -8000;          -- 预分配 8MB 内存页缓存
PRAGMA foreign_keys = ON;           -- 保证会话与足迹级联删除的强一致性
```

### 2.2 核心数据表结构
* **`context_sessions`（现场主表）**：记录工作现场的生命周期状态（`active`、`suspended`、`completed`）、专注秒数、所属工程、AI 提炼意图与行动建议；
* **`timeline_events`（细粒度时序足迹流水表）**：精确到毫秒记录每次视窗切换的应用、Bundle ID、窗口标题、URL、编辑的代码文件路径与正文抽取；
* **`fts_timeline`（SQLite FTS5 全文检索虚拟表）**：采用 `tokenize = 'unicode61'` 分词器，针对中英文混合文本建立倒排索引，秒级召回任意业务实体与记忆碎片；
* **`daily_reports`（日报归档表）**：结构化持久化每日专注指标、核心项目突破与明日规划建议。

---

## 3. 主流开发工具 (IDE) 配置提取与授权导入机制

现代开发者日常通常在多个 AI 工具中配置了 API 凭证。ContextFlow 具备安全无感扫描本地配置文件的能力，杜绝反人类的反复复制黏贴：

1. **Cursor 配置安全嗅探**：
   - 目标路径：`~/Library/Application Support/Cursor/User/settings.json`
   - 解析字段：`cursor.openaiApiKey`、`cursor.anthropicApiKey`
2. **Continue 插件模型导入**：
   - 目标路径：`~/.continue/config.json`
   - 提取 `models` 数组中的 `apiBase`、`model` 与 `apiKey`
3. **Aider 终端协同配置**：
   - 目标路径：`~/.aider.conf.yml` / `~/.env`
   - 解析预设的 `DEEPSEEK_API_KEY` 与模型参数
4. **Shell Profile 环境变量穿透**：
   - 纯本地只读分析 `~/.zshrc` / `~/.bash_profile` 中的 `export ..._API_KEY`，零网络开销提取凭据。

---

## 4. 高可用多 API Key 智能轮换池与 Failover 故障转移

### 4.1 痛点解决
在高频的工作记忆意图提炼与连续自然语言问答中，单 Key 极易触发服务商的并发限制（429 Rate Limit）或因公网抖动发生连接超时。

### 4.2 轮换与容灾算法
* **密钥池自动解析**：支持多行换行或逗号分隔录入多个 API Key，系统自动剔除重复项并组建通道池；
* **Round-Robin 负载均衡**：并发请求按循环顺序轮换分配，降低单 Key 的限流概率；
* **毫秒级故障转移 (Failover)**：
  - 当某个通道遭遇 HTTP 429、401 鉴权失效或请求超时，系统立即标记该通道并无缝切换至备用通道重试；
  - 只有当池内所有 Key 均告耗尽时，才优雅降级至端侧离线引擎；
* **开箱即用离线端侧保障**：在无网络或未填写 Key 的状态下，系统自动启用 Apple Neural Engine（本地 CoreML / Vision）进行离线实体提炼，完全离线可用。

---

## 5. 毫秒级视窗穿透与 IDE 侧边栏防幻觉降噪屏障

### 5.1 历史幻觉事故深度溯源
在早期版本中，辅助功能（Accessibility）在抓取 Antigravity 等现代化 IDE 视窗时，容易误将**左侧边栏历史会话列表（例如旧项目名、聊天记录标签）**当成用户当前正在攻坚的活动现场，导致 AI 在回答时产生“正在开发城堡模块、导游宝”等离谱幻觉。

### 5.2 三层防线彻底清零
1. **视窗穿透与前台活动元素锁定**：通过 `WindowInspector.swift`，明确只提取带有系统焦点（Focus）的编辑区与文档正文，对侧边栏已知的历史标签进行特征过滤；
2. **数据存储层物理清洗**：在数据库初始化与引擎启动阶段，物理扫描并抹除所有带有侧边栏干扰项的脏记录；
3. **提示词事实锁定屏障**：在 `AISummarizer.swift` 中强制注入事实约束提示词：
   `“严禁脑补任何未在时序轨迹中明确出现的虚构模块或项目名称，必须 100% 忠实于当前屏幕真实轨迹与时序时间线。”`

---

## 6. ContextFlow 现代化原生 macOS 桌面端 UI 与多语言国际化 (i18n)

### 6.1 彻底消灭反人类排版缺陷
* **侧边栏防截断**：宽度扩展至 248pt，设置 20pt 绝对安全呼吸边距，彻底告别文字被左边框裁切问题；
* **原生 Segmented 胶囊平铺导航**：彻底淘汰 macOS 原生 TabView 导致的右上角 `>>` 折叠与黑色悬浮药丸工具栏缺陷；
* **流式横向分类胶囊 (Chips)**：全部、开发、浏览器、沟通、文档等分类采用横向自适应滚动容器，绝不挤压成竖条。

### 6.2 全局多语言国际化 (i18n)
内置 `LocalizationManager.swift`，原生支持三种主流工作语言：
* 🇨🇳 **简体中文 (`zh-Hans`)**
* 🇺🇸 **English (`en`)**
* 🇯🇵 **日本語 (`ja`)**

---

## 7. 工作全景复盘日报与周报投入占比算法

### 7.1 数据聚合逻辑
根据 `timeline_events` 表中的时序窗口驻留秒数，系统以时间切片聚合算法统计用户在各个项目与应用中的纯专注投入：

$$\text{投入占比}(\text{Project}_i) = \frac{\sum \text{ActiveSeconds}(\text{Project}_i)}{\sum_{\text{all}} \text{ActiveSeconds}} \times 100\%$$

* **剔除挂起与闲置**：超过 30 秒无鼠标键盘输入的窗口自动切入挂起，不计入有效专注时长；
* **自动生成周报图表**：以可视化彩色进度条直观呈现研发精力投向。

---

## 8. 端侧隐私与长效权限锁定机制

* **本地神经视觉 OCR**：基于 Apple Neural Engine 硬件级加速，OCR 提炼全过程 0 字节图片上传云端；
* **代码签名与权限持久化**：采用深度代码签名，固定 `app.memoryelf` 权限签名树，杜绝 macOS 系统反复弹出辅助功能授权提醒；
* **密码与敏感弹窗硬件级忽略**：默认屏蔽 1Password、Bitwarden、系统 Keychain 弹窗等敏感场景，保证开发者隐私安全。
