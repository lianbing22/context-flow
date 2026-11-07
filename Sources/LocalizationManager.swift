import Foundation
import SwiftUI

public enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case zhHans = "zh-Hans"
    case en = "en"
    case ja = "ja"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "跟随系统 (System Default)"
        case .zhHans: return "简体中文 (Chinese)"
        case .en: return "English"
        case .ja: return "日本語 (Japanese)"
        }
    }
}

/// 全局多语言与本地化引擎 (支持实时响应切换，无感刷新)
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    @Published public var currentLanguage: AppLanguage = .zhHans

    private init() {
        let saved = UserDefaults.standard.string(forKey: "ContextFlow.AppLanguage") ?? "zh-Hans"
        self.currentLanguage = AppLanguage(rawValue: saved) ?? .zhHans
    }

    public func setLanguage(_ lang: AppLanguage) {
        self.currentLanguage = lang
        UserDefaults.standard.set(lang.rawValue, forKey: "ContextFlow.AppLanguage")
    }

    /// 核心键值本地化查找
    public func t(_ key: String) -> String {
        let activeLang: String
        if currentLanguage == .system {
            let pref = Locale.preferredLanguages.first ?? "zh-Hans"
            if pref.starts(with: "ja") { activeLang = "ja" }
            else if pref.starts(with: "en") { activeLang = "en" }
            else { activeLang = "zh-Hans" }
        } else {
            activeLang = currentLanguage.rawValue
        }

        return localizedStrings[activeLang]?[key] ?? localizedStrings["zh-Hans"]?[key] ?? key
    }

    // 工业级三语字典库 (支持 DeepSeek Harness 插件模型与授权中心)
    private let localizedStrings: [String: [String: String]] = [
        "zh-Hans": [
            "app_name": "全局记忆精灵",
            "app_sub": "全景工作台 · v2.2",
            "nav_timeline": "全景时间轴",
            "nav_chat": "AI 记忆对话",
            "nav_daily": "今日日报",
            "nav_weekly": "本周周报",
            "nav_suspended": "挂起看板",
            "nav_settings": "偏好设置",
            "focus_overview": "今日专注概览",
            "focus_mins": "专注分钟",
            "active_sessions": "攻坚现场",
            "cat_all": "全部",
            "cat_dev": "开发",
            "cat_browser": "浏览器",
            "cat_chat": "沟通",
            "cat_doc": "文档",
            "btn_restore": "恢复现场",
            "btn_complete": "收尾",
            "btn_ask": "问记忆",
            "btn_save": "保存配置",
            "btn_reset": "重置默认",
            "search_placeholder": "搜索记忆、业务实体或输入问题按回车问 AI...",
            "settings_title": "全局记忆精灵 设置",
            "tab_ai": "AI 记忆引擎",
            "tab_privacy": "隐私与黑名单",
            "tab_lifelog": "数字编年史",
            "tab_appearance": "外观与主题",
            "tab_general": "权限与维护",

            // DeepSeek Harness 模型插件与授权中心
            "harness_title": "插件化模型与授权中心 (DeepSeek Harness 架构)",
            "harness_sub": "已实现「一切皆插件」自适应识别本地运行时、IDE软件配置与主流大模型开放平台",
            "btn_rescan_harness": "🔍 重新探查全部插件与授权",
            "harness_scanning": "正在并发探查本地模型端口、IDE 配置与 Shell 密钥...",
            "category_local": "本地离线运行时",
            "category_ide": "开发工具与 AI 软件",
            "category_cloud": "主流云端开放平台",
            "btn_adopt_plugin": "一键装配激活",
            "btn_open_portal": "打开控制台授权",
            "btn_import_ide": "从软件导入配置",
            "msg_adopted": "已成功激活并装配所选模型插件配置！",

            // 密钥池与连接
            "api_config_title": "API 连接参数与密钥池",
            "preset_label": "快捷预设:",
            "base_url_label": "Base URL:",
            "api_key_label": "API Key(s):",
            "model_name_label": "Model Name:",
            "key_rotation_tip": "支持多 Key 轮换容灾，每行或以逗号分隔一个 Key",
            "btn_test_conn": "测试连通性",
            "testing_conn": "正在测试连通性...",
            "test_success": "连接成功",
            "test_failed": "连接失败，请检查 Base URL、API Key 与模型名称",

            // 主题与外观
            "theme_amber": "阶跃暖橘",
            "theme_aurora": "极光深邃",
            "theme_neon": "电光紫霓",
            "theme_paper": "极简纸墨",
            "theme_system": "跟随系统",
            "lang_label": "界面语言 (Language):"
        ],
        "en": [
            "app_name": "ContextFlow",
            "app_sub": "Panoramic Workspace · v2.2",
            "nav_timeline": "Full Timeline",
            "nav_chat": "AI Memory Chat",
            "nav_daily": "Daily Wrap-up",
            "nav_weekly": "Weekly Wrap-up",
            "nav_suspended": "Suspended Tasks",
            "nav_settings": "Preferences",
            "focus_overview": "Today's Focus Overview",
            "focus_mins": "Focus Mins",
            "active_sessions": "Active Tasks",
            "cat_all": "All",
            "cat_dev": "Dev",
            "cat_browser": "Browser",
            "cat_chat": "Chat",
            "cat_doc": "Docs",
            "btn_restore": "Restore",
            "btn_complete": "Archive",
            "btn_ask": "Ask AI",
            "btn_save": "Save Settings",
            "btn_reset": "Reset",
            "search_placeholder": "Search memories, entities or press enter to ask AI...",
            "settings_title": "ContextFlow Preferences",
            "tab_ai": "AI Memory Engine",
            "tab_privacy": "Privacy & Filter",
            "tab_lifelog": "Digital Chronicle",
            "tab_appearance": "Appearance & Theme",
            "tab_general": "Permissions & DB",

            // DeepSeek Harness
            "harness_title": "Plugin Model & Auth Hub (DeepSeek Harness Architecture)",
            "harness_sub": "'Everything is a Plugin' auto-discovery for local runtimes, IDE configs & cloud LLMs",
            "btn_rescan_harness": "🔍 Rescan Plugins & Authorizations",
            "harness_scanning": "Scanning local model ports, IDE configs and shell keys in parallel...",
            "category_local": "Local Offline Runtimes",
            "category_ide": "Dev Tools & AI Software",
            "category_cloud": "Mainstream Cloud Platforms",
            "btn_adopt_plugin": "One-Click Adopt",
            "btn_open_portal": "Get API Key / Auth",
            "btn_import_ide": "Import from IDE",
            "msg_adopted": "Successfully adopted and activated model plugin configuration!",

            // API Config
            "api_config_title": "API Parameters & Multi-Key Failover Pool",
            "preset_label": "Quick Preset:",
            "base_url_label": "Base URL:",
            "api_key_label": "API Key(s):",
            "model_name_label": "Model Name:",
            "key_rotation_tip": "Supports multi-key failover pool. One key per line or comma-separated.",
            "btn_test_conn": "Test Connection",
            "testing_conn": "Testing connection...",
            "test_success": "Connection successful",
            "test_failed": "Connection failed. Please verify Base URL, API Key and Model Name.",

            // Theme & Appearance
            "theme_amber": "StepFun Amber",
            "theme_aurora": "Aurora Deep",
            "theme_neon": "Electric Neon",
            "theme_paper": "Minimal Paper",
            "theme_system": "System Native",
            "lang_label": "Interface Language:"
        ],
        "ja": [
            "app_name": "ContextFlow (記憶エルフ)",
            "app_sub": "パノラマワークスペース · v2.2",
            "nav_timeline": "全景タイムライン",
            "nav_chat": "AI記憶対话",
            "nav_daily": "本日日報",
            "nav_weekly": "今週週報",
            "nav_suspended": "中断タスク",
            "nav_settings": "環境設定",
            "focus_overview": "本日の集中状況",
            "focus_mins": "集中時間(分)",
            "active_sessions": "作業現場数",
            "cat_all": "すべて",
            "cat_dev": "開発",
            "cat_browser": "ブラウザ",
            "cat_chat": "連絡",
            "cat_doc": "文書",
            "btn_restore": "現場を復元",
            "btn_complete": "完了",
            "btn_ask": "AIに質問",
            "btn_save": "設定保存",
            "btn_reset": "初期化",
            "search_placeholder": "記憶やタスクを検索、またはEnterでAIに質問...",
            "settings_title": "ContextFlow 環境設定",
            "tab_ai": "AI記憶エンジン",
            "tab_privacy": "プライバシーと除外",
            "tab_lifelog": "デジタル年代記",
            "tab_appearance": "外観とテーマ",
            "tab_general": "権限とDB管理",

            // DeepSeek Harness
            "harness_title": "プラグイン型モデル＆認証ハブ (DeepSeek Harness 構造)",
            "harness_sub": "ローカル推論環境、IDE設定、主要クラウドLLMを自律検出・即時適用",
            "btn_rescan_harness": "🔍 全プラグイン・認証を再検出",
            "harness_scanning": "ローカルポート、IDE設定、Shell環境変数を並行スキャン中...",
            "category_local": "ローカルオフライン推論基盤",
            "category_ide": "開発ツール＆AIクライアント",
            "category_cloud": "主要クラウドLLMプラットフォーム",
            "btn_adopt_plugin": "ワンクリック適用",
            "btn_open_portal": "認証コンソールを開く",
            "btn_import_ide": "設定をインポート",
            "msg_adopted": "選択したモデルプラグインの設定を正常に適用しました！",

            // API Config
            "api_config_title": "API接続パラメータ＆フェイルオーバーキー配列",
            "preset_label": "プリセット:",
            "base_url_label": "Base URL:",
            "api_key_label": "API Key(s):",
            "model_name_label": "Model Name:",
            "key_rotation_tip": "複数キーの冗長化プール対応。改行またはカンマ区切りで入力。",
            "btn_test_conn": "接続テスト",
            "testing_conn": "接続確認中...",
            "test_success": "接続成功",
            "test_failed": "接続失敗。Base URL、API Key、モデル名を確認してください。",

            // Theme & Appearance
            "theme_amber": "階躍アンバー",
            "theme_aurora": "オーロラディープ",
            "theme_neon": "ネオンパープル",
            "theme_paper": "ミニマルペーパー",
            "theme_system": "システム準拠",
            "lang_label": "表示言語 (Language):"
        ]
    ]
}
