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
    @State private var selectedProvider: String = "deepseek"
    @State private var aiBaseURL: String = "https://api.deepseek.com/v1"
    @State private var aiApiKey: String = ""
    @State private var aiModel: String = "deepseek-chat"
    @State private var enableKeyRotation: Bool = true
    @State private var showApiKey: Bool = false
    @State private var isTestingConnection: Bool = false
    @State private var testResultText: String? = nil
    @State private var isTestSuccess: Bool = false
    @State private var keyTestResults: [KeyTestResult] = []

    // MARK: - 自适应模型与客户端探查状态
    @State private var isScanningLocalModels: Bool = false
    @State private var detectionReport: HarnessDetectionReport? = nil
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

    public init(initialTab: String = "ai") {
        self._currentTab = State(initialValue: initialTab)
    }

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
                Text("全局记忆精灵 · 数据均安全落盘在本地 ~/.contextflow")
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

    // MARK: - Tab 1: AI 记忆引擎
    private var aiTabContent: some View {
        VStack(spacing: 14) {
            // 卡片 0: 模型与插件中心
            cardContainer(
                title: "🔌 插件化模型与授权中心 (DeepSeek Harness 架构)",
                badge: isScanningLocalModels ? "并发探测中..." : (detectionReport != nil ? "已就绪 \(detectionReport!.plugins.count) 个适配插件" : "自适应识别 · 一键装配")
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("自适应识别本机运行的本地离线模型、IDE 软件凭证以及云端模型开放平台。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(action: {
                            triggerScanLocalModels()
                        }) {
                            HStack(spacing: 4) {
                                if isScanningLocalModels {
                                    ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                                    Text("正在并发探查...")
                                } else {
                                    Image(systemName: "sparkle.magnifyingglass")
                                    Text("一键全景探测")
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

                    if let rep = detectionReport {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(rep.plugins) { plugin in
                                HStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(pluginColor(for: plugin.category).opacity(0.15))
                                            .frame(width: 26, height: 26)
                                        Image(systemName: pluginIcon(for: plugin.category))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(pluginColor(for: plugin.category))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(plugin.name)
                                                .font(.system(size: 11.5, weight: .bold))
                                            Text(plugin.authStatus)
                                                .font(.system(size: 9.5))
                                                .foregroundColor(plugin.detectedKey != nil ? .green : .secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.primary.opacity(0.04))
                                                .cornerRadius(3)
                                        }

                                        Text("\(plugin.baseURL) · 可用模型: \(plugin.models.prefix(3).joined(separator: ", "))")
                                            .font(.system(size: 9.5, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    HStack(spacing: 6) {
                                        if let pUrl = plugin.portalURL, let u = URL(string: pUrl) {
                                            Button(action: {
                                                NSWorkspace.shared.open(u)
                                            }) {
                                                HStack(spacing: 2) {
                                                    Image(systemName: "arrow.up.right.square")
                                                    Text("授权官网")
                                                }
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.primary.opacity(0.05))
                                                .cornerRadius(4)
                                            }
                                            .buttonStyle(.plain)
                                        }

                                        Button(action: {
                                            adoptDiscoveredPlugin(plugin)
                                        }) {
                                            HStack(spacing: 3) {
                                                Image(systemName: "bolt.fill")
                                                Text("一键装配")
                                            }
                                            .font(.system(size: 10.5, weight: .semibold))
                                            .foregroundColor(themeMgr.currentTheme.accentColor)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3.5)
                                            .background(themeMgr.currentTheme.accentColor.opacity(0.12))
                                            .cornerRadius(5)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
                                .cornerRadius(7)
                            }
                        }
                    }
                }
            }

            // 卡片 1: 服务商预设与参数
            cardContainer(title: "模型服务商与 API 连接配置", badge: "兼容 OpenAI 协议") {
                VStack(alignment: .leading, spacing: 12) {
                    // 服务商快捷选择行
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("预设服务商")
                                .font(.system(size: 12.5, weight: .medium))
                            Text("快速载入推荐的网关地址与主流大模型")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $selectedProvider) {
                            Text("DeepSeek (深度求索 · 推荐)").tag("deepseek")
                            Text("Agnes AI (高速智能网关)").tag("agnes")
                            Text("智谱 GLM-4-Flash").tag("zhipu")
                            Text("通义千问 (DashScope)").tag("qwen")
                            Text("月之暗面 Kimi").tag("kimi")
                            Text("OpenAI (官方 GPT-4o)").tag("openai")
                            Text("Ollama (本地离线大模型)").tag("ollama")
                            Text("自定义兼容中转 (Custom)").tag("custom")
                        }
                        .labelsHidden()
                        .frame(width: 220)
                        .onChange(of: selectedProvider) { _, provider in
                            applyProviderPreset(provider)
                        }
                    }

                    Divider().opacity(0.3)

                    // Base URL 通栏输入
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API 接口网关 (Base URL)")
                            .font(.system(size: 12, weight: .medium))
                        TextField("https://api.deepseek.com/v1", text: $aiBaseURL)
                            .textFieldStyle(.roundedBorder)
                    }

                    // API Key 通栏安全输入 (Keychain 加密保护)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("API 访问密钥 (API Key)")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "key.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            Text("macOS Keychain 硬件级保护")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(showApiKey ? "隐藏密钥" : "显示密钥") {
                                showApiKey.toggle()
                            }
                            .font(.system(size: 10.5))
                            .buttonStyle(.plain)
                            .foregroundColor(themeMgr.currentTheme.accentColor)
                        }

                        if showApiKey {
                            TextEditor(text: $aiApiKey)
                                .font(.system(size: 11.5, design: .monospaced))
                                .frame(height: 52)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.12), lineWidth: 1))
                        } else {
                            SecureField("sk-xxxxxxxxxxxxxxxxxxxxxxxx", text: $aiApiKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        Text("支持多 Key 轮询（以换行或逗号分隔），密钥已由系统钥匙串隔离，绝不随配置文件明文落盘。")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    // Model Name 通栏输入
                    VStack(alignment: .leading, spacing: 4) {
                        Text("指定推理模型名称 (Model)")
                            .font(.system(size: 12, weight: .medium))
                        TextField("deepseek-chat", text: $aiModel)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider().opacity(0.3)

                    // 连通性测试与多密钥轮询
                    HStack {
                        Toggle("启用多 Key 故障转移轮询", isOn: $enableKeyRotation)
                            .font(.system(size: 11.5))

                        Spacer()

                        Button(action: {
                            testAIConnection()
                        }) {
                            HStack(spacing: 4) {
                                if isTestingConnection {
                                    ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                                    Text("测试连接中...")
                                } else {
                                    Image(systemName: "network")
                                    Text("测试连通性")
                                }
                            }
                            .font(.system(size: 11, weight: .medium))
                        }
                        .controlSize(.regular)
                        .disabled(isTestingConnection || parsedKeys.isEmpty)
                    }

                    if let result = testResultText {
                        HStack(spacing: 4) {
                            Image(systemName: isTestSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(isTestSuccess ? .green : .orange)
                            Text(result)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(isTestSuccess ? .green : .orange)
                        }
                        .padding(6)
                        .background(isTestSuccess ? Color.green.opacity(0.08) : Color.orange.opacity(0.08))
                        .cornerRadius(5)
                    }
                }
            }
        }
    }

    // MARK: - Tab 2: 隐私与忽略黑名单
    private var privacyTabContent: some View {
        VStack(spacing: 14) {
            cardContainer(title: "隐私保护安全承诺", badge: "本地计算 · 零截图上云") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundColor(themeMgr.currentTheme.accentColor)
                        Text("视窗快照与 OCR 均在 Apple 神经引擎离线计算，图像文件绝不上传云端。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundColor(themeMgr.currentTheme.accentColor)
                        Text("系统密码管理器、安全鉴权弹窗以及锁屏已被底层永久阻断，绝不嗅探。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundColor(themeMgr.currentTheme.accentColor)
                        Text("向云端提炼发送前，系统已自动对 API Key、Token 和密码等敏感凭据执行正则脱敏。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }

            cardContainer(title: "已忽略的应用黑名单 (不记录、不挂起、不截图)", badge: "\(ignoredApps.count) 个已拦截") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField("输入应用名称或 BundleId (如 1Password, Telegram)", text: $newIgnoredAppName)
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

    // MARK: - Tab 3: 数字编年史与 GitHub 归档 (彻底修复排版，绝不反人类)
    private var lifelogTabContent: some View {
        VStack(spacing: 14) {
            cardContainer(title: "GitHub 私有编年史同步", badge: enableGitHubSync ? "自动同步中" : "未开启") {
                VStack(alignment: .leading, spacing: 12) {
                    // 1. 自动同步 Switch 开关行
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("启用 GitHub 私有归档自动同步")
                                .font(.system(size: 12.5, weight: .medium))
                            Text("开启后将本地每日工作记录与数据库静默归档至您的 GitHub 私有仓库")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $enableGitHubSync)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Divider().opacity(0.3)

                    // 2. 仓库输入框 (通栏布局，彻底杜绝文字散开与错位)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("GitHub 仓库地址")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text("格式：用户名/仓库名 (如 yourname/my-lifelog)")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }

                        TextField("yourname/my-lifelog 或 git@github.com:yourname/my-lifelog.git", text: $gitHubRepo)
                            .textFieldStyle(.roundedBorder)
                            .disabled(!enableGitHubSync)

                        Text("推荐在 GitHub 上创建 Private（私有）仓库，并将本机 SSH Key 或 PAT 添加至账户，实现每日静默无感备份。")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }

                    Divider().opacity(0.3)

                    // 3. 周期选择行 (左侧说明，右侧菜单)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("自动提交同步周期")
                                .font(.system(size: 12, weight: .medium))
                            Text("后台静默提交与推送到远端仓库的时间间隔")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $syncIntervalHours) {
                            Text("每 1 小时自动提交").tag(1)
                            Text("每 2 小时自动提交 (推荐)").tag(2)
                            Text("每 4 小时自动提交").tag(4)
                        }
                        .labelsHidden()
                        .frame(width: 180)
                        .disabled(!enableGitHubSync)
                    }

                    Divider().opacity(0.3)

                    // 4. 测试与同步操作行
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("手动验证与推送")
                                .font(.system(size: 12, weight: .medium))
                            if let msg = lifelog.syncMessage {
                                Text(msg)
                                    .font(.system(size: 10.5))
                                    .foregroundColor(lifelog.isSyncing ? .blue : .secondary)
                            } else {
                                Text("立即触发一次本地 Markdown 导出与 Git 远端推送测试")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Button(action: {
                            saveAllSettings()
                            lifelog.triggerSync(isManual: true)
                        }) {
                            if lifelog.isSyncing {
                                HStack(spacing: 4) {
                                    ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                                    Text("同步中...")
                                }
                            } else {
                                Text("立即测试推送")
                            }
                        }
                        .controlSize(.regular)
                        .disabled(!enableGitHubSync || gitHubRepo.isEmpty || lifelog.isSyncing)
                    }
                }
            }

            // 本地目录卡片
            cardContainer(title: "本地工作编年史目录", badge: nil) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("本地存储绝对路径")
                            .font(.system(size: 12, weight: .medium))
                        Text("~/.contextflow/lifelog-repo")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

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

    // MARK: - Tab 4: 外观与个性主题
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
                    Text("选择适合您工作习惯的主题风格。切换立即生效于全景工作台与状态栏窗口。")
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
                            Text("屏幕录制权限 (Screen Recording)")
                                .font(.system(size: 12, weight: .medium))
                            Text("用于离开瞬间的单窗口微缩快照与离线大字视觉提炼，永不上云")
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

            cardContainer(title: "感知捕获行为偏好", badge: nil) {
                VStack(spacing: 12) {
                    // 屏幕快照开关
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("视窗微缩快照与本地视觉 OCR")
                                .font(.system(size: 12, weight: .medium))
                            Text("关闭后彻底禁用任何屏幕快照与 Vision OCR，仅通过纯文本轨迹记录现场")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $enableThumbnails)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Divider().opacity(0.3)

                    // 瞬态应用过滤阈值
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("瞬态应用过滤宽限期")
                                .font(.system(size: 12, weight: .medium))
                            Text("切入微信、飞书、音乐等应用小于设定秒数时不打断当前主工作现场")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            Slider(value: $transientThreshold, in: 10...90, step: 5)
                                .frame(width: 120)
                            Text("\(Int(transientThreshold)) 秒")
                                .font(.system(size: 11, design: .monospaced))
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
            }

            cardContainer(title: "数据与维护管理", badge: nil) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("清空本地全部历史现场与缓存")
                            .font(.system(size: 12, weight: .medium))
                        Text("抹除 SQLite 中的所有历史记录与截图缩略图，配置保留")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("清空全部数据") {
                        DatabaseManager.shared.clearAllData()
                        engine.completedSessions.removeAll()
                        engine.suspendedSessions.removeAll()
                        engine.activeSession = nil
                        engine.persistState()
                    }
                    .controlSize(.regular)
                }
            }
        }
    }

    // MARK: - 辅助卡片容器 (标准现代 macOS 卡片样式)
    private func cardContainer<Content: View>(
        title: String,
        badge: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                if let b = badge {
                    Text(b)
                        .font(.system(size: 10))
                        .foregroundColor(themeMgr.currentTheme.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(themeMgr.currentTheme.accentColor.opacity(0.12))
                        .cornerRadius(5)
                }
            }

            Divider().opacity(0.25)

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
        lifelog.restartAutoSyncTimer()
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
        case "deepseek":
            aiBaseURL = "https://api.deepseek.com/v1"
            aiModel = "deepseek-chat"
        case "agnes":
            aiBaseURL = "https://api.agnes-ai.cn/v1"
            aiModel = "agnes-3.0-flash"
        case "zhipu":
            aiBaseURL = "https://open.bigmodel.cn/api/paas/v4"
            aiModel = "glm-4-flash"
        case "openai":
            aiBaseURL = "https://api.openai.com/v1"
            aiModel = "gpt-4o-mini"
        case "qwen":
            aiBaseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
            aiModel = "qwen-plus"
        case "kimi":
            aiBaseURL = "https://api.moonshot.cn/v1"
            aiModel = "moonshot-v1-8k"
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

    private func triggerScanLocalModels() {
        isScanningLocalModels = true
        adoptSuccessText = nil

        ModelPluginHarness.shared.scanAll { report in
            DispatchQueue.main.async {
                self.isScanningLocalModels = false
                self.detectionReport = report
            }
        }
    }

    private func pluginColor(for cat: ModelPluginCategory) -> Color {
        switch cat {
        case .localRuntime: return .purple
        case .ideSoftware: return .blue
        case .cloudProvider: return .green
        }
    }

    private func pluginIcon(for cat: ModelPluginCategory) -> String {
        switch cat {
        case .localRuntime: return "cpu"
        case .ideSoftware: return "chevron.left.forwardslash.chevron.right"
        case .cloudProvider: return "cloud.fill"
        }
    }

    private func adoptDiscoveredPlugin(_ plugin: ModelServicePlugin) {
        self.selectedProvider = plugin.provider
        self.aiBaseURL = plugin.baseURL
        if let first = plugin.models.first {
            self.aiModel = first
        }
        if let k = plugin.detectedKey, !k.isEmpty && !k.contains("-local") && k != "ollama" {
            if self.aiApiKey.isEmpty {
                self.aiApiKey = k
            } else if !self.aiApiKey.contains(k) {
                self.aiApiKey += "\n" + k
            }
        }
        saveAllSettings()
        withAnimation {
            adoptSuccessText = "已成功装配 [\(plugin.name)]，配置已即时生效并写入设置！"
        }
    }
}
