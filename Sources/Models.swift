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
}
