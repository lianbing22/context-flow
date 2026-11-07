# ContextFlow ⚡️ (全局記憶エルフ)

<p align="center">
  <a href="README.md">🇨🇳 简体中文</a> |
  <a href="README_EN.md">🇺🇸 English</a> |
  <a href="README_JA.md"><strong>🇯🇵 日本語</strong></a>
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
  <strong>macOS 専用に設計された産業級の全景デジタル記憶・作業現場保護・AI 振り返りコパイロット。</strong><br>
  StepFun のモダンデスクトップ美学を継承し、<strong>DeepSeek Harness</strong> の「すべてはプラグインである（Everything is a Plugin）」哲学を深く実践。産業級 SQLite3 + FTS5 全文検索エンジンを内蔵し、ローカルモデル・開発環境認証の自動スキャン、複数キーの冗長化自動切り替え、クラウド画像送信ゼロ、完全オフライン対応のオープンソースソリューションです。
</p>

---

## 📸 インターフェースギャラリー (Interface Gallery)

### 🖥️ 1. 全景タイムライン・ワークスペース (Full Timeline Dashboard)
> StepFun 調のワイドレイアウト。サイドバーに 20pt の安全マージンを確保し文字切れを根絶。多次元分類タグ（すべて、💻開発、🌐ブラウザ、💬連絡、📝文書）、検索バーからの即時 AI 質問、詳細インスペクターと【当時のウィンドウ現場を復元】を完備。

<p align="center">
  <img src="docs/screenshots/01_dashboard_timeline.png" alt="全景タイムライン" width="95%" />
</p>

---

### 💬 2. AI 記憶対話・検索 (AI Memory Chat)
> 自然言語で記憶を検索可能（例：「今日 Antigravity で開発したプロジェクトと進捗は？」）。SQLite3 の実データと幻覚防止バリアにより、虚偽のない客観的な業務記録をミリ秒で回答します。

<p align="center">
  <img src="docs/screenshots/02_dashboard_chat.png" alt="AI記憶対話" width="95%" />
</p>

---

### ⚙️ 3. 環境設定と DeepSeek Harness モデルハブ (Preferences & Plugins)
> 分割型ナビゲーションにより折りたたみ `>>` や黒い浮動ツールバーを徹底排除。ローカルモデル（Ollama, LM Studio）の自動検出、開発環境（Cursor, Continue, Aider）設定の安全なインポート、BYOK、冗長化キー配列、GitHub 記録同期、多言語切替に対応。

<table align="center">
  <tr>
    <td align="center" width="50%">
      <strong>🔌 DeepSeek Harness プラグイン＆認証ハブ</strong><br><br>
      <img src="docs/screenshots/settings_ai.png" alt="DeepSeek Harness ハブ" width="100%" />
      <br>
      <em>ローカルモデル検出 · IDE 認証インポート · ワンクリック適用</em>
    </td>
    <td align="center" width="50%">
      <strong>📚 デジタル年代記と GitHub プライベート保存</strong><br><br>
      <img src="docs/screenshots/settings_lifelog.png" alt="デジタル年代記" width="100%" />
      <br>
      <em>LifeLog GitOps · 自動サイレントコミット · Finder 連携</em>
    </td>
  </tr>
</table>

---

## 🌟 主な機能とアーキテクチャ (Key Features)

### 1. 🔌 DeepSeek Harness プラグイン型モデル構造
- **Everything is a Plugin**: [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) の設計哲学に基づき、ローカル推論基盤、IDE設定、クラウドプラットフォームをプラグインとして抽象化。
- **ローカルオフライン環境の並行検出 (Local Runtimes)**: Ollama (`11434`)、LM Studio (`1234`)、vLLM (`8000`)、LocalAI (`8080`) をスキャンし、インストール済みモデル（`deepseek-r1:8b`, `qwen2.5-coder:7b` 等）を自動取得。
- **主要開発ツール設定のインポート (IDE Plugins)**:
  - **Cursor**: 設定ファイルから API キーとモデルを抽出。
  - **Continue**: `~/.continue/config.json` からエンドポイントとキーを取得。
  - **Aider**: `~/.aider.conf.yml` / `~/.env` からモデル設定を取得。
  - **Claude Desktop / VS Code**: MCP サーバとクライアント連携。
- **主要クラウド LLM 認証ハブ**: DeepSeek（DeepSeek-V3 / R1）、Agnes AI、Zhipu GLM、Qwen (DashScope)、Moonshot Kimi、StepFun、OpenAI の公式認証コンソールへ直接アクセスし、ワンクリックで適用可能。

### 2. 🗄️ 産業級 SQLite3 WAL + FTS5 全文検索エンジン
- **高並行 WAL モード**: macOS ネイティブの SQLite3 データベースを採用し、ミリ秒単位の頻繁なウィンドウ切り替えでも書き込みロックなし。
- **FTS5 倒排インデックス**: `unicode61` 分詞器による高速インデックスで、数万件の履歴から瞬時に検索。

### 3. 🛡️ 事実固定とアンチハルシネーション（幻覚防止）
- **アクセシビリティのノイズ遮断**: IDE サイドバーの過去セッション一覧をフィルタリングし、不要なノイズ混入を防止。
- **実データとの厳格な整合**: 過去の誤認識データを物理削除し、画面上の実測トレースに基づいた正確な回答を提供。

### 4. ⚡️ 複数キーの冗長化フェイルオーバープール
- カンマまたは改行で複数キーを登録可能。
- `429 Too Many Requests` やタイムアウト発生時に予備キーへシームレスに自動切り替え。

### 5. 🌐 完全多言語対応 (i18n)
- 🇨🇳 **簡体字中国語 (`zh-Hans`)**、🇺🇸 **英語 (`en`)**、🇯🇵 **日本語 (`ja`)** を標準サポート。

---

## 🛠️ ビルドとインストール (Build & Install)

### 必要要件
- macOS 13.0 (Ventura) 以降
- Swift 6.0+ / Xcode 16.0+

### ソースコードからのビルド
```bash
# 1. リポジトリのクローン
git clone https://github.com/lianbing22/context-flow.git
cd context-flow

# 2. ビルドスクリプトの実行 (コード署名付き)
./build.sh

# 3. アプリケーションの起動
open 全局记忆精灵.app
```

---

## 🔒 プライバシー保護 (Privacy First)

- **100% ローカル保存**: すべての記録と SQLite DB は `~/.contextflow/` に安全に保管。
- **画像クラウド送信ゼロ**: スナップショットと OCR は Apple Neural Engine 上でオフライン完結。
- **機密アプリの完全除外**: 1Password やシステム Keychain などのパスワード画面は自動ブロック。

---

## 📄 ライセンス (License)

本プロジェクトは [MIT License](LICENSE) のもとで公開されています。
