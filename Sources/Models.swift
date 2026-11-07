import Foundation

public enum SessionStatus: String, Codable, Sendable {
    case active       // 当前正在专注进行中
    case suspended    // 挂起待办（已失活超过阈值，且窗口仍未关闭）
    case completed    // 已收尾/手动标记完成/窗口已自然关闭
    case archived     // 超过48小时未碰，降级归档
}

public struct ContextItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let appName: String
    public let bundleId: String
    public let windowTitle: String
    public let url: String?
    public let filePath: String?
    public let project: String?
    public let extractedText: String?
    public let capturedAt: Date

    public init(
        id: UUID = UUID(),
        appName: String,
        bundleId: String,
        windowTitle: String,
        url: String? = nil,
        filePath: String? = nil,
        project: String? = nil,
        extractedText: String? = nil,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.appName = appName
        self.bundleId = bundleId
        self.windowTitle = windowTitle
        self.url = url
        self.filePath = filePath
        self.project = project
        self.extractedText = extractedText
        self.capturedAt = capturedAt
    }
}

public struct ContextSession: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var primaryApp: String
    public var items: [ContextItem]
    public var userNote: String?
    public var aiSummary: String?        // 智谱/Agnes 提炼的核心意图
    public var suggestion: String?       // AI 智能建议（下一步行动）
    public var thumbnailPath: String?     // 离开瞬间的微缩视窗截图路径
    public var detectedProject: String?   // 探测到的工程/项目目录
    public var createdAt: Date
    public var lastActiveAt: Date
    public var totalActiveSeconds: Int
    public var status: SessionStatus

    public init(
        id: UUID = UUID(),
        title: String,
        primaryApp: String,
        items: [ContextItem] = [],
        userNote: String? = nil,
        aiSummary: String? = nil,
        suggestion: String? = nil,
        thumbnailPath: String? = nil,
        detectedProject: String? = nil,
        createdAt: Date = Date(),
        lastActiveAt: Date = Date(),
        totalActiveSeconds: Int = 0,
        status: SessionStatus = .active
    ) {
        self.id = id
        self.title = title
        self.primaryApp = primaryApp
        self.items = items
        self.userNote = userNote
        self.aiSummary = aiSummary
        self.suggestion = suggestion
        self.thumbnailPath = thumbnailPath
        self.detectedProject = detectedProject
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.totalActiveSeconds = totalActiveSeconds
        self.status = status
    }

    /// 友好展示挂起时长，例如 "35分钟前搁置"
    public var suspendedAgoDescription: String {
        let seconds = Int(Date().timeIntervalSince(lastActiveAt))
        if seconds < 60 {
            return "刚刚搁置"
        } else if seconds < 3600 {
            return "\(seconds / 60) 分钟前搁置"
        } else {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return "\(hours) 小时 \(mins) 分钟前搁置"
        }
    }

    /// 友好展示累计专注时长，例如 "曾专注 24 分钟"
    public var totalActiveDescription: String {
        let mins = max(1, totalActiveSeconds / 60)
        if mins < 60 {
            return "曾专注 \(mins) 分钟"
        } else {
            return "曾专注 \(mins / 60) 小时 \(mins % 60) 分钟"
        }
    }
}

public struct DailyWrapUp: Codable, Sendable {
    public let date: String             // YYYY-MM-DD
    public let generatedAt: Date
    public let summary: String          // 今日工作核心总结
    public let keyProjects: [String]    // 关键涉及工程/业务
    public let totalFocusMinutes: Int   // 今日累计专注分钟数
    public let sessionCount: Int        // 今日完成/挂起任务数
    public let suggestions: [String]    // 改进与下一步建议

    public init(
        date: String,
        generatedAt: Date = Date(),
        summary: String,
        keyProjects: [String],
        totalFocusMinutes: Int,
        sessionCount: Int,
        suggestions: [String] = []
    ) {
        self.date = date
        self.generatedAt = generatedAt
        self.summary = summary
        self.keyProjects = keyProjects
        self.totalFocusMinutes = totalFocusMinutes
        self.sessionCount = sessionCount
        self.suggestions = suggestions
    }

    public var markdown: String {
        var md = "# ☀️ 全局工作日报 (\(date))\n\n"
        md += "### 🎯 今日核心成果\n\(summary)\n\n"
        md += "### ⏱ 专注与业务分布\n"
        let hours = String(format: "%.1f", Double(totalFocusMinutes) / 60.0)
        md += "- 累计专注时长: \(totalFocusMinutes) 分钟 (约 \(hours) 小时)\n"
        md += "- 攻坚业务现场: \(sessionCount) 个\n"
        if !keyProjects.isEmpty {
            md += "- 核心业务项目: \(keyProjects.joined(separator: "、"))\n"
        }
        if !suggestions.isEmpty {
            md += "\n### ⏳ 待办与跟进建议\n"
            md += suggestions.map { "• " + $0 }.joined(separator: "\n")
            md += "\n"
        }
        md += "---\n*本工作日报由 全局记忆精灵 (ContextFlow) 智能提炼生成*"
        return md
    }
}

// MARK: - 周报数据结构与分布

public struct ProjectTimeShare: Codable, Sendable, Identifiable {
    public var id: String { projectName }
    public let projectName: String
    public let focusMinutes: Int
    public let percentage: Int
    public let primaryApp: String

    public init(projectName: String, focusMinutes: Int, percentage: Int, primaryApp: String) {
        self.projectName = projectName
        self.focusMinutes = focusMinutes
        self.percentage = percentage
        self.primaryApp = primaryApp
    }
}

public struct DailyBriefSummary: Codable, Sendable, Identifiable {
    public var id: String { date }
    public let date: String
    public let dayOfWeek: String
    public let focusMinutes: Int
    public let sessionCount: Int
    public let highlight: String

    public init(date: String, dayOfWeek: String, focusMinutes: Int, sessionCount: Int, highlight: String) {
        self.date = date
        self.dayOfWeek = dayOfWeek
        self.focusMinutes = focusMinutes
        self.sessionCount = sessionCount
        self.highlight = highlight
    }
}

public struct WeeklyWrapUp: Codable, Sendable {
    public let weekRange: String
    public let generatedAt: Date
    public let summary: String
    public let totalFocusMinutes: Int
    public let totalSessionCount: Int
    public let projectDistribution: [ProjectTimeShare]
    public let dailyBreakdown: [DailyBriefSummary]
    public let nextWeekPlans: [String]

    public init(
        weekRange: String,
        generatedAt: Date = Date(),
        summary: String,
        totalFocusMinutes: Int,
        totalSessionCount: Int,
        projectDistribution: [ProjectTimeShare],
        dailyBreakdown: [DailyBriefSummary] = [],
        nextWeekPlans: [String] = []
    ) {
        self.weekRange = weekRange
        self.generatedAt = generatedAt
        self.summary = summary
        self.totalFocusMinutes = totalFocusMinutes
        self.totalSessionCount = totalSessionCount
        self.projectDistribution = projectDistribution
        self.dailyBreakdown = dailyBreakdown
        self.nextWeekPlans = nextWeekPlans
    }

    public var markdown: String {
        var md = "# 📅 全局工作周报 (\(weekRange))\n\n"
        md += "### 🎯 本周核心攻坚与产出综述\n\(summary)\n\n"
        md += "### ⏱ 本周整体投入\n"
        let hours = String(format: "%.1f", Double(totalFocusMinutes) / 60.0)
        md += "- 累计专注时长: \(totalFocusMinutes) 分钟 (约 \(hours) 小时)\n"
        md += "- 攻坚业务现场: \(totalSessionCount) 个\n\n"

        if !projectDistribution.isEmpty {
            md += "### 📊 项目时间分布与研发占比\n"
            for p in projectDistribution {
                let pHours = String(format: "%.1f", Double(p.focusMinutes) / 60.0)
                md += "- **\(p.projectName)**: \(p.percentage)% (\(p.focusMinutes) 分钟 / \(pHours)h) · 主力工具: \(p.primaryApp)\n"
            }
            md += "\n"
        }

        if !dailyBreakdown.isEmpty {
            md += "### 🗓 本周每日工作脉络\n"
            for d in dailyBreakdown {
                md += "- **\(d.date) (\(d.dayOfWeek))**: \(d.focusMinutes) 分钟 / \(d.sessionCount) 现场 — \(d.highlight)\n"
            }
            md += "\n"
        }

        if !nextWeekPlans.isEmpty {
            md += "### 🚀 下周关键攻坚与推进规划\n"
            for plan in nextWeekPlans {
                md += "- \(plan)\n"
            }
            md += "\n"
        }

        md += "---\n*本工作周报由 全局记忆精灵 (ContextFlow) 智能提炼生成*"
        return md
    }
}
