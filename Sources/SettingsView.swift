import SwiftUI
import Cocoa

@MainActor
public final class SettingsWindowController: NSObject {
    public static let shared = SettingsWindowController()

    private var window: NSWindow?

    public func showWindow(tab: String? = nil) {
        // 先关闭菜单栏 Popover，避免交互焦点冲突
        MenuBarManager.shared.closePopover(nil)

        if let w = window {
            w.level = .floating
            w.center()
            w.makeKeyAndOrderFront(nil)
            w.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            if let targetTab = tab {
                NotificationCenter.default.post(name: NSNotification.Name("ContextFlow.SwitchSettingsTab"), object: targetTab)
            }
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 620),
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

        if let targetTab = tab {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: NSNotification.Name("ContextFlow.SwitchSettingsTab"), object: targetTab)
            }
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var engine = ContextEngine.shared
    @ObservedObject var lifelog = LifeLogSyncManager.shared
    @ObservedObject var themeMgr = ThemeManager.shared
    @ObservedObject var loc = LocalizationManager.shared

    // MARK: - 导航选卡 (标准 macOS 顶部原生胶囊分段导航)
    @State private var currentTab: String = "ai" // ai, privacy, lifelog, appearance, general

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

    // MARK: - 自适应模型与客户端探查状态
    @State private var isScanningLocalModels: Bool = false
    @State private var detectionReport: DetectionReport? = nil
    @State private var adoptSuccessText: String? = nil

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
            // 1. 顶部经典分段导航栏
            topNavigationBar
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(Color(NSColor.windowBackgroundColor))

            Divider().opacity(0.4)

            // 2. 主体设置内容区
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    switch currentTab {
                    case "privacy":
                        privacyTabContent
                    case "lifelog":
                        lifelogTabContent
                    case "appearance":
                        appearanceTabContent
                    case "general":
                        generalTabContent
                    default:
                        aiTabContent
                    }
                }
                .padding(20)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.2))

            Divider().opacity(0.4)

            // 3. 底部常驻操作栏
            bottomActionBar
        }
        .frame(width: 680, height: 620)
        .onAppear {
            loadCurrentSettings()
            refreshPermissionsStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ContextFlow.SwitchSettingsTab"))) { notif in
            if let tab = notif.object as? String {
                withAnimation(.easeInOut(duration: 0.16)) {
                    self.currentTab = tab
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ContextFlow.TriggerModelScan"))) { _ in
            withAnimation(.easeInOut(duration: 0.16)) {
                self.currentTab = "ai"
            }
            self.triggerScanLocalModels()
        }
    }

    // MARK: - 顶部导航栏
    private var topNavigationBar: some View {
        HStack(spacing: 6) {
            tabNavButton(id: "ai", title: loc.t("tab_ai"), icon: "sparkles")
            tabNavButton(id: "privacy", title: loc.t("tab_privacy"), icon: "hand.raised.fill")
            tabNavButton(id: "lifelog", title: loc.t("tab_lifelog"), icon: "book.closed.fill")
            tabNavButton(id: "appearance", title: loc.t("tab_appearance"), icon: "paintpalette.fill")
            tabNavButton(id: "general", title: loc.t("tab_general"), icon: "gearshape.fill")
        }
        .padding(3)
        .background(Color.primary.opacity(0.06))
        .cornerRadius(9)
    }

    private func tabNavButton(id: String, title: String, icon: String) -> some View {
        let isSelected = currentTab == id
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.16)) {
                currentTab = id
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11.5))
                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color(NSColor.controlBackgroundColor) : Color.clear)
            .foregroundColor(isSelected ? themeMgr.currentTheme.accentColor : .secondary)
            .cornerRadius(7)
            .shadow(color: isSelected ? Color.black.opacity(0.08) : Color.clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 底部操作栏
    private var bottomActionBar: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("全局记忆精灵 · 数据均本地化存储在 ~/.contextflow")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(loc.t("btn_reset")) {
                resetToDefaults()
            }
            .controlSize(.regular)

            Button(action: {
                saveAllSettings()
                NSApp.keyWindow?.close()
            }) {
                Text(loc.t("btn_save"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(themeMgr.currentTheme.accentColor)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Tab 1: AI 记忆引擎 (BYOK 与多 Key 容灾池 + 自适应本地大模型发现)
    private var aiTabContent: some View {
        VStack(spacing: 14) {
            // 卡片 0: 自适应识别本地大模型与软件配置
            cardContainer(
                title: "🔍 本地大模型与软件环境自适应嗅探",
                badge: isScanningLocalModels ? "并发探测中..." : (detectionReport != nil ? "发现 \(detectionReport!.services.count) 端点 / \(detectionReport!.installedApps.count) 软件" : "DeepSeek Harness 机制")
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("自适应识别本地各种模型和软件，兼容主流模型软件授权与环境变量一键导入。")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            triggerScanLocalModels()
                        }) {
                            HStack(spacing: 4) {
                                if isScanningLocalModels {
                                    ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                                    Text("正在嗅探...")
                                } else {
                                    Image(systemName: "sparkle.magnifyingglass")
                                    Text("一键智能探测")
                                }
                            }
                            .font(.system(size: 11.5, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(themeMgr.currentTheme.accentColor.opacity(0.12))
                            .foregroundColor(themeMgr.currentTheme.accentColor)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(isScanningLocalModels)
                    }

                    if let alert = adoptSuccessText {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text(alert).font(.system(size: 11, weight: .semibold)).foregroundColor(.green)
                        }
                        .padding(6)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                    }

                    // 报告回显
                    if let rep = detectionReport {
                        VStack(alignment: .leading, spacing: 8) {
                            if !rep.services.isEmpty {
                                Text("发现的可用大模型服务与凭据：")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundColor(.secondary)

                                ForEach(rep.services) { s in
                                    HStack(spacing: 8) {
                                        Image(systemName: s.isLocalOffline ? "desktopcomputer" : "cloud.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(themeMgr.currentTheme.accentColor)

                                        VStack(alignment: .leading, spacing: 1) {
                                            HStack(spacing: 4) {
                                                Text(s.name).font(.system(size: 11.5, weight: .semibold))
                                                Text("(\(s.sourceDescription))")
                                                    .font(.system(size: 9.5))
                                                    .foregroundColor(.secondary)
                                            }
                                            Text("端点: \(s.baseURL) · 模型: \(s.models.prefix(2).joined(separator: ", "))")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Button("一键装配") {
                                            adoptDiscoveredService(s)
                                        }
                                        .controlSize(.small)
                                    }
                                    .padding(8)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                    .cornerRadius(6)
                                }
                            }

                            if !rep.installedApps.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("已识别并联动的本地开发与 AI 软件：")
                                        .font(.system(size: 10.5, weight: .bold))
                                        .foregroundColor(.secondary)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(rep.installedApps) { app in
                                                HStack(spacing: 4) {
                                                    Circle().fill(app.isRunning ? Color.green : Color.secondary.opacity(0.4)).frame(width: 5, height: 5)
                                                    Text(app.name).font(.system(size: 10.5))
                                                }
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3.5)
                                                .background(Color.primary.opacity(0.05))
                                                .cornerRadius(5)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(8)
                    }
                }
            }

            // 卡片 1: 服务商预设
            cardContainer(title: "服务商预设 (自带密钥 BYOK)", badge: "兼容 OpenAI 标准协议") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Text("快捷预设：")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 90, alignment: .trailing)

                        Picker("", selection: $selectedProvider) {
                            Text("Agnes AI (官方高速 / 智能负载均衡)").tag("agnes")
                            Text("DeepSeek (官方深度思考)").tag("deepseek")
                            Text("智谱 GLM-4-Flash (高性价比)").tag("zhipu")
                            Text("OpenAI (官方 GPT-4o-mini)").tag("openai")
                            Text("SiliconFlow (硅基流动开源模型)").tag("siliconflow")
                            Text("Ollama (本地离线大模型)").tag("ollama")
                            Text("自定义兼容中转 (Custom)").tag("custom")
                        }
                        .labelsHidden()
                        .onChange(of: selectedProvider) { _, provider in
                            applyProviderPreset(provider)
                        }
                    }

                    Text("支持任意遵循 OpenAI 标准协议的接口服务，包括 Agnes AI、DeepSeek、智谱、通义千问或本地 Ollama。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.leading, 102)
                }
            }

            // 卡片 2: API 连接参数
            cardContainer(title: "API 连接参数", badge: nil) {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Text("Base URL：")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 90, alignment: .trailing)
                        TextField("例如 https://api.agnes-ai.cn/v1", text: $aiBaseURL)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 12) {
                        Text("Model Name：")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 90, alignment: .trailing)
                        TextField("例如 agnes-3.0-flash 或 deepseek-chat", text: $aiModel)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            // 卡片 3: 高可用 API Key 密钥池 (Key Pool)
            cardContainer(
                title: "高可用 API Key 密钥池 (Key Pool)",
                badge: parsedKeys.count > 1 ? "智能轮换已激活 (\(parsedKeys.count) 密钥)" : (parsedKeys.count == 1 ? "单密钥就绪" : "未配置密钥 · 离线模式")
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("API 密钥：")
                                .font(.system(size: 12, weight: .medium))
                            Button(action: {
                                showApiKey.toggle()
                            }) {
                                HStack(spacing: 2) {
                                    Image(systemName: showApiKey ? "eye.slash" : "eye")
                                    Text(showApiKey ? "密文" : "明文")
                                }
                                .font(.system(size: 10))
                                .foregroundColor(themeMgr.currentTheme.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(width: 90, alignment: .trailing)

                        VStack(alignment: .leading, spacing: 4) {
                            if showApiKey {
                                TextEditor(text: $aiApiKey)
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(height: 52)
                                    .padding(4)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                            } else {
                                SecureField("粘贴您的 API Key，支持多行或逗号录入多个 Key 组建容灾池", text: $aiApiKey)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Text("支持输入 1 个 Key，也可多行/逗号输入多个 Key 组建容灾轮换池。")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                    }

                    // 智能轮换开关
                    HStack(spacing: 12) {
                        Spacer().frame(width: 90)
                        Toggle(isOn: $enableKeyRotation) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("多 Key 智能轮换与超时自动故障转移 (Failover)")
                                    .font(.system(size: 11.5, weight: .medium))
                                Text("意图提炼与问答时按顺序轮换；遇到 429 限流或网络超时无缝转移至备用 Key。")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }

                    // 连通性测试与结果
                    HStack(spacing: 12) {
                        Spacer().frame(width: 90)
                        Button(action: {
                            testAIConnection()
                        }) {
                            HStack(spacing: 4) {
                                if isTestingConnection {
                                    ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                                    Text("正在测试...")
                                } else {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                    Text("测试连通性")
                                }
                            }
                            .font(.system(size: 11))
                        }
                        .disabled(parsedKeys.isEmpty || isTestingConnection)

                        if let res = testResultText {
                            Text(res)
                                .font(.system(size: 11))
                                .foregroundColor(isTestSuccess ? .green : .red)
                        }
                    }
                }
            }

            // 卡片 4: 开箱即用离线保障
            HStack(spacing: 10) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 16))
                    .foregroundColor(themeMgr.currentTheme.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("端侧离线神经引擎保障")
                        .font(.system(size: 11.5, weight: .semibold))
                    Text("若暂不填写 API Key 或网络离线，全局记忆精灵将自动启用 Apple Neural Engine 本地视觉与实体离线引擎，完全断网可用。")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
        }
    }

    // MARK: - 触发本地模型与软件嗅探
    private func triggerScanLocalModels() {
        isScanningLocalModels = true
        adoptSuccessText = nil
        ModelDetector.shared.scanAll { report in
            Task { @MainActor in
                self.isScanningLocalModels = false
                self.detectionReport = report
            }
        }
    }

    private func adoptDiscoveredService(_ service: DiscoveredModelService) {
        self.selectedProvider = service.provider
        self.aiBaseURL = service.baseURL
        if let first = service.models.first {
            self.aiModel = first
        }
        if let k = service.detectedKey, !k.isEmpty && k != "ollama" {
            if self.aiApiKey.isEmpty {
                self.aiApiKey = k
            } else if !self.aiApiKey.contains(k) {
                self.aiApiKey += "\n" + k
            }
        }
        saveAllSettings()
        withAnimation {
            adoptSuccessText = "已成功装配 [\(service.name)]，配置已即时生效！"
        }
    }

    // MARK: - Tab 2: 隐私与忽略黑名单
    private var privacyTabContent: some View {
        VStack(spacing: 14) {
            cardContainer(title: "隐私保护原则", badge: "本地计算 · 零上云") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundColor(themeMgr.currentTheme.accentColor)
                        Text("0 截图云端上传：离开瞬间的微缩视窗快照与 OCR 均在 Apple 神经引擎离线计算。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundColor(themeMgr.currentTheme.accentColor)
                        Text("敏感信息免打扰：系统级密码管理器、安全鉴权弹窗已默认永久绝不嗅探。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }

            cardContainer(title: "已忽略的应用名单 (不记录、不挂起)", badge: "\(ignoredApps.count) 个已拦截") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField("输入应用名或 BundleId (如 1Password)", text: $newIgnoredAppName)
                            .textFieldStyle(.roundedBorder)

                        Button("添加") {
                            let name = newIgnoredAppName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !name.isEmpty && !ignoredApps.contains(name) {
                                ignoredApps.append(name)
                                newIgnoredAppName = ""
                            }
                        }
                        .controlSize(.regular)
                    }

                    VStack(spacing: 4) {
                        ForEach(ignoredApps, id: \.self) { app in
                            HStack {
                                Image(systemName: "slash.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(app)
                                    .font(.system(size: 11.5))
                                Spacer()
                                Button(action: {
                                    ignoredApps.removeAll { $0 == app }
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                            .cornerRadius(6)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tab 3: 数字编年史与 GitHub 归档
    private var lifelogTabContent: some View {
        VStack(spacing: 14) {
            cardContainer(title: "GitHub 私有编年史同步", badge: enableGitHubSync ? "自动同步中" : "未开启") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text("自动同步：")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 100, alignment: .trailing)

                        Toggle("启用 GitHub 私有归档自动同步", isOn: $enableGitHubSync)
                            .font(.system(size: 12, weight: .medium))
                    }

                    HStack(alignment: .top, spacing: 12) {
                        Text("GitHub 仓库：")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 100, alignment: .trailing)

                        VStack(alignment: .leading, spacing: 4) {
                            TextField("格式：用户名/仓库名 (如 yourname/my-lifelog)", text: $gitHubRepo)
                                .textFieldStyle(.roundedBorder)
                                .disabled(!enableGitHubSync)

                            Text("推荐在 GitHub 上创建 Private（私有）仓库，并将本机 SSH Key 或 PAT 添加至账户，实现每日静默无感备份。")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                        }
                    }

                    HStack(spacing: 12) {
                        Text("同步周期：")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 100, alignment: .trailing)

                        Picker("", selection: $syncIntervalHours) {
                            Text("每 1 小时自动提交").tag(1)
                            Text("每 2 小时自动提交 (推荐)").tag(2)
                            Text("每 4 小时自动提交").tag(4)
                        }
                        .labelsHidden()
                        .disabled(!enableGitHubSync)
                    }

                    HStack(spacing: 12) {
                        Spacer().frame(width: 100)

                        Button("立即测试推送") {
                            saveAllSettings()
                            lifelog.triggerSync(isManual: true)
                        }
                        .controlSize(.regular)
                        .disabled(!enableGitHubSync || gitHubRepo.isEmpty)

                        if let msg = lifelog.syncMessage {
                            Text(msg)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            cardContainer(title: "本地归档目录", badge: nil) {
                HStack(spacing: 12) {
                    Text("存储路径：")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 100, alignment: .trailing)

                    Text("~/.contextflow/lifelog-repo")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(.primary)

                    Spacer()

                    Button("在访达中打开") {
                        let path = (FileManager.default.homeDirectoryForCurrentUser.path as NSString).appendingPathComponent(".contextflow/lifelog-repo")
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                    }
                    .controlSize(.regular)
                }
            }
        }
    }

    // MARK: - Tab 4: 外观、个性主题与语言设定
    private var appearanceTabContent: some View {
        VStack(spacing: 14) {
            // 语言设置
            cardContainer(title: "界面语言设定 (Language / 言語)", badge: loc.currentLanguage.displayName) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("支持中文、英文与日文界面自适应切换，切换后即刻全局生效。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Picker("显示语言：", selection: Binding(
                        get: { loc.currentLanguage },
                        set: { newLang in loc.setLanguage(newLang) }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            cardContainer(title: "视觉质感与主题配色", badge: "5 套精调色彩") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("选择适合您工作习惯的主题风格。切换立即生效于全景大工作台与菜单栏小窗口。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

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
                                    .font(.system(size: 16))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedTheme == theme ? theme.badgeBackground : Color(NSColor.controlBackgroundColor).opacity(0.35))
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
            }
        }
    }

    // MARK: - Tab 5: 权限与高级维护
    private var generalTabContent: some View {
        VStack(spacing: 14) {
            cardContainer(title: "系统核心权限", badge: "本地一次性授权") {
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("辅助功能权限 (Accessibility)")
                                .font(.system(size: 12, weight: .medium))
                            Text("用于毫秒级穿透前台窗口与标签页标题，零截图纯文本无感感知")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if isAXGranted {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                Text("已就绪").font(.system(size: 11, weight: .medium)).foregroundColor(.green)
                            }
                        } else {
                            Button("去开启") { PermissionsManager.shared.openSystemSettings(for: "accessibility") }.controlSize(.small)
                        }
                    }

                    Divider().opacity(0.3)

                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("屏幕快照与本地视觉 (Vision)")
                                .font(.system(size: 12, weight: .medium))
                            Text("仅在离开瞬间保存微缩快照与离线大字实体提炼，永不云端上传")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if isSCGranted {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                Text("已就绪").font(.system(size: 11, weight: .medium)).foregroundColor(.green)
                            }
                        } else {
                            Button("去开启") { PermissionsManager.shared.openSystemSettings(for: "screenCapture") }.controlSize(.small)
                        }
                    }
                }
            }

            cardContainer(title: "感知参数调节", badge: nil) {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Text("微打断宽限：")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 90, alignment: .trailing)

                        Slider(value: $transientThreshold, in: 10...120, step: 5)

                        Text("\(Int(transientThreshold)) 秒")
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 45, alignment: .trailing)
                    }

                    HStack(spacing: 12) {
                        Text("常驻现场上限：")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 90, alignment: .trailing)

                        Slider(value: $maxSuspended, in: 3...15, step: 1)

                        Text("\(Int(maxSuspended)) 个")
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 45, alignment: .trailing)
                    }

                    HStack(spacing: 12) {
                        Spacer().frame(width: 90)
                        Toggle("离开瞬间保存视窗微缩图", isOn: $enableThumbnails)
                            .font(.system(size: 11.5))
                    }
                }
            }

            cardContainer(title: "本地 SQLite 数据库与数据维护", badge: "SQLite3 + FTS5") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Button("打开数据目录 (~/.contextflow)") {
                            let path = (FileManager.default.homeDirectoryForCurrentUser.path as NSString).appendingPathComponent(".contextflow")
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                        }
                        .controlSize(.regular)

                        Button("重新提炼所有现场") {
                            isRefreshingAll = true
                            engine.reSummarizeAllSuspendedSessions { count in
                                isRefreshingAll = false
                                refreshAlertText = "已完成 \(count) 个现场重提炼"
                            }
                        }
                        .controlSize(.regular)
                        .disabled(isRefreshingAll)

                        if let alert = refreshAlertText {
                            Text(alert)
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                        }
                    }

                    Text("当前会话与时序流水已持久化至本地 SQLite3 WAL 数据库与 FTS5 全文索引。")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 通用卡片容器
    private func cardContainer<Content: View>(title: String, badge: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                if let b = badge {
                    Text(b)
                        .font(.system(size: 10.5))
                        .foregroundColor(themeMgr.currentTheme.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(themeMgr.currentTheme.accentColor.opacity(0.12))
                        .cornerRadius(5)
                }
            }

            Divider().opacity(0.3)

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.8)
        )
    }

    // MARK: - 内部业务方法
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
                    self.testResultText = "⚠️ 有 \(failedCount) 个通道连接失败"
                }
            }
        }
    }
}
