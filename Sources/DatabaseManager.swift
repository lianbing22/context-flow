import Foundation
import SQLite3

/// 商业级本地 SQLite 数据库引擎 (基于 macOS 原生 libsqlite3，支持 WAL 高并发模式与 FTS5 全文搜索)
public final class DatabaseManager: @unchecked Sendable {
    public static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "app.memoryelf.database", qos: .userInitiated)
    private let dbPath: String

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folder = home.appendingPathComponent(".contextflow", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileURL = folder.appendingPathComponent("contextflow.sqlite3")
        self.dbPath = fileURL.path

        openDatabase()
        createTables()
        optimizeDatabase()
    }

    deinit {
        if db != nil {
            sqlite3_close_v2(db)
        }
    }

    // MARK: - 数据库初始化与 WAL 优化

    private func openDatabase() {
        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db))
            AppLogger.shared.log(tag: "SQLITE_ERROR", message: "无法打开 SQLite 数据库: \(errmsg)")
        } else {
            AppLogger.shared.log(tag: "SQLITE_INIT", message: "SQLite 数据库已成功就绪: \(dbPath)")
        }
    }

    private func optimizeDatabase() {
        // 开启 WAL (Write-Ahead Logging) 模式，大幅提升并发读写吞吐量与抗崩溃能力
        executeRaw(sql: "PRAGMA journal_mode = WAL;")
        executeRaw(sql: "PRAGMA synchronous = NORMAL;")
        executeRaw(sql: "PRAGMA foreign_keys = ON;")
        executeRaw(sql: "PRAGMA cache_size = -8000;") // 8MB 高速缓存
    }

    private func executeRaw(sql: String) {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            if let err = err {
                let msg = String(cString: err)
                AppLogger.shared.log(tag: "SQLITE_ERROR", message: "执行 SQL 失败: \(msg) | SQL: \(sql)")
                sqlite3_free(err)
            }
        }
    }

    // MARK: - 数据表结构构建 (结构化事件流 + 会话 + 全文索引 + 复盘)

    private func createTables() {
        // 1. 工作现场核心表 (sessions)
        let createSessionsSQL = """
        CREATE TABLE IF NOT EXISTS context_sessions (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            primary_app TEXT NOT NULL,
            bundle_id TEXT,
            detected_project TEXT,
            ai_summary TEXT,
            suggestion TEXT,
            status TEXT NOT NULL,
            total_active_seconds INTEGER DEFAULT 0,
            thumbnail_path TEXT,
            created_at REAL NOT NULL,
            last_active_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_sessions_last_active ON context_sessions(last_active_at DESC);
        CREATE INDEX IF NOT EXISTS idx_sessions_status ON context_sessions(status);
        CREATE INDEX IF NOT EXISTS idx_sessions_project ON context_sessions(detected_project);
        """
        executeRaw(sql: createSessionsSQL)

        // 2. 细粒度物理窗口轨迹足迹表 (timeline_events)
        let createEventsSQL = """
        CREATE TABLE IF NOT EXISTS timeline_events (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            app_name TEXT NOT NULL,
            bundle_id TEXT NOT NULL,
            window_title TEXT NOT NULL,
            url TEXT,
            file_path TEXT,
            extracted_text TEXT,
            captured_at REAL NOT NULL,
            FOREIGN KEY(session_id) REFERENCES context_sessions(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_events_session_id ON timeline_events(session_id);
        CREATE INDEX IF NOT EXISTS idx_events_captured_at ON timeline_events(captured_at DESC);
        """
        executeRaw(sql: createEventsSQL)

        // 3. FTS5 全文搜索虚拟表 (对业务实体、窗口标题、网址与文本建立倒排索引)
        let createFTSSQL = """
        CREATE VIRTUAL TABLE IF NOT EXISTS fts_timeline USING fts5(
            session_id UNINDEXED,
            app_name,
            window_title,
            project,
            ai_summary,
            extracted_text,
            tokenize = 'unicode61'
        );
        """
        executeRaw(sql: createFTSSQL)

        // 4. 每日工作复盘日报表 (daily_reports)
        let createReportsSQL = """
        CREATE TABLE IF NOT EXISTS daily_reports (
            date TEXT PRIMARY KEY,
            summary TEXT NOT NULL,
            key_projects TEXT NOT NULL,
            suggestions TEXT NOT NULL,
            total_focus_minutes INTEGER NOT NULL,
            session_count INTEGER NOT NULL,
            created_at REAL NOT NULL
        );
        """
        executeRaw(sql: createReportsSQL)

        // 5. 全局系统配置表 (settings)
        let createSettingsSQL = """
        CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """
        executeRaw(sql: createSettingsSQL)
    }

    // MARK: - 会话 (ContextSession) 数据持久化操作

    public func upsertSession(_ s: ContextSession) {
        dbQueue.sync {
            let sql = """
            INSERT INTO context_sessions (
                id, title, primary_app, bundle_id, detected_project, ai_summary,
                suggestion, status, total_active_seconds, thumbnail_path, created_at, last_active_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                primary_app = excluded.primary_app,
                bundle_id = excluded.bundle_id,
                detected_project = excluded.detected_project,
                ai_summary = excluded.ai_summary,
                suggestion = excluded.suggestion,
                status = excluded.status,
                total_active_seconds = excluded.total_active_seconds,
                thumbnail_path = excluded.thumbnail_path,
                last_active_at = excluded.last_active_at;
            """

            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                let idStr = s.id.uuidString
                sqlite3_bind_text(stmt, 1, (idStr as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (s.title as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (s.primaryApp as NSString).utf8String, -1, nil)
                if let b = s.items.first?.bundleId {
                    sqlite3_bind_text(stmt, 4, (b as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 4)
                }

                if let p = s.detectedProject {
                    sqlite3_bind_text(stmt, 5, (p as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 5)
                }

                if let sum = s.aiSummary {
                    sqlite3_bind_text(stmt, 6, (sum as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 6)
                }

                if let sug = s.suggestion {
                    sqlite3_bind_text(stmt, 7, (sug as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 7)
                }

                sqlite3_bind_text(stmt, 8, (s.status.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_int64(stmt, 9, Int64(s.totalActiveSeconds))
                if let thumb = s.thumbnailPath {
                    sqlite3_bind_text(stmt, 10, (thumb as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 10)
                }

                sqlite3_bind_double(stmt, 11, s.createdAt.timeIntervalSince1970)
                sqlite3_bind_double(stmt, 12, s.lastActiveAt.timeIntervalSince1970)

                sqlite3_step(stmt)
                sqlite3_finalize(stmt)

                // 同步索引至 FTS 全文搜索表
                updateFTSIndex(session: s)
            }

            // 保存包含的子项
            for item in s.items {
                insertEvent(item: item, sessionId: s.id)
            }
        }
    }

    public func insertEvent(item: ContextItem, sessionId: UUID) {
        let sql = """
        INSERT OR REPLACE INTO timeline_events (
            id, session_id, app_name, bundle_id, window_title, url, file_path, extracted_text, captured_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (item.id.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (sessionId.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (item.appName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (item.bundleId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 5, (item.windowTitle as NSString).utf8String, -1, nil)

            if let u = item.url {
                sqlite3_bind_text(stmt, 6, (u as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 6)
            }

            if let f = item.filePath {
                sqlite3_bind_text(stmt, 7, (f as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 7)
            }

            if let t = item.extractedText {
                sqlite3_bind_text(stmt, 8, (t as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 8)
            }

            sqlite3_bind_double(stmt, 9, item.capturedAt.timeIntervalSince1970)

            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }

    private func updateFTSIndex(session s: ContextSession) {
        // 先删除旧的全文记录
        let delSQL = "DELETE FROM fts_timeline WHERE session_id = ?;"
        var delStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, delSQL, -1, &delStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(delStmt, 1, (s.id.uuidString as NSString).utf8String, -1, nil)
            sqlite3_step(delStmt)
            sqlite3_finalize(delStmt)
        }

        // 插入新的全文索引记录
        let insSQL = """
        INSERT INTO fts_timeline (session_id, app_name, window_title, project, ai_summary, extracted_text)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        var insStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, insSQL, -1, &insStmt, nil) == SQLITE_OK {
            let combinedText = s.items.compactMap { $0.extractedText }.joined(separator: " ")
            let combinedTitles = s.items.map { $0.windowTitle }.joined(separator: " ")

            sqlite3_bind_text(insStmt, 1, (s.id.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insStmt, 2, (s.primaryApp as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insStmt, 3, (combinedTitles as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insStmt, 4, ((s.detectedProject ?? "") as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insStmt, 5, ((s.aiSummary ?? s.title) as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insStmt, 6, (combinedText as NSString).utf8String, -1, nil)

            sqlite3_step(insStmt)
            sqlite3_finalize(insStmt)
        }
    }

    // MARK: - 查询接口 (支持毫秒级 SQL & FTS5 全文搜索)

    public func fetchAllSessions(limit: Int = 100) -> [ContextSession] {
        dbQueue.sync {
            let sql = "SELECT * FROM context_sessions ORDER BY last_active_at DESC LIMIT ?;"
            var stmt: OpaquePointer?
            var list: [ContextSession] = []

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(limit))
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let s = parseSession(from: stmt) {
                        list.append(s)
                    }
                }
                sqlite3_finalize(stmt)
            }
            return list
        }
    }

    public func fetchSuspendedSessions() -> [ContextSession] {
        dbQueue.sync {
            let sql = "SELECT * FROM context_sessions WHERE status = 'suspended' ORDER BY last_active_at DESC;"
            var stmt: OpaquePointer?
            var list: [ContextSession] = []

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let s = parseSession(from: stmt) {
                        list.append(s)
                    }
                }
                sqlite3_finalize(stmt)
            }
            return list
        }
    }

    public func searchSessionsFTS(query: String, category: String? = nil, limit: Int = 50) -> [ContextSession] {
        dbQueue.sync {
            let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanQuery.isEmpty {
                return fetchAllSessions(limit: limit)
            }

            // 使用 FTS5 全文匹配
            let ftsSQL = """
            SELECT DISTINCT s.* FROM context_sessions s
            JOIN fts_timeline f ON s.id = f.session_id
            WHERE fts_timeline MATCH ?
            ORDER BY s.last_active_at DESC LIMIT ?;
            """

            var stmt: OpaquePointer?
            var list: [ContextSession] = []

            if sqlite3_prepare_v2(db, ftsSQL, -1, &stmt, nil) == SQLITE_OK {
                let matchArg = "\"\(cleanQuery)*\""
                sqlite3_bind_text(stmt, 1, (matchArg as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 2, Int32(limit))

                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let s = parseSession(from: stmt) {
                        list.append(s)
                    }
                }
                sqlite3_finalize(stmt)
            }

            // 如果 FTS 没有结果，做 LIKE 模糊兜底
            if list.isEmpty {
                let likeSQL = """
                SELECT * FROM context_sessions
                WHERE title LIKE ? OR primary_app LIKE ? OR ai_summary LIKE ? OR detected_project LIKE ?
                ORDER BY last_active_at DESC LIMIT ?;
                """
                var likeStmt: OpaquePointer?
                if sqlite3_prepare_v2(db, likeSQL, -1, &likeStmt, nil) == SQLITE_OK {
                    let wildcard = "%\(cleanQuery)%"
                    sqlite3_bind_text(likeStmt, 1, (wildcard as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(likeStmt, 2, (wildcard as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(likeStmt, 3, (wildcard as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(likeStmt, 4, (wildcard as NSString).utf8String, -1, nil)
                    sqlite3_bind_int(likeStmt, 5, Int32(limit))

                    while sqlite3_step(likeStmt) == SQLITE_ROW {
                        if let s = parseSession(from: likeStmt) {
                            list.append(s)
                        }
                    }
                    sqlite3_finalize(likeStmt)
                }
            }

            return list
        }
    }

    private func parseSession(from stmt: OpaquePointer?) -> ContextSession? {
        guard let stmt = stmt else { return nil }

        guard let idCString = sqlite3_column_text(stmt, 0),
              let id = UUID(uuidString: String(cString: idCString)),
              let titleCString = sqlite3_column_text(stmt, 1),
              let appCString = sqlite3_column_text(stmt, 2) else {
            return nil
        }

        let title = String(cString: titleCString)
        let primaryApp = String(cString: appCString)

        var project: String? = nil
        if let pCString = sqlite3_column_text(stmt, 4) {
            project = String(cString: pCString)
        }

        var summary: String? = nil
        if let sCString = sqlite3_column_text(stmt, 5) {
            summary = String(cString: sCString)
        }

        var suggestion: String? = nil
        if let sugCString = sqlite3_column_text(stmt, 6) {
            suggestion = String(cString: sugCString)
        }

        var status: SessionStatus = .active
        if let stCString = sqlite3_column_text(stmt, 7) {
            status = SessionStatus(rawValue: String(cString: stCString)) ?? .active
        }

        let activeSeconds = Int(sqlite3_column_int64(stmt, 8))

        var thumbnail: String? = nil
        if let thCString = sqlite3_column_text(stmt, 9) {
            thumbnail = String(cString: thCString)
        }

        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 10))
        let lastActiveAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 11))

        // 查询该 Session 下包含的 items
        let items = fetchEvents(sessionId: id)

        return ContextSession(
            id: id,
            title: title,
            primaryApp: primaryApp,
            items: items,
            aiSummary: summary,
            suggestion: suggestion,
            thumbnailPath: thumbnail,
            detectedProject: project,
            createdAt: createdAt,
            lastActiveAt: lastActiveAt,
            totalActiveSeconds: activeSeconds,
            status: status
        )
    }

    private func fetchEvents(sessionId: UUID) -> [ContextItem] {
        let sql = "SELECT * FROM timeline_events WHERE session_id = ? ORDER BY captured_at ASC;"
        var stmt: OpaquePointer?
        var items: [ContextItem] = []

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (sessionId.uuidString as NSString).utf8String, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let idCString = sqlite3_column_text(stmt, 0),
                   let id = UUID(uuidString: String(cString: idCString)),
                   let appCString = sqlite3_column_text(stmt, 2),
                   let bundleCString = sqlite3_column_text(stmt, 3),
                   let titleCString = sqlite3_column_text(stmt, 4) {

                    let appName = String(cString: appCString)
                    let bundleId = String(cString: bundleCString)
                    let winTitle = String(cString: titleCString)

                    var url: String? = nil
                    if let uC = sqlite3_column_text(stmt, 5) { url = String(cString: uC) }

                    var filePath: String? = nil
                    if let fC = sqlite3_column_text(stmt, 6) { filePath = String(cString: fC) }

                    var text: String? = nil
                    if let tC = sqlite3_column_text(stmt, 7) { text = String(cString: tC) }

                    let captured = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 8))

                    items.append(ContextItem(
                        id: id,
                        appName: appName,
                        bundleId: bundleId,
                        windowTitle: winTitle,
                        url: url,
                        filePath: filePath,
                        extractedText: text,
                        capturedAt: captured
                    ))
                }
            }
            sqlite3_finalize(stmt)
        }
        return items
    }

    public func deleteSession(id: UUID) {
        dbQueue.sync {
            let sql = "DELETE FROM context_sessions WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }

            let ftsSQL = "DELETE FROM fts_timeline WHERE session_id = ?;"
            var ftsStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, ftsSQL, -1, &ftsStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(ftsStmt, 1, (id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_step(ftsStmt)
                sqlite3_finalize(ftsStmt)
            }
        }
    }

    public func clearAllData() {
        dbQueue.sync {
            executeRaw(sql: "DELETE FROM timeline_events;")
            executeRaw(sql: "DELETE FROM context_sessions;")
            executeRaw(sql: "DELETE FROM fts_timeline;")
            executeRaw(sql: "DELETE FROM daily_reports;")
            executeRaw(sql: "VACUUM;")
            AppLogger.shared.log(tag: "SQLITE", message: "数据库已完全清空重置。")
        }
    }

    // MARK: - 日报持久化 (DailyWrapUp)

    public func saveDailyReport(_ report: DailyWrapUp) {
        dbQueue.sync {
            let sql = """
            INSERT OR REPLACE INTO daily_reports (
                date, summary, key_projects, suggestions, total_focus_minutes, session_count, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                let projectsJSON = (try? JSONSerialization.data(withJSONObject: report.keyProjects))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
                let sugJSON = (try? JSONSerialization.data(withJSONObject: report.suggestions))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

                sqlite3_bind_text(stmt, 1, (report.date as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (report.summary as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (projectsJSON as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (sugJSON as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 5, Int32(report.totalFocusMinutes))
                sqlite3_bind_int(stmt, 6, Int32(report.sessionCount))
                sqlite3_bind_double(stmt, 7, Date().timeIntervalSince1970)

                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }

    public func getDailyReport(date: String) -> DailyWrapUp? {
        dbQueue.sync {
            let sql = "SELECT * FROM daily_reports WHERE date = ?;"
            var stmt: OpaquePointer?
            var report: DailyWrapUp? = nil

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (date as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    if let sumC = sqlite3_column_text(stmt, 1),
                       let projC = sqlite3_column_text(stmt, 2),
                       let sugC = sqlite3_column_text(stmt, 3) {
                        let summary = String(cString: sumC)
                        let projStr = String(cString: projC)
                        let sugStr = String(cString: sugC)
                        let focusMins = Int(sqlite3_column_int(stmt, 4))
                        let count = Int(sqlite3_column_int(stmt, 5))

                        let projs = (try? JSONSerialization.jsonObject(with: projStr.data(using: .utf8) ?? Data())) as? [String] ?? []
                        let sugs = (try? JSONSerialization.jsonObject(with: sugStr.data(using: .utf8) ?? Data())) as? [String] ?? []

                        report = DailyWrapUp(
                            date: date,
                            summary: summary,
                            keyProjects: projs,
                            totalFocusMinutes: focusMins,
                            sessionCount: count,
                            suggestions: sugs
                        )
                    }
                }
                sqlite3_finalize(stmt)
            }
            return report
        }
    }
}
