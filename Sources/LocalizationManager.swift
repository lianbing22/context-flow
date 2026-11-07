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
        // 读取已保存的语言设定，默认中文
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

    // 多语言字典库
    private let localizedStrings: [String: [String: String]] = [
        "zh-Hans": [
            "app_name": "全局记忆精灵",
            "app_sub": "全景工作台 · v2.0",
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
            "btn_restore": "恢复当时视窗现场",
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
            "btn_detect_models": "🔍 智能探测本地模型与客户端配置",
            "detecting": "正在并发探测本地端口与环境变量...",
            "detect_result_title": "本地模型运行时与凭据发现",
            "btn_adopt": "一键装配激活",
            "theme_amber": "阶跃暖橘",
            "theme_aurora": "极光深邃",
            "theme_neon": "电光紫霓",
            "theme_paper": "极简纸墨",
            "theme_system": "跟随系统"
        ],
        "en": [
            "app_name": "ContextFlow",
            "app_sub": "Panoramic Workspace · v2.0",
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
            "btn_restore": "Restore Window Context",
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
            "btn_detect_models": "🔍 Auto-Discover Local Models & Configs",
            "detecting": "Probing local model endpoints & environment keys...",
            "detect_result_title": "Discovered Local Models & Credentials",
            "btn_adopt": "Adopt Configuration",
            "theme_amber": "StepFun Amber",
            "theme_aurora": "Aurora Deep",
            "theme_neon": "Electric Neon",
            "theme_paper": "Minimal Paper",
            "theme_system": "System Native"
        ],
        "ja": [
            "app_name": "ContextFlow (記憶エルフ)",
            "app_sub": "パノラマワークスペース · v2.0",
            "nav_timeline": "全景タイムライン",
            "nav_chat": "AI記憶対話",
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
            "btn_restore": "当時のウィンドウ現場を復元",
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
            "btn_detect_models": "🔍 ローカルモデルと設定を自動検出",
            "detecting": "ローカルポートと環境変数を検出中...",
            "detect_result_title": "検出されたモデルと認証情報",
            "btn_adopt": "設定を適用",
            "theme_amber": "階躍アンバー",
            "theme_aurora": "オーロラディープ",
            "theme_neon": "ネオンパープル",
            "theme_paper": "ミニマルペーパー",
            "theme_system": "システム準拠"
        ]
    ]
}
