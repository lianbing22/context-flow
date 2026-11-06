import Foundation

public struct AppSettings: Codable, Sendable {
    // MARK: - 1. AI 意图与复盘引擎 (开源 BYOK)
    public var aiProvider: String          // deepseek, zhipu, openai, siliconflow, ollama, custom
    public var aiBaseURL: String           // API 端点
    public var aiApiKey: String            // 用户填写的 API Key
    public var aiModel: String             // 模型名称

    // MARK: - 2. 数字编年史与备份
    public var enableGitHubSync: Bool      // 是否开启 GitHub 私有归档同步
    public var gitHubRepo: String          // 用户自己的仓库名，如 "username/my-digital-lifelog"
    public var syncIntervalHours: Int      // 同步周期 (小时)

    // MARK: - 3. 感知与微打断
    public var suspendThresholdSeconds: Int // 判定为挂起所需的失活秒数 (默认 10)
    public var transientThresholdSeconds: Int // 瞬态忽略秒数 (默认 30)
    public var maxDisplaySuspended: Int    // 状态栏最多展示几个核心现场 (默认 5)
    public var enableThumbnails: Bool      // 是否保留视窗快照微缩图 (默认 true)

    // MARK: - 4. 隐私黑名单
    public var customIgnoredApps: [String] // 用户自定义忽略的应用名单 (如 1Password, 银行等)

    public init(
        aiProvider: String = "deepseek",
        aiBaseURL: String = "https://api.deepseek.com/v1",
        aiApiKey: String = "",
        aiModel: String = "deepseek-chat",
        enableGitHubSync: Bool = false,
        gitHubRepo: String = "",
        syncIntervalHours: Int = 2,
        suspendThresholdSeconds: Int = 10,
        transientThresholdSeconds: Int = 30,
        maxDisplaySuspended: Int = 5,
        enableThumbnails: Bool = true,
        customIgnoredApps: [String] = ["1Password", "KeePassXC", "Keychain Access"]
    ) {
        self.aiProvider = aiProvider
        self.aiBaseURL = aiBaseURL
        self.aiApiKey = aiApiKey
        self.aiModel = aiModel
        self.enableGitHubSync = enableGitHubSync
        self.gitHubRepo = gitHubRepo
        self.syncIntervalHours = syncIntervalHours
        self.suspendThresholdSeconds = suspendThresholdSeconds
        self.transientThresholdSeconds = transientThresholdSeconds
        self.maxDisplaySuspended = maxDisplaySuspended
        self.enableThumbnails = enableThumbnails
        self.customIgnoredApps = customIgnoredApps
    }
}

public struct StoragePayload: Codable, Sendable {
    public var settings: AppSettings
    public var activeSession: ContextSession?
    public var sessions: [ContextSession]
}

public final class ContextStore: @unchecked Sendable {
    public static let shared = ContextStore()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "app.memoryelf.store", qos: .utility)

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folder = home.appendingPathComponent(".contextflow", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.fileURL = folder.appendingPathComponent("data.json")
    }

    public func load() -> StoragePayload {
        guard let data = try? Data(contentsOf: fileURL) else {
            return StoragePayload(
                settings: AppSettings(),
                activeSession: nil,
                sessions: []
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let payload = try? decoder.decode(StoragePayload.self, from: data) {
            return payload
        }

        return StoragePayload(
            settings: AppSettings(),
            activeSession: nil,
            sessions: []
        )
    }

    public func save(settings: AppSettings, active: ContextSession?, sessions: [ContextSession]) {
        queue.async {
            let payload = StoragePayload(settings: settings, activeSession: active, sessions: sessions)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(payload) {
                try? data.write(to: self.fileURL, options: .atomic)
            }
        }
    }
}
