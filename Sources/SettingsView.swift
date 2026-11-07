import SwiftUI
import Cocoa

@MainActor
public final class SettingsWindowController: NSObject {
    public static let shared = SettingsWindowController()

    private var window: NSWindow?

    public func showWindow() {
        // 先关闭菜单栏 Popover，避免交互焦点冲突
        MenuBarManager.shared.closePopover(nil)

        if let w = window {
            w.level = .floating
            w.center()
            w.makeKeyAndOrderFront(nil)
            w.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 490),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.center()
        newWindow.title = "全局记忆精灵 设置"
        newWindow.contentViewController = hostingController
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .floating
        newWindow.hidesOnDeactivate = false

        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
}

public struct SettingsView: View {
    @ObservedObject var engine = ContextEngine.shared
    @ObservedObject var lifelog = LifeLogSyncManager.shared
    @ObservedObject var themeMgr = ThemeManager.shared

    // MARK: - AI 配置状态
    @State private var selectedProvider: String = "deepseek"
    @State private var aiBaseURL: String = "https://api.deepseek.com/v1"
    @State private var aiApiKey: String = ""
    @State private var aiModel: String = "deepseek-chat"
    @State private var showApiKey: Bool = false
    @State private var isTestingConnection: Bool = false
    @State private var testResultText: String? = nil
    @State private var isTestSuccess: Bool = false

    // MARK: - 外观与主题状态
    @State private var selectedTheme: AppTheme = ThemeManager.shared.currentTheme

    // MARK: - GitHub 编年史状态
    @State private var enableGitHubSync: Bool = false
    @State private var gitHubRepo: String = ""
    @State private var syncIntervalHours: Int = 2

    // MARK: - 隐私黑名单状态
    @State private var ignoredApps: [String] = []
    @State private var newIgnoredAppName: String = ""

    // MARK: - 感知与高级偏好
    @State private var transientThreshold: Double = 30
    @State private var maxSuspended: Double = 5
    @State private var enableThumbnails: Bool = true
    @State private var isRefreshingAll: Bool = false
    @State private var refreshAlertText: String? = nil

    // MARK: - 权限状态
    @State private var isAXGranted: Bool = PermissionsManager.shared.isAccessibilityGranted()
    @State private var isSCGranted: Bool = PermissionsManager.shared.isScreenCaptureGranted()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            TabView {
                // Tab 1: AI 记忆引擎 (BYOK)
                aiSettingsTab
                    .tabItem {
                        Label("AI 记忆引擎", systemImage: "sparkles")
                    }

                // Tab 2: 隐私与忽略应用
                privacySettingsTab
                    .tabItem {
                        Label("隐私与黑名单", systemImage: "hand.raised.fill")
                    }

                // Tab 3: 数字编年史与 GitHub
                lifelogSettingsTab
                    .tabItem {
                        Label("数字编年史", systemImage: "book.closed")
                    }

                // Tab 4: 外观与个性主题
                appearanceSettingsTab
                    .tabItem {
                        Label("外观与主题", systemImage: "paintpalette.fill")
                    }

                // Tab 5: 系统权限与高级
                generalSettingsTab
                    .tabItem {
                        Label("权限与高级", systemImage: "gearshape")
                    }
            }
            .padding(16)

            Divider()

            HStack {
                Text("全局记忆精灵 开源版 · 运行中数据均本地化存储")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                Button("重置默认") {
                    resetToDefaults()
                }
                .controlSize(.small)

                Button("保存配置") {
                    saveAllSettings()
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 540, height: 490)
        .onAppear {
            loadCurrentSettings()
            refreshPermissionsStatus()
        }
    }

    private func loadCurrentSettings() {
        let s = engine.settings
        self.selectedProvider = s.aiProvider
        self.aiBaseURL = s.aiBaseURL
        self.aiApiKey = s.aiApiKey
        self.aiModel = s.aiModel

        self.enableGitHubSync = s.enableGitHubSync
        self.gitHubRepo = s.gitHubRepo
        self.syncIntervalHours = s.syncIntervalHours

        self.ignoredApps = s.customIgnoredApps
        self.transientThreshold = Double(s.transientThresholdSeconds)
        self.maxSuspended = Double(s.maxDisplaySuspended)
        self.enableThumbnails = s.enableThumbnails
        if let t = AppTheme(rawValue: s.theme) {
            self.selectedTheme = t
        }
    }

    private func saveAllSettings() {
        var s = engine.settings
        s.aiProvider = selectedProvider
        s.aiBaseURL = aiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        s.aiApiKey = aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        s.aiModel = aiModel.trimmingCharacters(in: .whitespacesAndNewlines)

        s.enableGitHubSync = enableGitHubSync
        s.gitHubRepo = gitHubRepo.trimmingCharacters(in: .whitespacesAndNewlines)
        s.syncIntervalHours = syncIntervalHours

        s.customIgnoredApps = ignoredApps
        s.transientThresholdSeconds = Int(transientThreshold)
        s.maxDisplaySuspended = Int(maxSuspended)
        s.enableThumbnails = enableThumbnails
        s.theme = selectedTheme.rawValue

        engine.settings = s
        engine.persistState()
        themeMgr.applyTheme(selectedTheme)
        AppLogger.shared.log(tag: "SETTINGS", message: "全局配置与主题 [\(selectedTheme.displayName)] 已保存更新！")
    }

    private func resetToDefaults() {
        let def = AppSettings()
        self.selectedProvider = def.aiProvider
        self.aiBaseURL = def.aiBaseURL
        self.aiApiKey = ""
        self.aiModel = def.aiModel
        self.enableGitHubSync = def.enableGitHubSync
        self.gitHubRepo = ""
        self.syncIntervalHours = def.syncIntervalHours
        self.ignoredApps = def.customIgnoredApps
        self.transientThreshold = Double(def.transientThresholdSeconds)
        self.maxSuspended = Double(def.maxDisplaySuspended)
        self.enableThumbnails = def.enableThumbnails
        self.selectedTheme = .amber
        themeMgr.applyTheme(.amber)
    }

    private func refreshPermissionsStatus() {
        isAXGranted = PermissionsManager.shared.isAccessibilityGranted()
        isSCGranted = PermissionsManager.shared.isScreenCaptureGranted()
    }

    // MARK: - Tab 1: AI 记忆引擎 (BYOK)

    private var aiSettingsTab: some View {
        Form {
            Section(header: Text("服务提供商预设 (自带密钥 BYOK)").font(.headline)) {
                Picker("快捷预设：", selection: $selectedProvider) {
                    Text("DeepSeek (官方)").tag("deepseek")
                    Text("智谱 GLM-4-Flash").tag("zhipu")
                    Text("OpenAI (官方)").tag("openai")
                    Text("SiliconFlow (硅基流动)").tag("siliconflow")
                    Text("Ollama (本地离线)").tag("ollama")
                    Text("自定义兼容中转 (Custom)").tag("custom")
                }
                .onChange(of: selectedProvider) { _, provider in
                    applyProviderPreset(provider)
                }

                Text("支持任意遵循 OpenAI 标准协议的接口服务，包括 DeepSeek、智谱、通义千问、Kimi 或本地大模型。")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }

            Section(header: Text("API 连接参数").font(.headline)) {
                TextField("Base URL:", text: $aiBaseURL)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    if showApiKey {
                        TextField("API Key:", text: $aiApiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("API Key:", text: $aiApiKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(action: {
                        showApiKey.toggle()
                    }) {
                        Image(systemName: showApiKey ? "eye.slash" : "eye")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help(showApiKey ? "隐藏密钥" : "显示明文")
                }

                TextField("Model Name:", text: $aiModel)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button(action: {
                        testAIConnection()
                    }) {
                        HStack(spacing: 4) {
                            if isTestingConnection {
                                ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                            }
                            Text("测试连通性")
                        }
                    }
                    .disabled(isTestingConnection)
                    .controlSize(.small)

                    if let result = testResultText {
                        Text(result)
                            .font(.system(size: 11))
                            .foregroundColor(isTestSuccess ? .green : .red)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 2)
            }

            Section(header: Text("开箱即用保障").font(.headline)) {
                Text("💡 若暂不填写 API Key，全局记忆精灵将自动启用 Apple Neural Engine 本地视觉与实体离线引擎，完全断网可用。")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
        }
    }

    private func applyProviderPreset(_ provider: String) {
        switch provider {
        case "deepseek":
            aiBaseURL = "https://api.deepseek.com/v1"
            aiModel = "deepseek-chat"
        case "zhipu":
            aiBaseURL = "https://open.bigmodel.cn/api/paas/v4"
            aiModel = "glm-4-flash"
        case "openai":
            aiBaseURL = "https://api.openai.com/v1"
            aiModel = "gpt-4o-mini"
        case "siliconflow":
            aiBaseURL = "https://api.siliconflow.cn/v1"
            aiModel = "Qwen/Qwen2.5-7B-Instruct"
        case "ollama":
            aiBaseURL = "http://localhost:11434/v1"
            aiModel = "qwen2.5:7b"
            aiApiKey = "ollama"
        default:
            break
        }
    }

    private func testAIConnection() {
        isTestingConnection = true
        testResultText = nil
        let base = aiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = aiModel.trimmingCharacters(in: .whitespacesAndNewlines)

        AISummarizer.shared.testConnection(baseURL: base, apiKey: key, model: model) { success, msg in
            DispatchQueue.main.async {
                self.isTestingConnection = false
                self.isTestSuccess = success
                self.testResultText = msg
            }
        }
    }

    // MARK: - Tab 2: 隐私与忽略黑名单

    private var privacySettingsTab: some View {
        Form {
            Section(header: Text("隐私保护原则").font(.headline)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("• 0 截图云端上传：离开瞬间的微缩视窗快照与 OCR 均在 Apple 神经引擎离线计算。")
                    Text("• 敏感信息免打扰：系统级密码管理器、安全鉴权弹窗已默认永久绝不嗅探。")
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineSpacing(2)
            }

            Section(header: Text("已忽略的应用名单 (不记录、不挂起)").font(.headline)) {
                HStack {
                    TextField("输入应用名或 BundleId (如 1Password)", text: $newIgnoredAppName)
                        .textFieldStyle(.roundedBorder)

                    Button("添加") {
                        let name = newIgnoredAppName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty && !ignoredApps.contains(name) {
                            ignoredApps.append(name)
                            newIgnoredAppName = ""
                        }
                    }
                    .controlSize(.small)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(ignoredApps, id: \.self) { app in
                            HStack {
                                Image(systemName: "slash.circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(app)
                                    .font(.system(size: 11.5))
                                Spacer()
                                Button(action: {
                                    ignoredApps.removeAll { $0 == app }
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10))
                                        .foregroundColor(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                            .cornerRadius(4)
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
    }

    // MARK: - Tab 3: 数字编年史与 GitHub 归档

    private var lifelogSettingsTab: some View {
        Form {
            Section(header: Text("GitHub 私有编年史同步").font(.headline)) {
                Toggle("启用 GitHub 私有归档自动同步", isOn: $enableGitHubSync)
                    .font(.system(size: 12, weight: .medium))

                VStack(alignment: .leading, spacing: 4) {
                    Text("GitHub 私有仓库：")
                        .foregroundColor(.secondary)
                    TextField("格式：用户名/仓库名 (如 yourname/my-lifelog)", text: $gitHubRepo)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!enableGitHubSync)

                    Text("提示：推荐在 GitHub 上创建一个 Private（私有）仓库，并将本机 SSH Key 或 Personal Access Token 添加至账户，实现每日静默无感备份。")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }

                Picker("自动同步周期：", selection: $syncIntervalHours) {
                    Text("每 1 小时自动提交").tag(1)
                    Text("每 2 小时自动提交 (推荐)").tag(2)
                    Text("每 4 小时自动提交").tag(4)
                }
                .disabled(!enableGitHubSync)

                HStack {
                    Button("立即测试推送") {
                        saveAllSettings()
                        lifelog.triggerSync(isManual: true)
                    }
                    .controlSize(.small)
                    .disabled(!enableGitHubSync || gitHubRepo.isEmpty)

                    if let msg = lifelog.syncMessage {
                        Text(msg)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }

            Section(header: Text("本地归档目录").font(.headline)) {
                HStack {
                    Text("~/.contextflow/lifelog-repo")
                        .font(.system(size: 11, design: .monospaced))
                    Spacer()
                    Button("在访达中打开") {
                        let path = (FileManager.default.homeDirectoryForCurrentUser.path as NSString).appendingPathComponent(".contextflow/lifelog-repo")
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Tab 4: 权限与高级偏好

    private var generalSettingsTab: some View {
        Form {
            Section(header: Text("系统核心权限 (请求一次，长期有效)").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    // 1. 辅助功能
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("辅助功能权限 (Accessibility)")
                                .font(.system(size: 12, weight: .medium))
                            Text("用于毫秒级穿透前台窗口与标签页标题")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if isAXGranted {
                            Text("已就绪").font(.system(size: 11, weight: .medium)).foregroundColor(.green)
                        } else {
                            Button("去开启") { PermissionsManager.shared.openSystemSettings(for: "accessibility") }.controlSize(.small)
                        }
                    }

                    Divider()

                    // 2. 屏幕录制
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("屏幕快照与本地视觉 (Vision)")
                                .font(.system(size: 12, weight: .medium))
                            Text("离开瞬间微缩快照与离线大字实体提炼")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if isSCGranted {
                            Text("已就绪").font(.system(size: 11, weight: .medium)).foregroundColor(.green)
                        } else {
                            Button("去开启") { PermissionsManager.shared.openSystemSettings(for: "screenCapture") }.controlSize(.small)
                        }
                    }
                }
            }

            Section(header: Text("感知参数调节").font(.headline)) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("微打断宽限时间：")
                        Spacer()
                        Text("\(Int(transientThreshold)) 秒")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    Slider(value: $transientThreshold, in: 10...120, step: 5)
                    Text("切去微信、备忘录等小于该时长视为临时查阅，不打断原主现场。")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("状态栏常驻现场上限：")
                        Spacer()
                        Text("\(Int(maxSuspended)) 个")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    Slider(value: $maxSuspended, in: 3...15, step: 1)
                }

                Toggle("离开瞬间保存视窗微缩图", isOn: $enableThumbnails)
                    .font(.system(size: 11.5))
            }

            Section(header: Text("数据与本地维护").font(.headline)) {
                HStack(spacing: 8) {
                    Button("打开数据目录 (~/.contextflow)") {
                        let path = (FileManager.default.homeDirectoryForCurrentUser.path as NSString).appendingPathComponent(".contextflow")
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                    }
                    .controlSize(.small)

                    Button("重新提炼所有现场") {
                        isRefreshingAll = true
                        engine.reSummarizeAllSuspendedSessions { count in
                            isRefreshingAll = false
                            refreshAlertText = "已完成 \(count) 个现场重提炼"
                        }
                    }
                    .controlSize(.small)
                    .disabled(isRefreshingAll)

                    if let alert = refreshAlertText {
                        Text(alert)
                            .font(.system(size: 10.5))
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }

    // MARK: - Tab 5: 外观与个性主题设置

    private var appearanceSettingsTab: some View {
        Form {
            Section(header: Text("视觉质感与主题配色").font(.headline)) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("选择适合您工作习惯的主题风格。切换立即生效于主菜单浮窗与全景大工作台。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    ForEach(AppTheme.allCases) { theme in
                        HStack(spacing: 12) {
                            HStack(spacing: -4) {
                                ForEach(0..<theme.previewColors.count, id: \.self) { i in
                                    Circle()
                                        .fill(theme.previewColors[i])
                                        .frame(width: 14, height: 14)
                                        .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
                                }
                            }
                            .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(theme.displayName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(theme.subtitle)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if selectedTheme == theme {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(theme.accentColor)
                                    .font(.system(size: 14))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(selectedTheme == theme ? theme.badgeBackground : Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedTheme == theme ? theme.accentColor.opacity(0.5) : Color.primary.opacity(0.06), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTheme = theme
                            themeMgr.applyTheme(theme)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
