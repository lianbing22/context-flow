import Cocoa
import CoreGraphics

public struct RawWindowInfo: Sendable {
    public let appName: String
    public let bundleId: String
    public let windowTitle: String
    public let url: String?
    public let filePath: String?
    public let project: String?
    public let extractedText: String?
}

public final class WindowInspector: @unchecked Sendable {
    public static let shared = WindowInspector()
    private init() {}

    /// 必须绝对忽略的系统守护/安全授权窗口名单 (防止触发权限告警死循环)
    private let systemOrSecurityProcesses: Set<String> = [
        "com.apple.loginwindow",
        "com.apple.ScreenSaver.Engine",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.Spotlight",
        "com.apple.systemuiserver",
        "app.memoryelf",
        "com.citrolabs.contextflow",
        "com.apple.SecurityAgent",
        "com.apple.CoreAuthUI",
        "com.apple.universalAccessAuthWarn",
        "com.apple.WebKit.WebContent"
    ]

    private let transientBundleIds: Set<String> = [
        "com.tencent.xinWeChat",
        "com.tencent.WeChat",
        "com.electron.lark",
        "com.bytedance.feishu",
        "com.alibaba.DingTalkMac",
        "com.netease.163music",
        "com.spotify.client",
        "com.agilebits.onepassword7",
        "com.1password.1password",
        "com.apple.Preferences",
        "com.apple.systempreferences"
    ]

    public func isSystemOrSecurityProcess(bundleId: String, appName: String) -> Bool {
        if systemOrSecurityProcesses.contains(bundleId) { return true }
        let nameLower = appName.lowercased()
        let idLower = bundleId.lowercased()
        if nameLower.contains("securityagent") ||
            nameLower.contains("universalaccess") ||
            nameLower.contains("authwarn") ||
            nameLower.contains("loginwindow") ||
            nameLower.contains("screensaver") ||
            nameLower == "contextflow" ||
            nameLower == "全局记忆精灵" {
            return true
        }

        // 动态支持用户在设置中自定义的隐私黑名单
        let settings = ContextStore.shared.load().settings
        for ignored in settings.customIgnoredApps {
            let ig = ignored.trimmingCharacters(in: .whitespaces).lowercased()
            if !ig.isEmpty && (nameLower.contains(ig) || idLower.contains(ig)) {
                return true
            }
        }

        return false
    }

    public func isTransientApp(bundleId: String) -> Bool {
        return transientBundleIds.contains(bundleId)
    }

    /// 获取当前前台活跃窗口的完整信息 (商业级：穿透真实网页/文档标题 + 真实业务正文)
    public func inspectFrontmostWindow() -> RawWindowInfo? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        let appName = frontApp.localizedName ?? "Unknown"
        let bundleId = frontApp.bundleIdentifier ?? ""
        let pid = frontApp.processIdentifier

        // 绝对不嗅探任何系统授权/锁屏窗口
        if isSystemOrSecurityProcess(bundleId: bundleId, appName: appName) {
            return nil
        }

        // 1. 基础标题嗅探：利用 CoreGraphics 毫秒级原生获取非隐藏窗口标题
        var windowTitle: String = appName
        if let cgWin = fetchWindowInfoViaCoreGraphics(pid: pid), !cgWin.title.isEmpty {
            windowTitle = cgWin.title
        } else if let axTitle = fetchFrontAppWindowTitle(pid: pid, processName: appName), !axTitle.isEmpty {
            windowTitle = axTitle
        }

        // 2. 深度穿透：如果是浏览器 (包括 ego lite, Chrome, Safari, Edge, Arc 等)，提取活跃标签页的真实网页标题与 URL
        var pageUrl: String? = nil
        var siteDomainLabel: String? = nil
        if isBrowser(bundleId: bundleId, appName: appName) {
            let tabInfo = fetchBrowserTabInfo(appName: appName, bundleId: bundleId)
            if let realTabTitle = tabInfo.title, !realTabTitle.isEmpty {
                // 如果提取到了真实网页标题（如“Apple Developer Documentation”），直接替换外壳泛化标题
                windowTitle = realTabTitle
            }
            pageUrl = tabInfo.url
            if let u = pageUrl {
                siteDomainLabel = extractDomainLabel(url: u)
            }
        }

        // 动态支持用户在设置中自定义的隐私黑名单与敏感关键词（应用名、BundleId、窗口标题、URL 全链路拦截）
        let settings = ContextStore.shared.load().settings
        let nameLower = appName.lowercased()
        let idLower = bundleId.lowercased()
        let winLower = windowTitle.lowercased()
        for ignored in settings.customIgnoredApps {
            let ig = ignored.trimmingCharacters(in: .whitespaces).lowercased()
            if !ig.isEmpty {
                if nameLower.contains(ig) || idLower.contains(ig) || winLower.contains(ig) || (pageUrl?.lowercased().contains(ig) ?? false) {
                    AppLogger.shared.log(tag: "PRIVACY_FILTER", message: "🛡️ 已拦截包含隐私关键词 [\(ig)] 的窗口: [\(appName)] [\(windowTitle)]")
                    return nil
                }
            }
        }

        // 3. 深度无感提取窗口内的关键业务正文与视觉元素
        var extractedText = fetchFrontWindowText(pid: pid, processName: appName)
        if let domain = siteDomainLabel {
            let prefix = "【平台业务: \(domain)】"
            extractedText = extractedText == nil ? prefix : "\(prefix) \(extractedText!)"
        }

        // 4. 提取项目工程与正在编辑的文件路径信息 (只有在开发工具中才关联项目)
        let (project, filePath) = parseWindowFileAndProject(appName: appName, bundleId: bundleId, windowTitle: windowTitle)

        return RawWindowInfo(
            appName: appName,
            bundleId: bundleId,
            windowTitle: windowTitle,
            url: pageUrl,
            filePath: filePath,
            project: project,
            extractedText: extractedText
        )
    }

    /// 毫秒级原生从 CoreGraphics 窗口栈抓取指定 PID 的最上层真实在屏窗口标题
    public func fetchWindowInfoViaCoreGraphics(pid: pid_t) -> (title: String, ownerName: String)? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // 第一轮：优先搜寻 layer == 0 (标准窗口)、尺寸正常 (>100x100) 且有标题的窗口
        for info in infoList {
            guard let ownerPid = info[kCGWindowOwnerPID as String] as? Int,
                  ownerPid == Int(pid) else { continue }

            let layer = info[kCGWindowLayer as String] as? Int ?? -1
            let owner = info[kCGWindowOwnerName as String] as? String ?? ""
            let name = (info[kCGWindowName as String] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let bounds = info[kCGWindowBounds as String] as? [String: Any] ?? [:]
            let w = bounds["Width"] as? Double ?? 0
            let h = bounds["Height"] as? Double ?? 0

            // 过滤极小辅助气泡或无意义纯空窗口
            if layer == 0 && w > 80 && h > 80 && !name.isEmpty && name != owner {
                return (title: name, ownerName: owner)
            }
        }

        // 第二轮：如果第一轮没匹配到非应用名标题，尝试获取任意有效标题
        for info in infoList {
            guard let ownerPid = info[kCGWindowOwnerPID as String] as? Int,
                  ownerPid == Int(pid) else { continue }
            let owner = info[kCGWindowOwnerName as String] as? String ?? ""
            let name = (info[kCGWindowName as String] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !name.isEmpty {
                return (title: name, ownerName: owner)
            }
        }

        return nil
    }

    /// 判断是否属于浏览器架构
    public func isBrowser(bundleId: String, appName: String) -> Bool {
        let idLower = bundleId.lowercased()
        let nameLower = appName.lowercased()
        return idLower.contains("chrome") || idLower.contains("safari") || idLower.contains("edge") ||
               idLower.contains("brave") || idLower.contains("arc") || idLower.contains("ego") ||
               idLower.contains("citrolabs.ego") || nameLower.contains("browser") ||
               nameLower.contains("ego") || nameLower.contains("vivaldi") || nameLower.contains("orion")
    }

    /// 深度穿透浏览器内核：同时抓取真实标签页标题与当前 URL
    public func fetchBrowserTabInfo(appName: String, bundleId: String) -> (title: String?, url: String?) {
        let idLower = bundleId.lowercased()
        let escapedAppName = appName.replacingOccurrences(of: "\"", with: "\\\"")

        let scriptSource: String
        if idLower.contains("safari") {
            scriptSource = """
            tell application "Safari"
                try
                    set tabTitle to name of current tab of front window
                    set tabUrl to URL of current tab of front window
                    return tabTitle & "|||ContextFlowSep|||" & tabUrl
                on error
                    return ""
                end try
            end tell
            """
        } else {
            // 所有 Chromium 系浏览器架构：ego lite, Google Chrome, Microsoft Edge, Brave Browser, Arc 等
            scriptSource = """
            tell application "\(escapedAppName)"
                try
                    set tabTitle to title of active tab of front window
                    set tabUrl to URL of active tab of front window
                    return tabTitle & "|||ContextFlowSep|||" & tabUrl
                on error
                    return ""
                end try
            end tell
            """
        }

        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            let res = script.executeAndReturnError(&error)
            if let fullStr = res.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !fullStr.isEmpty {
                let parts = fullStr.components(separatedBy: "|||ContextFlowSep|||")
                let title = parts.count > 0 ? parts[0].trimmingCharacters(in: .whitespacesAndNewlines) : nil
                let url = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
                let cleanTitle = (title?.isEmpty ?? true) ? nil : title
                let cleanUrl = (url?.starts(with: "http") ?? false) ? url : nil
                return (cleanTitle, cleanUrl)
            }
        }

        return (nil, nil)
    }

    /// 将常见平台 URL 自动识别为高识别度业务标签
    private func extractDomainLabel(url: String) -> String {
        guard let parsed = URL(string: url), let host = parsed.host?.lowercased() else { return "" }
        if host.contains("cloud.tencent.com") { return "腾讯云控制台" }
        if host.contains("aliyun.com") { return "阿里云控制台" }
        if host.contains("mp.weixin.qq.com") { return "微信公众平台/小程序" }
        if host.contains("github.com") { return "GitHub" }
        if host.contains("chatgpt.com") || host.contains("openai.com") { return "ChatGPT" }
        if host.contains("claude.ai") || host.contains("anthropic.com") { return "Claude AI" }
        if host.contains("feishu.cn") || host.contains("larksuite.com") { return "飞书" }
        if host.contains("dingtalk.com") { return "钉钉" }
        if host.contains("yuque.com") { return "语雀文档" }
        if host.contains("notion.so") { return "Notion" }
        if host.contains("bigmodel.cn") || host.contains("zhipuai.cn") { return "智谱大模型平台" }
        return host
    }

    /// 辅助方法：基于 PID 的 System Events 标题嗅探
    private func fetchFrontAppWindowTitle(pid: pid_t, processName: String) -> String? {
        let scriptSource = """
        tell application "System Events"
            try
                tell (first process whose unix id is \(pid))
                    set winTitle to name of front window
                    return winTitle
                end tell
            on error
                return ""
            end try
        end tell
        """

        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            let res = script.executeAndReturnError(&error)
            let val = res.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let val = val, !val.isEmpty {
                return val
            }
        }
        return nil
    }

    /// 深度嗅探前台窗口内部的关键文本内容 (基于 Accessibility 穿透，多层级提取正文)
    private func fetchFrontWindowText(pid: pid_t, processName: String) -> String? {
        let escapedName = processName.replacingOccurrences(of: "\"", with: "\\\"")
        let scriptSource = """
        tell application "System Events"
            try
                set targetProc to missing value
                try
                    set targetProc to (first process whose unix id is \(pid))
                on error
                    set targetProc to process "\(escapedName)"
                end try
                if targetProc is missing value then return ""
                tell targetProc
                    set w to front window
                    set allText to ""
                    try
                        set docPath to value of attribute "AXDocument" of w
                        if docPath is not missing value and (docPath as text) is not "" then
                            set allText to allText & "文档:" & (docPath as text) & " "
                        end if
                    end try

                    -- 1. 尝试直接获取顶层文本 (过滤侧边栏、历史列表与导航按钮噪音)
                    try
                        set tList to value of every static text of w
                        repeat with i from 1 to (count of tList)
                            if i > 8 then exit repeat
                            set itemText to (item i of tList) as text
                            set isNoise to false
                            -- 过滤侧边栏导航与历史会话条目噪音
                            if itemText contains "Cowork" or itemText contains "Customize" or itemText contains "New Conversation" or itemText contains "Pinned" or itemText contains "城堡" or itemText contains "FDE案例" then
                                set isNoise to true
                            end if
                            if (length of itemText) > 2 and (length of itemText) < 140 and not isNoise then
                                set allText to allText & itemText & " "
                            end if
                        end repeat
                    end try

                    -- 2. 深入第一层容器穿透文本 (针对 Electron / Chromium 复合容器)
                    try
                        if (length of allText) < 20 then
                            set gList to every UI element of w
                            repeat with gItem in gList
                                try
                                    set subTexts to value of every static text of gItem
                                    repeat with st in subTexts
                                        set sVal to st as text
                                        if (length of sVal) > 2 and (length of sVal) < 140 then
                                            set allText to allText & sVal & " "
                                            if (length of allText) > 250 then exit repeat
                                        end if
                                    end repeat
                                end try
                                if (length of allText) > 250 then exit repeat
                            end repeat
                        end if
                    end try

                    return allText
                end tell
            on error
                return ""
            end try
        end tell
        """

        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            let res = script.executeAndReturnError(&error)
            let val = res.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let val = val, !val.isEmpty {
                return String(val.prefix(350))
            }
        }
        return nil
    }

    /// 嗅探 ZCode 活跃工程项目 (仅当当前处于 ZCode 内部时生效)
    private func fetchZCodeActiveProject() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let settingFile = home.appendingPathComponent(".zcode/v2/setting.json")
        guard let data = try? Data(contentsOf: settingFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let activeWs = json["lastActiveWorkspace"] as? [String: Any],
              let path = activeWs["workspacePath"] as? String else {
            return nil
        }
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }

    /// 深度解析窗口标题中的工程名与代码文件路径
    private func parseWindowFileAndProject(appName: String, bundleId: String, windowTitle: String) -> (project: String?, filePath: String?) {
        let nameLower = appName.lowercased()
        let idLower = bundleId.lowercased()

        // 1. Antigravity 宿主精准识别 (绑定正在进行的真实项目：全局记忆精灵 ContextFlow)
        if nameLower.contains("antigravity") || idLower.contains("antigravity") {
            let clean = windowTitle
                .replacingOccurrences(of: "Outside of Project...", with: "")
                .replacingOccurrences(of: " - ", with: " · ")
                .trimmingCharacters(in: .whitespaces)
            let desc = clean.isEmpty ? "ContextFlow 客户端重构与架构设计" : clean
            return ("全局记忆精灵 (ContextFlow)", desc)
        }

        // 2. ZCode 专用解析 (严格限定在 ZCode 应用前台时)
        if nameLower.contains("zcode") || idLower.contains("zcode") {
            let p = fetchZCodeActiveProject()
            let f = (windowTitle != appName && !windowTitle.isEmpty) ? windowTitle : nil
            return (p, f)
        }

        // 3. VS Code / Cursor / Trae / Windsurf / Xcode / JetBrains
        let isCodeEditor = isEditorOrIDE(bundleId: bundleId, appName: appName)
        if isCodeEditor {
            let separators = [" — ", " - ", " – "]
            for sep in separators {
                if windowTitle.contains(sep) {
                    let parts = windowTitle.components(separatedBy: sep)
                    if parts.count >= 2 {
                        let potentialFile = parts[0].trimmingCharacters(in: .whitespaces)
                        let potentialProj = parts[1].trimmingCharacters(in: .whitespaces)
                        if potentialFile.contains(".") {
                            return (potentialProj, potentialFile)
                        }
                    }
                }
            }
            if windowTitle.contains(".") {
                return (nil, windowTitle)
            }
        }

        // 3. 通用本地文档 / 文件
        if windowTitle.contains("/") || windowTitle.hasSuffix(".docx") || windowTitle.hasSuffix(".xlsx") ||
           windowTitle.hasSuffix(".md") || windowTitle.hasSuffix(".pdf") || windowTitle.hasSuffix(".json") {
            return (nil, windowTitle)
        }

        return (nil, nil)
    }

    private func isEditorOrIDE(bundleId: String, appName: String) -> Bool {
        let str = (bundleId + " " + appName).lowercased()
        return str.contains("code") || str.contains("xcode") || str.contains("cursor") ||
               str.contains("trae") || str.contains("antigravity") || str.contains("idea") ||
               str.contains("pycharm") || str.contains("webstorm") || str.contains("sublime")
    }
}
