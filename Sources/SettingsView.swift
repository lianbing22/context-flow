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
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 560),
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
    @State private var selectedProvider: String = "agnes"
    @State private var aiBaseURL: String = "https://api.agnes-ai.cn/v1"
    @State private var aiApiKey: String = ""
    @State private var aiModel: String = "agnes-3.0-flash"
    @State private var enableKeyRotation: Bool = true
    @State private var showApiKey: Bool = false
    @State private var isTestingConnection: Bool = false
    @State private var testResultText: String? = nil
    @State private var isTestSuccess: Bool = false
    @State private var keyTestResults: [KeyTestResult] = []

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

    private var parsedKeys: [String] {
        let raw = aiApiKey
        var res: [String] = []
        for line in raw.components(separatedBy: .newlines) {
            for part in line.components(separatedBy: ",") {
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && !res.contains(trimmed) {
                    res.append(trimmed)
                }
            }
        }
        return res
    }

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
        .frame(width: 600, height: 560)
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
        self.enableKeyRotation = s.enableKeyRotation

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

        if !self.parsedKeys.isEmpty && self.testResultText == nil {
            self.testAIConnection()
        }
    }

    private func saveAllSettings() {
        var s = engine.settings
        s.aiProvider = selectedProvider
        s.aiBaseURL = aiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        s.aiApiKey = aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        s.aiModel = aiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        s.enableKeyRotation = enableKeyRotation

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
        self.enableKeyRotation = def.enableKeyRotation
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

    // MARK: - Tab 1: AI 记忆引擎 (BYOK 与多 Key 轮换池)

    private var aiSettingsTab: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                // 卡片 1: 服务商预设与基础协议
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("服务商预设 (自带密钥 BYOK)")
                            .font(.system(size: 12.5, weight: .bold))
                        Spacer()
                        Text("兼容 OpenAI 标准协议")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }

                    Picker("快捷预设：", selection: $selectedProvider) {
                        Text("Agnes AI (官方高速 / 智能负载均衡)").tag("agnes")
                        Text("DeepSeek (官方深度思考)").tag("deepseek")
                        Text("智谱 GLM-4-Flash (超高性价比)").tag("zhipu")
                        Text("OpenAI (官方 GPT-4o-mini)").tag("openai")
                        Text("SiliconFlow (硅基流动开源模型)").tag("siliconflow")
                        Text("Ollama (本地离线大模型)").tag("ollama")
                        Text("自定义兼容中转 (Custom)").tag("custom")
                    }
                    .labelsHidden()
                    .onChange(of: selectedProvider) { _, provider in
                        applyProviderPreset(provider)
                    }

                    Text("支持任意遵循 OpenAI 标准协议的接口服务，包括 Agnes AI、DeepSeek、智谱、通义千问或本地 Ollama。")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(8)

                // 卡片 2: API 连接参数
                VStack(alignment: .leading, spacing: 8) {
                    Text("API 连接参数")
                        .font(.system(size: 12.5, weight: .bold))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Base URL (API 端点)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("例如 https://api.agnes-ai.cn/v1", text: $aiBaseURL)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model Name (模型代号)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("例如 agnes-3.0-flash 或 deepseek-chat", text: $aiModel)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(8)

                // 卡片 3: 多 Key 智能轮换与故障转移池 (Key Pool)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("高可用 API Key 密钥池 (Key Pool)")
                            .font(.system(size: 12.5, weight: .bold))

                        Spacer()

                        if parsedKeys.count > 1 {
                            HStack(spacing: 4) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text("智能轮换已激活 (\(parsedKeys.count) 密钥)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(10)
                        } else if parsedKeys.count == 1 {
                            Text("单密钥通道就绪")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        } else {
                            Text("未配置密钥 · 离线模式")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("API 密钥 (支持一行一个或逗号分隔录入多个 Key)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {
                                showApiKey.toggle()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: showApiKey ? "eye.slash" : "eye")
                                    Text(showApiKey ? "密文隐藏" : "明文查看")
                                }
                                .font(.system(size: 10.5))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                        }

                        if showApiKey {
                            TextEditor(text: $aiApiKey)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(height: 58)
                                .padding(4)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        } else {
                            // 密文状态下用多行 SecureField 或带掩码的单行显示
                            SecureField("粘贴您的 API Key，支持多行录入多个 Key 组建容灾池", text: $aiApiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    // 智能轮换开关
                    Toggle(isOn: $enableKeyRotation) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("多 Key 负载均衡与超时自动故障转移 (Failover)")
                                .font(.system(size: 11.5, weight: .semibold))
                            Text("高频意图提炼与问答时按顺序轮换负载；遇到 429 限流或网络超时无缝转移至备用 Key。")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .padding(.vertical, 2)

                    // 密钥池已解析状态回显
                    if !parsedKeys.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("已解析密钥通道 (\(parsedKeys.count) 个)：")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.secondary)

                            ForEach(Array(parsedKeys.enumerated()), id: \.offset) { idx, k in
                                HStack {
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(themeMgr.currentTheme.accentColor)
                                    Text("通道 \(idx + 1): \(AISummarizer.maskKey(k))")
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(idx == 0 ? "主力负载" : "热备/轮换")
                                        .font(.system(size: 9.5))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(NSColor.windowBackgroundColor).opacity(0.7))
                                .cornerRadius(4)
                            }
                        }
                    }

                    Divider().opacity(0.4)

                    // 连通性测试区
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Button(action: {
                                testAIConnection()
                            }) {
                                HStack(spacing: 5) {
                                    if isTestingConnection {
                                        ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                                    } else {
                                        Image(systemName: "antenna.radiowaves.left.and.right")
                                    }
                                    Text(parsedKeys.count > 1 ? "一键测试全部密钥池连通性" : "测试连通性")
                                }
                            }
                            .disabled(isTestingConnection || parsedKeys.isEmpty)
                            .controlSize(.small)

                            if let result = testResultText {
                                Text(result)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(isTestSuccess ? .green : .red)
                                    .lineLimit(1)
                            }
                        }

                        // 多 Key 测试详情独立展示
                        if !keyTestResults.isEmpty {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(keyTestResults) { item in
                                    HStack(spacing: 6) {
                                        Image(systemName: item.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(item.isSuccess ? .green : .red)
                                            .font(.system(size: 10))
                                        Text("\(item.maskedKey):")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        Text(item.message)
                                            .font(.system(size: 10))
                                            .foregroundColor(item.isSuccess ? .primary : .red)
                                    }
                                }
                            }
                            .padding(6)
                            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(8)

                // 卡片 4: 离线兜底保障
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "cpu")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("端侧离线神经引擎保障")
                            .font(.system(size: 11.5, weight: .bold))
                        Text("若未配置 API Key 或网络中断，系统会自动调用 Apple Neural Engine 本地视觉与实体离线引擎，毫秒级提取窗口意图，完全离线可用且 0 报错。")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(8)
            }
            .padding(1)
        }
    }

    private func applyProviderPreset(_ provider: String) {
        switch provider {
        case "agnes":
            aiBaseURL = "https://api.agnes-ai.cn/v1"
            aiModel = "agnes-3.0-flash"
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
        let keys = parsedKeys
        guard !keys.isEmpty else {
            testResultText = "请至少输入一个 API Key"
            isTestSuccess = false
            return
        }

        isTestingConnection = true
        testResultText = nil
        keyTestResults = []

        let base = aiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = aiModel.trimmingCharacters(in: .whitespacesAndNewlines)

        AISummarizer.shared.testAllConnections(baseURL: base, apiKeys: keys, model: model) { results in
            DispatchQueue.main.async {
                self.isTestingConnection = false
                self.keyTestResults = results
                let allSuccess = !results.isEmpty && results.allSatisfy { $0.isSuccess }
                self.isTestSuccess = allSuccess
                if allSuccess {
                    self.testResultText = "✓ 密钥池全部验证通过 (共 \(results.count) 个通道可用)"
                } else {
                    let failedCount = results.filter { !$0.isSuccess }.count
                    self.testResultText = "⚠️ 有 \(failedCount) 个通道连接失败，请查看详情"
                }
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
