import SwiftUI
import Cocoa

public enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case amber = "amber"       // 阶跃暖橘 (对标阶跃星AI)
    case aurora = "aurora"     // 极光深邃 (程序员黑客风)
    case neon = "neon"         // 电光紫霓 (未来科技风)
    case paper = "paper"       // 极简纸墨 (纯净专注风)

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .amber: return "阶跃暖橘"
        case .aurora: return "极光深邃"
        case .neon: return "电光紫霓"
        case .paper: return "极简纸墨"
        }
    }

    public var subtitle: String {
        switch self {
        case .system: return "原生毛玻璃，匹配 macOS 浅色/深色"
        case .amber: return "阶跃星AI同款暖色调，温暖高亮与柔光"
        case .aurora: return "黑曜石暗黑底色，搭配薄荷极光蓝"
        case .neon: return "高对比度深紫电光，硬核极客科技质感"
        case .paper: return "纯粹素雅灰白纸面，专注内容无视觉干扰"
        }
    }

    public var accentColor: Color {
        switch self {
        case .system: return Color.orange
        case .amber: return Color(red: 1.0, green: 0.45, blue: 0.08) // #FF7315
        case .aurora: return Color(red: 0.0, green: 0.88, blue: 0.75) // #00E0BF
        case .neon: return Color(red: 0.65, green: 0.35, blue: 1.0)  // #A659FF
        case .paper: return Color(red: 0.25, green: 0.25, blue: 0.28) // 墨色
        }
    }

    public var secondaryAccentColor: Color {
        switch self {
        case .system: return Color.blue
        case .amber: return Color(red: 1.0, green: 0.65, blue: 0.2)
        case .aurora: return Color(red: 0.1, green: 0.65, blue: 1.0)
        case .neon: return Color(red: 0.95, green: 0.25, blue: 0.8)
        case .paper: return Color(red: 0.5, green: 0.5, blue: 0.55)
        }
    }

    public var badgeBackground: Color {
        switch self {
        case .system: return Color.orange.opacity(0.12)
        case .amber: return Color(red: 1.0, green: 0.45, blue: 0.08).opacity(0.15)
        case .aurora: return Color(red: 0.0, green: 0.88, blue: 0.75).opacity(0.15)
        case .neon: return Color(red: 0.65, green: 0.35, blue: 1.0).opacity(0.15)
        case .paper: return Color.primary.opacity(0.08)
        }
    }

    public var previewColors: [Color] {
        switch self {
        case .system: return [.orange, .blue]
        case .amber: return [Color(red: 1.0, green: 0.45, blue: 0.08), Color(red: 1.0, green: 0.7, blue: 0.2)]
        case .aurora: return [Color(red: 0.0, green: 0.88, blue: 0.75), Color(red: 0.05, green: 0.4, blue: 0.9)]
        case .neon: return [Color(red: 0.65, green: 0.35, blue: 1.0), Color(red: 0.95, green: 0.25, blue: 0.8)]
        case .paper: return [Color(red: 0.2, green: 0.2, blue: 0.25), Color(red: 0.6, green: 0.6, blue: 0.65)]
        }
    }
}

@MainActor
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()

    @Published public var currentTheme: AppTheme = .amber
    @Published public var glassOpacity: Double = 0.85

    private init() {
        let savedThemeRaw = ContextStore.shared.load().settings.theme
        if let theme = AppTheme(rawValue: savedThemeRaw) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .amber
        }
    }

    public func applyTheme(_ theme: AppTheme) {
        self.currentTheme = theme
        var currentSettings = ContextStore.shared.load().settings
        currentSettings.theme = theme.rawValue
        ContextEngine.shared.settings = currentSettings
        ContextEngine.shared.persistState()
    }
}
