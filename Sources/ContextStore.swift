import Foundation

public struct AppSettings: Codable, Sendable {
    // MARK: - 1. AI 意图与复盘引擎 (开源 BYOK)
    public var aiProvider: String          // agnes, deepseek, zhipu, openai, siliconflow, ollama, custom
    public var aiBaseURL: String           // API 端点
    public var aiApiKey: String            // 用户填写的 API Key (支持多行/换行/逗号分隔的密钥池)
    public var aiModel: String             // 模型名称
    public var enableKeyRotation: Bool     // 是否开启多 Key 智能轮换与故障转移 (默认 true)

    /// 解析出所有可用的独立 API Key 列表
    public var apiKeys: [String] {
        aiApiKey
            .components(separatedBy: CharacterSet.newlines.union(CharacterSet(charactersIn: ",")))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

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

    // MARK: - 5. 外观与主题
    public var theme: String               // system, amber, aurora, neon, paper

    public init(
        aiProvider: String = "agnes",
        aiBaseURL: String = "https://api.agnes-ai.cn/v1",
        aiApiKey: String = "",
        aiModel: String = "agnes-3.0-flash",
        enableKeyRotation: Bool = true,
        enableGitHubSync: Bool = false,
        gitHubRepo: String = "",
        syncIntervalHours: Int = 2,
        suspendThresholdSeconds: Int = 10,
        transientThresholdSeconds: Int = 30,
        maxDisplaySuspended: Int = 5,
        enableThumbnails: Bool = true,
        customIgnoredApps: [String] = ["1Password", "KeePassXC", "Keychain Access"],
        theme: String = "amber"
    ) {
        self.aiProvider = aiProvider
        self.aiBaseURL = aiBaseURL
        self.aiApiKey = aiApiKey
        self.aiModel = aiModel
        self.enableKeyRotation = enableKeyRotation
        self.enableGitHubSync = enableGitHubSync
        self.gitHubRepo = gitHubRepo
        self.syncIntervalHours = syncIntervalHours
        self.suspendThresholdSeconds = suspendThresholdSeconds
        self.transientThresholdSeconds = transientThresholdSeconds
        self.maxDisplaySuspended = maxDisplaySuspended
        self.enableThumbnails = enableThumbnails
        self.customIgnoredApps = customIgnoredApps
        self.theme = theme
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.aiProvider = try container.decodeIfPresent(String.self, forKey: .aiProvider) ?? "agnes"
        self.aiBaseURL = try container.decodeIfPresent(String.self, forKey: .aiBaseURL) ?? "https://api.agnes-ai.cn/v1"
        self.aiApiKey = try container.decodeIfPresent(String.self, forKey: .aiApiKey) ?? ""
        self.aiModel = try container.decodeIfPresent(String.self, forKey: .aiModel) ?? "agnes-3.0-flash"
        self.enableKeyRotation = try container.decodeIfPresent(Bool.self, forKey: .enableKeyRotation) ?? true

        self.enableGitHubSync = try container.decodeIfPresent(Bool.self, forKey: .enableGitHubSync) ?? false
        self.gitHubRepo = try container.decodeIfPresent(String.self, forKey: .gitHubRepo) ?? ""
        self.syncIntervalHours = try container.decodeIfPresent(Int.self, forKey: .syncIntervalHours) ?? 2

        self.suspendThresholdSeconds = try container.decodeIfPresent(Int.self, forKey: .suspendThresholdSeconds) ?? 10
        self.transientThresholdSeconds = try container.decodeIfPresent(Int.self, forKey: .transientThresholdSeconds) ?? 30
        self.maxDisplaySuspended = try container.decodeIfPresent(Int.self, forKey: .maxDisplaySuspended) ?? 5
        self.enableThumbnails = try container.decodeIfPresent(Bool.self, forKey: .enableThumbnails) ?? true
        self.customIgnoredApps = try container.decodeIfPresent([String].self, forKey: .customIgnoredApps) ?? ["1Password", "KeePassXC", "Keychain Access"]
        self.theme = try container.decodeIfPresent(String.self, forKey: .theme) ?? "amber"
    }
}

public struct StoragePayload: Codable, Sendable {
    public var settings: AppSettings
    public var activeSession: ContextSession?
    public var sessions: [ContextSession]
}

/// 统一存储协调器 (全面依托 SQLite 关系型与 FTS5 全文检索引擎，双向保证数据强一致性与极速读取)
public final class ContextStore: @unchecked Sendable {
    public static let shared = ContextStore()

    private let fileURL: URL
    private let db = DatabaseManager.shared
    private let queue = DispatchQueue(label: "app.memoryelf.store", qos: .utility)

    public static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            if let dateStr = try? container.decode(String.self) {
                let isoWithFrac = ISO8601DateFormatter()
                isoWithFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoWithFrac.date(from: dateStr) {
                    return date
                }
                let isoStd = ISO8601DateFormatter()
                if let date = isoStd.date(from: dateStr) {
                    return date
                }
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US_POSIX")
                df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                if let date = df.date(from: dateStr) {
                    return date
                }
            }
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解析日期字段")
        }
        return decoder
    }

    public static func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folder = home.appendingPathComponent(".contextflow", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.fileURL = folder.appendingPathComponent("data.json")
    }

    public func load() -> StoragePayload {
        // 优先从 SQLite 数据库加载已持久化的所有现场
        let dbSessions = db.fetchAllSessions(limit: 200)

        // 读取 settings (严格使用统一 dateDecodingStrategy 兼容解码)
        var currentSettings = AppSettings()
        var active: ContextSession? = nil

        let decoder = Self.makeJSONDecoder()
        if let data = try? Data(contentsOf: fileURL),
           let payload = try? decoder.decode(StoragePayload.self, from: data) {
            currentSettings = payload.settings
            active = payload.activeSession
        }

        // P0-04: 优先从系统原生 Keychain 安全加载 API Key，杜绝明文泄露
        if let secKey = KeychainHelper.shared.loadApiKey(), !secKey.isEmpty {
            currentSettings.aiApiKey = secKey
        } else if !currentSettings.aiApiKey.isEmpty {
            // 平滑向后兼容：自动迁移旧版本 JSON 明文 Key 到系统 Keychain 并保护
            KeychainHelper.shared.saveApiKey(currentSettings.aiApiKey)
        }

        // 若 SQLite 中已有更丰富的数据，以 SQLite 现场为准，否则回退到 JSON 中的 sessions
        let finalSessions: [ContextSession]
        if !dbSessions.isEmpty {
            finalSessions = dbSessions
        } else if let data = try? Data(contentsOf: fileURL),
                  let payload = try? decoder.decode(StoragePayload.self, from: data) {
            finalSessions = payload.sessions
        } else {
            finalSessions = []
        }

        return StoragePayload(
            settings: currentSettings,
            activeSession: active,
            sessions: finalSessions
        )
    }

    public func save(settings: AppSettings, active: ContextSession?, sessions: [ContextSession]) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // P0-04: API Key 安全写入系统钥匙串，杜绝落盘泄露
            if !settings.aiApiKey.isEmpty {
                KeychainHelper.shared.saveApiKey(settings.aiApiKey)
            }

            // 1. 同步全量持久化至 SQLite 核心数据库
            for s in sessions {
                self.db.upsertSession(s)
            }
            if let act = active {
                self.db.upsertSession(act)
            }

            // 2. 写入轻量级快照 JSON (对落盘凭证进行安全置空，磁盘零明文存储敏感 Key)
            var diskSettings = settings
            diskSettings.aiApiKey = "" // 敏感凭据纯系统 Keychain 保管
            let payload = StoragePayload(settings: diskSettings, activeSession: active, sessions: sessions)
            let encoder = Self.makeJSONEncoder()
            if let data = try? encoder.encode(payload) {
                try? data.write(to: self.fileURL, options: .atomic)
            }
        }
    }

    /// 基于 SQLite3 FTS5 引擎的高性能全文搜索
    public func search(query: String, category: String? = nil) -> [ContextSession] {
        return db.searchSessionsFTS(query: query, category: category)
    }
}
