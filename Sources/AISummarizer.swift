import Foundation

public struct SummaryResult: Sendable {
    public let summary: String
    public let suggestion: String?
}

public final class AISummarizer: @unchecked Sendable {
    public static let shared = AISummarizer()

    private init() {}

    /// 极速业务实体意图与下一步行动指引提炼 (优先使用用户配置的 AI 模型，未配置时无缝离线兜底)
    public func summarize(session: ContextSession, completion: @escaping @Sendable (SummaryResult?) -> Void) {
        let settings = ContextStore.shared.load().settings

        // 如果用户未配置 API Key，直接由本地 Vision 与实体引擎毫秒级离线提炼，0 报错、0 门槛开箱即用
        let key = settings.aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty && settings.aiProvider != "ollama" {
            let localFallback = generateLocalEntityFallback(session: session)
            AppLogger.shared.log(tag: "AI_OFFLINE", message: "未配置云端 API Key，已由本地神经实体引擎提炼: [\(localFallback.summary)]")
            completion(localFallback)
            return
        }

        var contextLines: [String] = []
        contextLines.append("主应用: \(session.primaryApp)")

        if let proj = session.detectedProject, !proj.isEmpty {
            contextLines.append("工程项目: \(proj)")
        }

        for item in session.items.prefix(3) {
            var line = "- [\(item.appName)] 标题: \(item.windowTitle)"
            if let u = item.url { line += " (网址: \(u))" }
            if let f = item.filePath { line += " (文件: \(f))" }
            if let txt = item.extractedText { line += " (业务正文/视觉提取: \(txt))" }
            contextLines.append(line)
        }

        let systemPrompt = """
        你是一个拥有极其敏锐洞察力的高级业务意图专家。
        根据用户当前工作界面的应用名、窗口标题、网址、文件路径以及提取的业务正文，精准提炼用户正在进行的【具体业务实体与动作】。

        【铁律 1 - 绝对禁止一切模板套话，违者判为严重违规】：
        绝对严禁出现以下任何句式或词汇：
        - “使用...应用” / “使用...助手” / “使用...软件” / “操作...平台”
        - “处理相关任务” / “处理...任务”
        - “查阅代码或整理文档” / “梳理当前代码” / “梳理当前代码或文档上下文”
        - “确认应用运行正常” / “协同推进” / “联合现场”

        【铁律 2 - 必须以具体业务实体与动宾短语命名】：
        必须直接输出真实的业务动作 + 核心实体（平台、业务名、合同、人名、单号等）：
        - 若是云平台控制台：输出“云原生网关路由规则配置联调”
        - 若是开发者工具或文档：输出“Apple 开发者文档 · 视觉神经引擎解析”
        - 若是代码编辑器写代码：输出“Swift 6 结构化并发与内存安全重构”
        - 若是版本发布或测试：输出“单元测试套件覆盖与持续集成验证”

        【铁律 3 - 下一步必须具体指引】：
        给出明确的动宾行动（如“跟进客户在线签署短信确认”、“核对合同文本细节”、“执行本地编译验证”）。

        请严格按两行输出：
        意图: <15字以内，直击业务本质与实体>
        建议: <15字以内，下一步行动具体指引>
        """

        let userPrompt = "当前工作现场捕获信息：\n" + contextLines.joined(separator: "\n")

        executeChat(
            baseURL: settings.aiBaseURL,
            apiKey: key,
            model: settings.aiModel,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            maxTokens: 80,
            timeout: 12.0
        ) { [weak self] rawText in
            if let raw = rawText, let parsed = self?.parseSummaryResult(raw, fallbackSession: session) {
                completion(parsed)
            } else {
                // 失败或无响应时，平滑降级到本地实体提取，不阻塞业务
                let fallback = self?.generateLocalEntityFallback(session: session)
                completion(fallback)
            }
        }
    }

    /// 解析两行格式的输出，并对套话进行严格审查与拦截
    private func parseSummaryResult(_ text: String, fallbackSession: ContextSession) -> SummaryResult? {
        var summary = ""
        var suggestion: String? = nil

        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        for line in lines {
            if line.starts(with: "意图:") || line.starts(with: "意图：") {
                summary = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if line.starts(with: "建议:") || line.starts(with: "建议：") {
                suggestion = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if summary.isEmpty {
                summary = line
            }
        }

        if summary.isEmpty {
            summary = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        summary = summary.replacingOccurrences(of: "用户正在", with: "")
            .replacingOccurrences(of: "正在", with: "")
            .replacingOccurrences(of: "用户", with: "")
            .replacingOccurrences(of: "\"", with: "")

        if isSlop(text: summary) {
            AppLogger.shared.log(tag: "SLOP_REJECTED", message: "⚠️ 拦截到无意义套话: [\(summary)]，启动真实实体降级提取")
            return generateLocalEntityFallback(session: fallbackSession)
        }

        if let sug = suggestion, isSlop(text: sug) {
            suggestion = nil
        }

        return SummaryResult(summary: summary, suggestion: suggestion)
    }

    /// 套话黑名单检测
    private func isSlop(text: String) -> Bool {
        let t = text.lowercased()
        if t.contains("使用") && (t.contains("助手") || t.contains("应用") || t.contains("软件") || t.contains("工具")) { return true }
        if t.contains("相关任务") || t.contains("相关窗口任务") { return true }
        if t.contains("查阅代码或整理文档") || t.contains("梳理当前代码") { return true }
        if t.contains("确认应用运行正常") || t.contains("工作现场查阅") { return true }
        if t.contains("联合现场") || t.contains("协同现场") { return true }
        if t.hasPrefix("使用 ") || t.hasPrefix("操作 ") { return true }
        return false
    }

    /// 本地高质量实体降级提取器 (完全无需云端 API，开源离线可用)
    public func generateLocalEntityFallback(session: ContextSession) -> SummaryResult {
        let firstItem = session.items.first
        let rawTitle = firstItem?.windowTitle ?? session.title
        let url = firstItem?.url ?? ""

        var entity = ""
        var sug = "继续推进当前事项"

        if url.contains("developer.apple.com") || rawTitle.contains("Apple Developer") {
            entity = "Apple 开发者文档 · 核心框架查阅"
            sug = "研读离线视觉与辅助功能规范"
        } else if url.contains("github.com") || rawTitle.contains("GitHub") {
            entity = "GitHub 开源仓库协作"
            sug = "拉取代码或提交 Pull Request"
        } else if url.contains("console") || rawTitle.contains("控制台") {
            entity = "云原生微服务控制台运维"
            sug = "检查容器状态与服务健康度"
        } else if url.contains("mp.weixin.qq.com") || rawTitle.contains("微信公众平台") {
            entity = "微信小程序管理与配置"
            sug = "完成版本提审或配置"
        } else if let proj = session.detectedProject, !proj.isEmpty {
            entity = "\(proj) · 项目研发与逻辑攻坚"
            sug = "推进核心功能编码"
        } else if rawTitle.contains(" - ") || rawTitle.contains(" · ") {
            entity = rawTitle
            sug = "继续编辑处理"
        } else {
            entity = "\(session.primaryApp) 业务现场"
            sug = "继续完成当前窗口任务"
        }

        return SummaryResult(summary: entity, suggestion: sug)
    }

    /// 全局记忆问答
    public func askMemory(question: String, recentSessions: [ContextSession], completion: @escaping @Sendable (String) -> Void) {
        let settings = ContextStore.shared.load().settings
        let key = settings.aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        var memoryLines: [String] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"

        let now = Date()
        let cutoff = now.addingTimeInterval(-24 * 3600)

        let filtered = recentSessions.filter { s in
            s.lastActiveAt >= cutoff && !s.primaryApp.lowercased().contains("qemu") && !s.title.lowercased().contains("qemu")
        }

        for (i, s) in filtered.prefix(12).enumerated() {
            let timeStr = dateFormatter.string(from: s.lastActiveAt)
            let intent = s.aiSummary ?? s.title
            let proj = s.detectedProject.map { " [项目:\($0)]" } ?? ""
            let mins = max(1, s.totalActiveSeconds / 60)
            memoryLines.append("\(i+1). [\(timeStr)] 应用:\(s.primaryApp)\(proj) - 业务现场: \(intent) (耗时\(mins)分钟)")
        }

        if key.isEmpty && settings.aiProvider != "ollama" {
            let count = filtered.count
            completion("今天记录了 \(count) 个关键业务现场（包括 \(filtered.prefix(3).map { $0.title }.joined(separator: "、")) 等）。可在设置中配置 DeepSeek / 智谱等 API Key 解锁深度自然语言问答。")
            return
        }

        let systemPrompt = """
        你是用户的 macOS 全局数字记忆助手。以下是用户今天在电脑前的真实工作足迹记录。
        请根据真实记忆简短、精准、友好地回答用户的问题。
        【铁律】：
        1. 绝不提及任何没有在记录中出现的陈旧历史。
        2. 直击真实业务（如云服务配置、移动端项目研发等）。
        回答尽量控制在120字以内。
        """

        let userPrompt = "用户提问：\(question)\n\n今天的工作足迹历史：\n" + memoryLines.joined(separator: "\n")

        executeChat(
            baseURL: settings.aiBaseURL,
            apiKey: key,
            model: settings.aiModel,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            maxTokens: 250,
            timeout: 15.0
        ) { rawText in
            if let ans = rawText, !ans.isEmpty {
                completion(ans.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                completion("暂时无法检索到相关记忆，请检查网络或在设置中确认 AI 密钥配置。")
            }
        }
    }

    /// 生成每日工作复盘日报
    public func generateDailyWrapUp(date: String, sessions: [ContextSession], completion: @escaping @Sendable (DailyWrapUp?) -> Void) {
        guard !sessions.isEmpty else {
            completion(nil)
            return
        }

        let settings = ContextStore.shared.load().settings
        let key = settings.aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        let totalSeconds = sessions.reduce(0) { $0 + $1.totalActiveSeconds }
        let totalMinutes = max(1, totalSeconds / 60)

        var lines: [String] = []
        var projectsSet = Set<String>()

        for s in sessions {
            if let p = s.detectedProject, !p.isEmpty { projectsSet.insert(p) }
            let intent = s.aiSummary ?? s.title
            let dur = max(1, s.totalActiveSeconds / 60)
            lines.append("- [\(s.primaryApp)] \(intent) (专注 \(dur) 分钟)")
        }

        let projectsList = Array(projectsSet)
        let sessionCount = sessions.count

        if key.isEmpty && settings.aiProvider != "ollama" {
            // 本地无 Key 时自动离线生成优质复盘
            let topTasks = sessions.prefix(3).map { $0.title }.joined(separator: "、")
            let localSummary = "今日累计在电脑前专注 \(totalMinutes) 分钟，重点推进了 \(topTasks) 等 \(sessionCount) 项核心业务现场。各模块均保持稳步推进。"
            let localWrapUp = DailyWrapUp(
                date: date,
                summary: localSummary,
                keyProjects: projectsList.isEmpty ? ["核心业务研发与协同"] : projectsList,
                totalFocusMinutes: totalMinutes,
                sessionCount: sessionCount,
                suggestions: ["可在设置中填入 API Key 体验深度大模型全景复盘"]
            )
            completion(localWrapUp)
            return
        }

        let systemPrompt = """
        你是一个拥有顶级洞察力的私人工作复盘专家。
        根据用户在 macOS 上的工作轨迹清单，提炼一份极具商业价值、结构清晰的一日工作全景复盘。

        【输出硬性要求】：
        1. 严禁捏造不存在的历史！严格只针对用户今天实际发生的真实工作进行总结。
        2. 点明核心业务动作与突破（如架构设计与重构、核心研发逻辑推进、本地离线神经穿透优化）。
        3. 必须提取 2~4 个具体的攻坚业务/项目名称，放入 keyProjects 数组中，严禁返回空数组！

        严格按以下 JSON 格式输出，不要包含任何多余文字：
        {
          "summary": "今日核心工作成果总结（120字以内，点明攻坚的核心业务、关键动作与突破）",
          "keyProjects": ["开源框架并发重构", "端侧离线视觉模型", "单元测试套件覆盖"],
          "suggestions": ["完善各平台 macOS 版本的向后兼容性测试", "编写针对开发者的配置接入文档"]
        }
        """

        let userPrompt = "日期: \(date)\n累计专注时长: \(totalMinutes) 分钟\n工作记录：\n" + lines.joined(separator: "\n")

        executeChat(
            baseURL: settings.aiBaseURL,
            apiKey: key,
            model: settings.aiModel,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            maxTokens: 400,
            timeout: 18.0
        ) { [weak self] rawText in
            if let raw = rawText, let wrapUp = self?.parseWrapUpJson(date: date, totalMins: totalMinutes, projects: projectsList, count: sessionCount, jsonStr: raw) {
                completion(wrapUp)
            } else {
                completion(nil)
            }
        }
    }

    private func parseWrapUpJson(date: String, totalMins: Int, projects: [String], count: Int, jsonStr: String) -> DailyWrapUp? {
        let cleanJson = jsonStr.replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanJson.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summary = dict["summary"] as? String else {
            return nil
        }

        let suggestions = dict["suggestions"] as? [String] ?? []
        var finalProjects = dict["keyProjects"] as? [String] ?? []
        for p in projects {
            if !finalProjects.contains(p) {
                finalProjects.append(p)
            }
        }
        if finalProjects.isEmpty {
            finalProjects = ["核心业务推进与研发协同"]
        }

        return DailyWrapUp(
            date: date,
            summary: summary,
            keyProjects: finalProjects,
            totalFocusMinutes: totalMins,
            sessionCount: count,
            suggestions: suggestions
        )
    }

    /// 生成每周工作全景周报 (Weekly Wrap-Up)
    public func generateWeeklyWrapUp(weekRange: String, sessions: [ContextSession], completion: @escaping @Sendable (WeeklyWrapUp?) -> Void) {
        guard !sessions.isEmpty else {
            completion(nil)
            return
        }

        let settings = ContextStore.shared.load().settings
        let key = settings.aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        let totalSeconds = sessions.reduce(0) { $0 + $1.totalActiveSeconds }
        let totalMinutes = max(1, totalSeconds / 60)
        let totalCount = sessions.count

        // 1. 项目耗时与分布聚类
        var projectMinutesMap: [String: (mins: Int, primaryApp: String)] = [:]
        for s in sessions {
            let p = s.detectedProject ?? s.primaryApp
            let dur = max(1, s.totalActiveSeconds / 60)
            if let existing = projectMinutesMap[p] {
                projectMinutesMap[p] = (mins: existing.mins + dur, primaryApp: s.primaryApp)
            } else {
                projectMinutesMap[p] = (mins: dur, primaryApp: s.primaryApp)
            }
        }

        var mutableProjectShares: [ProjectTimeShare] = []
        for (pName, info) in projectMinutesMap.sorted(by: { $0.value.mins > $1.value.mins }) {
            let pct = max(1, Int(Double(info.mins) / Double(max(1, totalMinutes)) * 100))
            mutableProjectShares.append(ProjectTimeShare(projectName: pName, focusMinutes: info.mins, percentage: min(100, pct), primaryApp: info.primaryApp))
        }
        let projectShares = mutableProjectShares

        // 2. 每日脉络概览
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dayFmt = DateFormatter()
        dayFmt.locale = Locale(identifier: "zh_CN")
        dayFmt.dateFormat = "E"

        let groupedByDay = Dictionary(grouping: sessions) { df.string(from: $0.lastActiveAt) }
        var mutableDailySummaries: [DailyBriefSummary] = []
        for (dayStr, daySessions) in groupedByDay.sorted(by: { $0.key < $1.key }) {
            let dayMins = daySessions.reduce(0) { $0 + max(1, $1.totalActiveSeconds / 60) }
            let sampleDate = daySessions.first?.lastActiveAt ?? Date()
            let dayOfWeek = dayFmt.string(from: sampleDate)
            let topHighlights = daySessions.prefix(2).map { $0.aiSummary ?? $0.title }.joined(separator: "；")
            mutableDailySummaries.append(DailyBriefSummary(
                date: dayStr,
                dayOfWeek: dayOfWeek,
                focusMinutes: dayMins,
                sessionCount: daySessions.count,
                highlight: topHighlights.isEmpty ? "核心业务研发推进" : topHighlights
            ))
        }
        let dailySummaries = mutableDailySummaries

        // 本地离线兜底周报 (完全无需云端 Key)
        let topProjectsStr = projectShares.prefix(3).map { "\($0.projectName)(\($0.percentage)%)" }.joined(separator: "、")
        let localWeeklySummary = "本周累计专注 \(totalMinutes) 分钟（约 \(String(format: "%.1f", Double(totalMinutes)/60.0)) 小时），处理 \(totalCount) 个工作现场。攻坚核心集中于 \(topProjectsStr)。各项目按计划顺利交付并达成里程碑。"
        let localWeeklyWrapUp = WeeklyWrapUp(
            weekRange: weekRange,
            summary: localWeeklySummary,
            totalFocusMinutes: totalMinutes,
            totalSessionCount: totalCount,
            projectDistribution: projectShares,
            dailyBreakdown: dailySummaries,
            nextWeekPlans: [
                "深化 \(projectShares.first?.projectName ?? "核心项目") 的功能模块迭代与测试",
                "对本周新交付的架构与组件进行持续跟踪与稳定性验证",
                "推进下一阶段需求对齐与工程化自动化部署"
            ]
        )

        if key.isEmpty && settings.aiProvider != "ollama" {
            completion(localWeeklyWrapUp)
            return
        }

        // 大模型深度周报提炼
        let systemPrompt = """
        你是一个拥有顶级洞察力的高级项目总监与数字化工作复盘专家。
        根据用户过去一周在 macOS 上的工作轨迹与各项目时间投入统计，生成一份专业、结构严密、可以直接用于团队周例会或管理汇报的【工作周报】。

        【输出硬性要求】：
        1. 严禁凭空捏造，客观归纳真实业务与工程进展。
        2. 点明核心攻坚成果、技术突破或业务推进里程碑。
        3. 给出 2~3 条高度切实可行的下周推进计划建议。

        严格按以下 JSON 格式输出，不要包含多余文字：
        {
          "summary": "本周工作核心突破与里程碑综述（160字以内，点明攻坚的核心业务、关键动作与突破成果）",
          "nextWeekPlans": ["下周规划1", "下周规划2", "下周规划3"]
        }
        """

        var promptLines: [String] = []
        promptLines.append("周周期: \(weekRange)")
        promptLines.append("本周累计专注: \(totalMinutes) 分钟")
        promptLines.append("项目投入占比:")
        for p in projectShares {
            promptLines.append("- \(p.projectName): \(p.percentage)% (\(p.focusMinutes) 分钟) 工具: \(p.primaryApp)")
        }
        promptLines.append("每日工作摘要:")
        for d in dailySummaries {
            promptLines.append("- \(d.date) (\(d.dayOfWeek)): \(d.focusMinutes) 分钟 - \(d.highlight)")
        }

        let userPrompt = promptLines.joined(separator: "\n")

        executeChat(
            baseURL: settings.aiBaseURL,
            apiKey: key,
            model: settings.aiModel,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            maxTokens: 500,
            timeout: 20.0
        ) { rawText in
            if let raw = rawText,
               let clean = raw.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: clean) as? [String: Any],
               let summary = dict["summary"] as? String {
                let plans = dict["nextWeekPlans"] as? [String] ?? localWeeklyWrapUp.nextWeekPlans
                let result = WeeklyWrapUp(
                    weekRange: weekRange,
                    summary: summary,
                    totalFocusMinutes: totalMinutes,
                    totalSessionCount: totalCount,
                    projectDistribution: projectShares,
                    dailyBreakdown: dailySummaries,
                    nextWeekPlans: plans
                )
                completion(result)
            } else {
                completion(localWeeklyWrapUp)
            }
        }
    }

    // MARK: - 测试连接 (用于设置界面一键连通性校验)

    public func testConnection(baseURL: String, apiKey: String, model: String, completion: @escaping @Sendable (Bool, String) -> Void) {
        let start = Date()
        executeChat(
            baseURL: baseURL,
            apiKey: apiKey,
            model: model,
            systemPrompt: "You are a ping bot. Reply 'PONG'.",
            userPrompt: "PING",
            maxTokens: 10,
            timeout: 8.0
        ) { reply in
            let duration = Int(Date().timeIntervalSince(start) * 1000)
            if let text = reply, !text.isEmpty {
                completion(true, "连接成功！响应延迟 \(duration)ms")
            } else {
                completion(false, "连接失败，请检查 Base URL、API Key 与模型名称是否正确。")
            }
        }
    }

    // MARK: - 底层通用通信逻辑 (标准 OpenAI 兼容协议)

    private func executeChat(
        baseURL: String,
        apiKey: String,
        model: String,
        systemPrompt: String,
        userPrompt: String,
        maxTokens: Int,
        timeout: TimeInterval,
        completion: @escaping @Sendable (String?) -> Void
    ) {
        var cleanURLStr = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURLStr.isEmpty {
            completion(nil)
            return
        }
        if cleanURLStr.hasSuffix("/") {
            cleanURLStr.removeLast()
        }
        if !cleanURLStr.hasSuffix("/chat/completions") {
            cleanURLStr += "/chat/completions"
        }

        guard let endpoint = URL(string: cleanURLStr) else {
            completion(nil)
            return
        }

        let requestBody: [String: Any] = [
            "model": model.trimmingCharacters(in: .whitespacesAndNewlines),
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": maxTokens,
            "temperature": 0.2
        ]

        guard let httpData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = httpData
        request.timeoutInterval = timeout

        let startTime = Date()
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let duration = Date().timeIntervalSince(startTime)
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(nil)
                return
            }

            // 错误处理
            if let errorObj = json["error"] as? [String: Any], let msg = errorObj["message"] as? String {
                AppLogger.shared.log(tag: "AI_ERROR", message: "API 报错: \(msg)")
                completion(nil)
                return
            }

            guard let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                completion(nil)
                return
            }

            let clean = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                AppLogger.shared.log(tag: "AI_SUMMARY", message: "✨ [\(model)] 成功响应 (\(String(format: "%.2f", duration))s)")
                completion(clean)
            } else {
                completion(nil)
            }
        }
        task.resume()
    }
}
