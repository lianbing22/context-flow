# ContextFlow ⚡️ (全局记忆精灵)

<p align="center">
  <a href="README.md">🇨🇳 简体中文</a> |
  <a href="README_EN.md"><strong>🇺🇸 English</strong></a> |
  <a href="README_JA.md">🇯🇵 日本語</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2013.0%2B-blue?style=flat-square&logo=apple" alt="macOS 13.0+" />
  <img src="https://img.shields.io/badge/Swift-6.0%20%7C%20SwiftUI-orange?style=flat-square&logo=swift" alt="Swift 6.0" />
  <img src="https://img.shields.io/badge/Architecture-DeepSeek%20Harness%20Plugin-purple?style=flat-square" alt="DeepSeek Harness Plugin" />
  <img src="https://img.shields.io/badge/Database-SQLite3%20WAL%20%2B%20FTS5-blueviolet?style=flat-square" alt="SQLite3 + FTS5" />
  <img src="https://img.shields.io/badge/Vision-Apple%20Neural%20Engine-success?style=flat-square" alt="Apple Neural Engine" />
  <img src="https://img.shields.io/badge/Privacy-100%25%20Local%20Storage-brightgreen?style=flat-square" alt="100% Local Storage" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="MIT License" />
</p>

<p align="center">
  <strong>High-performance industrial-grade global digital memory, window context guardian, and AI work wrap-up copilot crafted for macOS.</strong><br>
  Built with ContextFlow's signature modern panoramic desktop design system, fully adopting the <strong>DeepSeek Harness</strong> "Everything is a Plugin" design philosophy. Embedded with an industrial-grade SQLite3 + FTS5 inverted full-text search engine, auto-discovering local models & IDE credentials, high-availability multi-key failover pool, zero cloud image uploads, completely offline-capable and open-source.
</p>

---

## 📸 Interface Gallery

### 🖥️ 1. Full Timeline Dashboard
> ContextFlow panoramic workspace with a 20pt guaranteed safe left-margin that eliminates sidebar truncation. Features multi-dimensional horizontal classification chips (All, 💻 Dev, 🌐 Browser, 💬 Chat, 📝 Docs), flexible search bar with instant Enter-to-chat, and inspector details with one-click window context restoration.

<p align="center">
  <img src="docs/screenshots/01_dashboard_timeline.png" alt="Full Timeline Dashboard" width="95%" />
</p>

---

### 💬 2. AI Global Memory Chat
> Commercial-grade conversational memory search: Ask questions naturally (e.g., *"What projects did I develop in Antigravity today and what is the progress?"*). Backed by genuine SQLite temporal traces and an anti-hallucination barrier, delivering precise and honest answers without fabricated claims.

<p align="center">
  <img src="docs/screenshots/02_dashboard_chat.png" alt="AI Memory Chat" width="95%" />
</p>

---

### ⚙️ 3. Native Preferences & DeepSeek Harness Model Hub
> Refactored with a clean Segmented navigation pill bar, eradicating popover `>>` collapse and floating toolbar glitches. Auto-discovers local offline models (Ollama, LM Studio), imports IDE configurations (Cursor, Continue, Aider), supports BYOK, multi-key failover pool, privacy blacklists, GitHub LifeLog archive, and multi-language switching (i18n).

<table align="center">
  <tr>
    <td align="center" width="50%">
      <strong>🔌 DeepSeek Harness Plugin & Authorization Hub</strong><br><br>
      <img src="docs/screenshots/settings_ai.png" alt="DeepSeek Harness Plugin & Auth Hub" width="100%" />
      <br>
      <em>Local model discovery · IDE authorization import · One-click adoption</em>
    </td>
    <td align="center" width="50%">
      <strong>📚 Digital Chronicle & GitHub Private Archive</strong><br><br>
      <img src="docs/screenshots/settings_lifelog.png" alt="LifeLog GitOps" width="100%" />
      <br>
      <em>LifeLog GitOps · Periodic background push · Finder integration</em>
    </td>
  </tr>
</table>

---

## 🌟 Architecture & Key Features

### 1. 🔌 DeepSeek Harness Plugin Architecture
- **Everything is a Plugin**: Follows [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) core philosophy, treating model inference, IDE configurations, and cloud providers as composable plugins.
- **Local Offline Runtimes**: Concurrently probes Ollama (`11434`), LM Studio (`1234`), vLLM (`8000`), and LocalAI (`8080`), automatically enumerating installed quantized models (e.g., `deepseek-r1:8b`, `qwen2.5-coder:7b`) with zero keys required.
- **One-Click IDE Configuration Import**:
  - **Cursor**: Extracts configured OpenAI/Anthropic/Custom API keys and models from `settings.json`.
  - **Continue**: Safely reads model lists, Base URLs, and keys from `~/.continue/config.json`.
  - **Aider**: Extracts credentials from `~/.aider.conf.yml` / `~/.env`.
  - **Claude Desktop / VS Code**: Probes MCP servers and client extensions.
- **Mainstream Cloud Platforms**: Direct authorization portals and one-click adoption for DeepSeek Official (DeepSeek-V3 & R1 reasoning), Agnes AI, Zhipu GLM, Qwen (DashScope), Moonshot Kimi, and OpenAI.

### 2. 🗄️ Industrial SQLite3 WAL + FTS5 Full-Text Engine
- **High-Concurrency WAL Mode**: Built-in macOS native `SQLite3` with Write-Ahead Logging and 8MB cache pages, effortlessly handling microsecond window switches without lockouts.
- **FTS5 Inverted Index Search**: Virtual FTS5 table powered by `unicode61` tokenizer for sub-millisecond retrieval across tens of thousands of window events.
- **Normalized Schema**: Structured across `context_sessions`, `timeline_events`, `fts_timeline`, `daily_reports`, and `app_settings`.

### 3. 🛡️ Fact-Anchored Anti-Hallucination Shield
- **Accessibility De-noising**: Filters non-active IDE sidebar tabs (historical chats, project trees) to prevent noise contamination.
- **Physical Purge & Strict Factuality**: Completely cleansed historic OCR noise records; responses strictly reflect real-time on-screen telemetry.

### 4. ⚡️ Multi-Key Intelligent Failover Pool
- Input multiple keys via comma or newline to establish a disaster-recovery pool.
- Automatically load-balances requests and transparently switches keys upon encountering `429 Too Many Requests` or network timeouts.

### 5. 🌐 Full Internationalization (i18n)
- Responsive localization manager (`LocalizationManager.swift`).
- Supports 🇨🇳 **Simplified Chinese (`zh-Hans`)**, 🇺🇸 **English (`en`)**, and 🇯🇵 **Japanese (`ja`)**.

---

## 🛠️ Build & Installation

### Requirements
- macOS 13.0 (Ventura) or later
- Swift 6.0+ / Xcode 16.0+

### Build from Source
```bash
# 1. Clone the repository
git clone https://github.com/lianbing22/context-flow.git
cd context-flow

# 2. Build with code signing
./build.sh

# 3. Launch application
open 全局记忆精灵.app
```

---

## 🔒 Privacy Guarantee

- **100% Local Storage**: All timelines, entities, and databases are stored in `~/.contextflow/`.
- **Zero Cloud Uploads**: Thumbnails and OCR are processed on-device via Apple Neural Engine.
- **Sensitive App Shield**: Password managers (1Password, Keychain) and auth prompts are permanently ignored.
- **Open Source & Auditable**: Built with 100% pure native Swift and system frameworks.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
