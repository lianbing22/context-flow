import Cocoa
import Foundation

@MainActor
public final class ContextEngine: ObservableObject {
    public static let shared = ContextEngine()

    @Published public var activeSession: ContextSession?
    @Published public var suspendedSessions: [ContextSession] = []
    @Published public var completedSessions: [ContextSession] = []
    @Published public var settings: AppSettings = AppSettings()

    public var onStateChanged: (() -> Void)?

    private var heartbeatTimer: Timer?
    private var lastObservedWindow: RawWindowInfo?
    private var transientStartTime: Date?
    private var transientAppBundleId: String?
    private var isSystemLocked: Bool = false

    /// 意图提炼后台补偿队列锁与重试记录
    private var isProcessingSummaryQueue: Bool = false
    private var lastSummaryRetryTime: [UUID: Date] = [:]

    private init() {
        loadPersistedState()
        setupWorkspaceNotifications()
        startHeartbeat()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.handleApplicationActivated()
        }
    }

    private func loadPersistedState() {
        let payload = ContextStore.shared.load()
        self.settings = payload.settings
        self.activeSession = payload.activeSession

        // 强力清洗历史脏数据：彻底排查并剔除 QEMU、loginwindow 以及四不像联合现场
        let now = Date()
        let cutoff = now.addingTimeInterval(-48 * 3600)

        func sanitizeSession(_ s: ContextSession) -> ContextSession? {
            let lowerApp = s.primaryApp.lowercased()
            let lowerTitle = s.title.lowercased()
            if lowerApp.contains("loginwindow") || lowerApp.contains("qemu") || lowerTitle.contains("qemu") {
                return nil
            }
            if s.lastActiveAt < cutoff {
                return nil
            }

            var clean = s
            // 清洗历史胡乱合并的“联合现场”或“协同”标题
            if clean.title.contains("联合现场") || clean.title.contains("协同") {
                if let firstItem = clean.items.first, !firstItem.windowTitle.isEmpty, firstItem.windowTitle != firstItem.appName {
                    clean.title = firstItem.windowTitle
                } else {
                    clean.title = "\(clean.primaryApp) 业务现场"
                }
            }

            // 清洗包含套话的 aiSummary
            if let ai = clean.aiSummary, ai.contains("使用") || ai.contains("助手") || ai.contains("相关任务") || ai.contains("整理文档") {
                clean.aiSummary = nil
                clean.suggestion = nil
            }

            return clean
        }

        self.suspendedSessions = payload.sessions
            .filter { $0.status == .suspended }
            .compactMap { sanitizeSession($0) }
        self.completedSessions = payload.sessions
            .filter { $0.status == .completed }
            .compactMap { sanitizeSession($0) }

        if let act = payload.activeSession, let sanitizedAct = sanitizeSession(act) {
            self.activeSession = sanitizedAct
        }

        self.suspendedSessions.sort { $0.lastActiveAt > $1.lastActiveAt }
        self.completedSessions.sort { $0.lastActiveAt > $1.lastActiveAt }

        AppLogger.shared.log(tag: "INIT", message: "持久化数据重构加载完成，保留 \(suspendedSessions.count) 个挂起现场，\(completedSessions.count) 个归档记录")

        // 自动自愈：触发深度业务正文与实体提炼
        for i in 0..<self.suspendedSessions.count {
            if self.suspendedSessions[i].aiSummary == nil {
                triggerAIIntentSummary(for: self.suspendedSessions[i])
            }
        }
    }

    public func persistState() {
        let allSessions = suspendedSessions + completedSessions
        ContextStore.shared.save(
            settings: settings,
            active: activeSession,
            sessions: allSessions
        )
        onStateChanged?()
    }

    private func setupWorkspaceNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleApplicationActivated()
            }
        }
    }

    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    /// 定时心跳检查
    private func tick() {
        guard let info = WindowInspector.shared.inspectFrontmostWindow() else { return }

        // 1. 锁屏/合盖睡眠检测
        if info.windowTitle == "[LOCK_SCREEN]" {
            if !isSystemLocked {
                isSystemLocked = true
                AppLogger.shared.log(tag: "LOCK_SCREEN", message: "检测到系统锁屏/合盖睡眠，工作计时已自动暂停")
            }
            return
        } else if isSystemLocked {
            isSystemLocked = false
            AppLogger.shared.log(tag: "UNLOCK", message: "检测到屏幕已解锁，恢复工作计时追踪: [\(info.appName)]")
        }

        // 2. 瞬态应用过滤（微信等 < 30s 视为主任务背景音）
        if transientAppBundleId != nil, let start = transientStartTime {
            let duration = Date().timeIntervalSince(start)
            if duration < Double(settings.transientThresholdSeconds) {
                return
            } else {
                AppLogger.shared.log(tag: "TRANSIENT_EXCEED", message: "辅助应用 [\(info.appName)] 停留超过 30s，转为主任务")
                transientAppBundleId = nil
                transientStartTime = nil
            }
        }

        // 3. 更新当前活跃 Session 计时
        if var current = activeSession {
            let now = Date()
            current.lastActiveAt = now
            current.totalActiveSeconds += 5

            let item = ContextItem(
                appName: info.appName,
                bundleId: info.bundleId,
                windowTitle: info.windowTitle,
                url: info.url,
                filePath: info.filePath,
                project: info.project,
                extractedText: info.extractedText,
                capturedAt: now
            )

            // 如果该窗口未记录在该会话中，合并追加
            if !current.items.contains(where: { $0.windowTitle == info.windowTitle && $0.appName == info.appName }) {
                current.items.append(item)
                if current.detectedProject == nil, let p = info.project {
                    current.detectedProject = p
                }
                AppLogger.shared.log(tag: "ITEM_APPEND", message: "捕获窗口更新: [\(info.appName)] \(info.windowTitle)")
            }

            self.activeSession = current
        }

        // 4. 检查悬挂超时与窗口自然关闭
        checkStaleSuspension()

        // 5. 意图提炼补偿队列：定期扫描并补充生成未完成的意图卡片
        processPendingSummaryQueue()

        persistState()
    }

    /// 处理前台应用切换事件 (彻底摒弃生拉硬拽的联合现场，保持业务现场独立纯粹)
    private func handleApplicationActivated() {
        guard let info = WindowInspector.shared.inspectFrontmostWindow() else { return }

        if info.windowTitle == "[LOCK_SCREEN]" ||
            info.bundleId == "app.memoryelf" ||
            info.bundleId == "com.citrolabs.contextflow" ||
            info.appName == "全局记忆精灵" ||
            info.appName == "ContextFlow" {
            return
        }

        let now = Date()

        if WindowInspector.shared.isTransientApp(bundleId: info.bundleId) {
            transientAppBundleId = info.bundleId
            transientStartTime = now
            AppLogger.shared.log(tag: "TRANSIENT_SKIP", message: "切入辅助通讯应用: [\(info.appName)]，启动 30s 宽限过滤")
            return
        } else {
            transientAppBundleId = nil
            transientStartTime = nil
        }

        // 判断是否属于同一个应用现场或相同工程
        if let current = activeSession {
            let isSameApp = (current.primaryApp == info.appName)
            let isSameProject = (info.project != nil && current.detectedProject != nil && info.project == current.detectedProject)

            if isSameApp || isSameProject {
                var updated = current
                updated.lastActiveAt = now

                if !updated.items.contains(where: { $0.windowTitle == info.windowTitle }) {
                    let newItem = ContextItem(
                        appName: info.appName,
                        bundleId: info.bundleId,
                        windowTitle: info.windowTitle,
                        url: info.url,
                        filePath: info.filePath,
                        project: info.project,
                        extractedText: info.extractedText,
                        capturedAt: now
                    )
                    updated.items.append(newItem)
                    if updated.detectedProject == nil, let p = info.project {
                        updated.detectedProject = p
                    }

                    // 如果原标题只是泛化应用名，而当前拿到了具体的业务窗口标题（如具体网页或代码文件标题），直接精准更新标题
                    if updated.title.contains("工作现场") && !info.windowTitle.isEmpty && info.windowTitle != info.appName {
                        updated.title = formatTitle(appName: info.appName, winTitle: info.windowTitle, project: updated.detectedProject)
                    }
                    AppLogger.shared.log(tag: "WINDOW_UPDATE", message: "同场景窗口更新: [\(updated.title)]")
                }

                self.activeSession = updated
                tick()
                return
            }

            // 用户切到了全新应用/场景，将旧现场安全挂起并提炼
            if current.totalActiveSeconds >= 10 {
                var suspended = current
                suspended.status = .suspended
                suspended.lastActiveAt = now

                // 离开瞬间截取微缩快照与原生神经 OCR
                let (snapPath, ocrText) = SnapshotManager.shared.captureSnapshotWithOCR(sessionId: suspended.id)
                if let p = snapPath { suspended.thumbnailPath = p }
                if let ocr = ocrText, !ocr.isEmpty {
                    if !suspended.items.isEmpty {
                        let last = suspended.items.removeLast()
                        let original = last.extractedText ?? ""
                        let combined = original.isEmpty ? "[屏幕核心视觉: \(ocr)]" : "\(original) [屏幕核心视觉: \(ocr)]"
                        let updatedItem = ContextItem(
                            id: last.id,
                            appName: last.appName,
                            bundleId: last.bundleId,
                            windowTitle: last.windowTitle,
                            url: last.url,
                            filePath: last.filePath,
                            project: last.project,
                            extractedText: combined,
                            capturedAt: last.capturedAt
                        )
                        suspended.items.append(updatedItem)
                    }
                }

                self.suspendedSessions.removeAll(where: { $0.id == suspended.id })
                self.suspendedSessions.insert(suspended, at: 0)

                AppLogger.shared.log(tag: "AUTO_SUSPEND", message: "原任务已安全挂起: [\(suspended.title)] (专注 \(suspended.totalActiveSeconds/60) 分钟)")

                // 核心：异步触发高精准业务实体提炼
                triggerAIIntentSummary(for: suspended)

                // 防堆积限制
                if self.suspendedSessions.count > settings.maxDisplaySuspended {
                    let excess = self.suspendedSessions.suffix(from: settings.maxDisplaySuspended)
                    for var old in excess {
                        old.status = .archived
                        self.completedSessions.insert(old, at: 0)
                    }
                    self.suspendedSessions = Array(self.suspendedSessions.prefix(settings.maxDisplaySuspended))
                }
            }
        }

        // 启动独立、纯粹的新工作现场
        let newItem = ContextItem(
            appName: info.appName,
            bundleId: info.bundleId,
            windowTitle: info.windowTitle,
            url: info.url,
            filePath: info.filePath,
            project: info.project,
            extractedText: info.extractedText,
            capturedAt: now
        )

        let sessionTitle = formatTitle(appName: info.appName, winTitle: info.windowTitle, project: info.project)
        self.activeSession = ContextSession(
            title: sessionTitle,
            primaryApp: info.appName,
            items: [newItem],
            detectedProject: info.project,
            createdAt: now,
            lastActiveAt: now,
            totalActiveSeconds: 5,
            status: .active
        )

        AppLogger.shared.log(tag: "NEW_SESSION", message: "开启独立工作现场: [\(sessionTitle)] (\(info.appName))")
        persistState()
    }

    /// 触发 AI 意图概括并将高价值业务实体回写 Session 标题与行动指引
    private func triggerAIIntentSummary(for session: ContextSession, completion: (@Sendable () -> Void)? = nil) {
        let targetId = session.id
        AISummarizer.shared.summarize(session: session) { [weak self] result in
            defer { completion?() }
            guard let result = result, !result.summary.isEmpty else {
                AppLogger.shared.log(tag: "AI_PENDING", message: "现场 [\(session.title)] 暂未获得有效业务实体")
                return
            }
            Task { @MainActor in
                if let idx = self?.suspendedSessions.firstIndex(where: { $0.id == targetId }) {
                    self?.suspendedSessions[idx].aiSummary = result.summary
                    self?.suspendedSessions[idx].suggestion = result.suggestion

                    // 核心商业级升级：将精准业务实体直接提升为主卡片标题！彻底干掉空洞的“XX 工作现场”
                    if !result.summary.isEmpty && !result.summary.contains("工作现场") {
                        self?.suspendedSessions[idx].title = result.summary
                    }

                    self?.persistState()
                    let sugLog = result.suggestion.map { " (下一步指引: \($0))" } ?? ""
                    AppLogger.shared.log(tag: "AI_DONE", message: "业务实体提炼完成并提升为主标题: \(result.summary)\(sugLog)")
                }
            }
        }
    }

    /// 全局记忆问答：基于今日真实工作足迹进行智能回答
    public func askMemory(question: String, completion: @escaping @MainActor (String) -> Void) {
        let allRecent = (activeSession.map { [$0] } ?? []) + suspendedSessions + completedSessions
        AISummarizer.shared.askMemory(question: question, recentSessions: allRecent) { answer in
            Task { @MainActor in
                completion(answer)
            }
        }
    }

    /// 触发今日工作复盘日报生成 (严格过滤最近24小时真实活跃现场，坚决杜绝陈旧历史垃圾)
    public func generateTodayWrapUp(completion: (@Sendable (DailyWrapUp?) -> Void)? = nil) {
        let now = Date()
        let cutoff = now.addingTimeInterval(-24 * 3600)

        let allCandidates = (activeSession.map { [$0] } ?? []) + suspendedSessions + completedSessions

        // 核心过滤：必须是最近 24 小时内的现场，彻底排除两天前甚至几周前的陈旧历史 (如 QEMU)
        let validSessions = allCandidates.filter { s in
            let isActiveRecently = s.lastActiveAt >= cutoff || s.createdAt >= cutoff
            let isSignificant = s.totalActiveSeconds >= 15 || s.aiSummary != nil
            let isClean = !s.primaryApp.lowercased().contains("qemu") && !s.title.lowercased().contains("qemu")
            return isActiveRecently && isSignificant && isClean
        }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let dateLabel: String
        if hour < 5 {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            dateLabel = "\(dateFormatter.string(from: yesterday)) ~ \(dateFormatter.string(from: now))"
        } else {
            dateLabel = dateFormatter.string(from: now)
        }

        AISummarizer.shared.generateDailyWrapUp(date: dateLabel, sessions: validSessions) { wrapUp in
            if let wrapUp = wrapUp {
                AppLogger.shared.log(tag: "DAILY_WRAPUP", message: "今日工作复盘已生成: [\(wrapUp.summary.prefix(30))...]")
            }
            completion?(wrapUp)
        }
    }

    /// 后台异步补偿队列：定期扫描未完成意图解析的会话，实现最终一致性
    private func processPendingSummaryQueue() {
        guard !isProcessingSummaryQueue else { return }

        let now = Date()
        guard let target = suspendedSessions.first(where: { s in
            guard s.aiSummary == nil else { return false }
            if let last = lastSummaryRetryTime[s.id] {
                return now.timeIntervalSince(last) >= 15.0
            }
            return true
        }) else { return }

        isProcessingSummaryQueue = true
        lastSummaryRetryTime[target.id] = now
        AppLogger.shared.log(tag: "QUEUE_PICK", message: "异步补偿队列调度：为现场 [\(target.title)] 启动实体提炼...")

        triggerAIIntentSummary(for: target) { [weak self] in
            Task { @MainActor in
                self?.isProcessingSummaryQueue = false
            }
        }
    }

    private func checkStaleSuspension() {
        let runningApps = NSWorkspace.shared.runningApplications
        let runningBundleIds = Set(runningApps.compactMap { $0.bundleIdentifier })
        let runningAppNames = Set(runningApps.compactMap { $0.localizedName })

        var remainingSuspended: [ContextSession] = []
        for var s in suspendedSessions {
            if WindowInspector.shared.isSystemOrSecurityProcess(bundleId: "", appName: s.primaryApp) {
                continue
            }

            var isAnyAppAlive = false
            for item in s.items {
                if runningBundleIds.contains(item.bundleId) || runningAppNames.contains(item.appName) {
                    isAnyAppAlive = true
                    break
                }
            }

            if !isAnyAppAlive {
                s.status = .completed
                completedSessions.insert(s, at: 0)
                AppLogger.shared.log(tag: "AUTO_CLOSE", message: "主进程已退出，自动收尾归档: [\(s.title)]")
            } else {
                remainingSuspended.append(s)
            }
        }

        self.suspendedSessions = remainingSuspended
    }

    private func formatTitle(appName: String, winTitle: String, project: String? = nil) -> String {
        if let proj = project, !proj.isEmpty {
            if winTitle.isEmpty || winTitle == appName {
                return "[\(proj)] \(appName)"
            }
            return "[\(proj)] \(winTitle)"
        }

        if winTitle.isEmpty || winTitle == appName {
            return "\(appName) 现场"
        }
        var clean = winTitle.replacingOccurrences(of: " — ◐ ", with: " · ")
        if clean.count > 36 {
            clean = String(clean.prefix(34)) + "..."
        }
        return clean
    }

    // MARK: - 用户交互方法

    public func restoreSession(id: UUID) {
        guard let index = suspendedSessions.firstIndex(where: { $0.id == id }) else { return }
        let session = suspendedSessions[index]
        AppLogger.shared.log(tag: "RESTORE", message: "用户触发一键恢复现场: [\(session.title)]")
        Restorer.shared.restore(session: session)

        var resumed = session
        resumed.status = .active
        resumed.lastActiveAt = Date()
        self.activeSession = resumed
        self.suspendedSessions.remove(at: index)
        persistState()
    }

    public func completeSession(id: UUID) {
        if let index = suspendedSessions.firstIndex(where: { $0.id == id }) {
            var item = suspendedSessions.remove(at: index)
            item.status = .completed
            completedSessions.insert(item, at: 0)
            AppLogger.shared.log(tag: "MANUAL_COMPLETE", message: "用户手动标记完成: [\(item.title)]")
            persistState()
        }
    }

    public func updateNote(id: UUID, note: String) {
        if let index = suspendedSessions.firstIndex(where: { $0.id == id }) {
            suspendedSessions[index].userNote = note.isEmpty ? nil : note
            AppLogger.shared.log(tag: "USER_NOTE", message: "更新备注 [\(suspendedSessions[index].title)]: \(note)")
            persistState()
        }
    }

    public func suspendActiveNow() {
        guard var act = activeSession else { return }
        act.status = .suspended
        act.lastActiveAt = Date()

        let (snapPath, ocrText) = SnapshotManager.shared.captureSnapshotWithOCR(sessionId: act.id)
        if let snapPath = snapPath {
            act.thumbnailPath = snapPath
        }
        if let ocr = ocrText, !ocr.isEmpty {
            if !act.items.isEmpty {
                let last = act.items.removeLast()
                let original = last.extractedText ?? ""
                let combined = original.isEmpty ? "[屏幕核心视觉: \(ocr)]" : "\(original) [屏幕核心视觉: \(ocr)]"
                let updatedItem = ContextItem(
                    id: last.id,
                    appName: last.appName,
                    bundleId: last.bundleId,
                    windowTitle: last.windowTitle,
                    url: last.url,
                    filePath: last.filePath,
                    project: last.project,
                    extractedText: combined,
                    capturedAt: last.capturedAt
                )
                act.items.append(updatedItem)
            }
        }

        self.suspendedSessions.removeAll(where: { $0.id == act.id })
        self.suspendedSessions.insert(act, at: 0)
        AppLogger.shared.log(tag: "MANUAL_SUSPEND", message: "用户手动挂起当前现场: [\(act.title)]")

        triggerAIIntentSummary(for: act)

        self.activeSession = nil
        persistState()
    }

    /// 重新深度提炼所有挂起现场 (过滤并替换掉旧废话)
    public func reSummarizeAllSuspendedSessions(completion: @escaping @MainActor (Int) -> Void) {
        var count = 0
        for i in 0..<suspendedSessions.count {
            suspendedSessions[i].aiSummary = nil
            suspendedSessions[i].suggestion = nil
            triggerAIIntentSummary(for: suspendedSessions[i])
            count += 1
        }
        persistState()
        completion(count)
    }
}
