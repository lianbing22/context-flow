import SwiftUI
import Cocoa

@MainActor
public final class DashboardWindowController: NSObject {
    public static let shared = DashboardWindowController()

    private var window: NSWindow?

    public func showWindow(tab: String? = nil) {
        // 先关闭菜单栏小 Popover，避免双重焦点
        MenuBarManager.shared.closePopover(nil)

        if let w = window {
            w.level = .normal
            w.center()
            w.makeKeyAndOrderFront(nil)
            w.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            if let targetTab = tab {
                NotificationCenter.default.post(name: NSNotification.Name("ContextFlow.SwitchDashboardTab"), object: targetTab)
            }
            return
        }

        let dashboardView = DashboardView(initialTab: tab ?? "timeline")
        let hostingController = NSHostingController(rootView: dashboardView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.center()
        newWindow.title = "全局记忆精灵 · 全景工作台"
        newWindow.titleVisibility = .hidden
        newWindow.titlebarAppearsTransparent = true
        newWindow.contentViewController = hostingController
        newWindow.isReleasedWhenClosed = false
        newWindow.minSize = NSSize(width: 960, height: 600)

        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    public func closeWindow() {
        window?.close()
    }
}

// MARK: - 记忆对话实体
struct MemoryChatMessage: Identifiable, Equatable {
    let id = UUID()
    let isUser: Bool
    let text: String
    let timestamp: Date
    var relatedSessions: [ContextSession] = []

    static func == (lhs: MemoryChatMessage, rhs: MemoryChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

public struct DashboardView: View {
    @ObservedObject var engine = ContextEngine.shared
    @ObservedObject var lifelog = LifeLogSyncManager.shared
    @ObservedObject var themeMgr = ThemeManager.shared

    @State private var selectedTab: String = "timeline" // timeline, chat, daily, weekly, suspended
    @State private var searchText: String = ""
    @State private var selectedCategory: ContextEngine.FilterCategory = .all
    @State private var selectedSessionId: UUID? = nil

    // 对话搜索状态
    @State private var chatInputText: String = ""
    @State private var isAskingAI: Bool = false
    @State private var chatMessages: [MemoryChatMessage] = []

    // 日报 / 周报状态
    @State private var dailyWrapUp: DailyWrapUp? = nil
    @State private var weeklyWrapUp: WeeklyWrapUp? = nil
    @State private var isGeneratingDaily: Bool = false
    @State private var isGeneratingWeekly: Bool = false
    @State private var copyToastText: String? = nil

    public init(initialTab: String = "timeline") {
        _selectedTab = State(initialValue: initialTab)
    }

    public var body: some View {
        HStack(spacing: 0) {
            // MARK: - 1. 左侧侧边栏 (Sidebar: 宽敞呼吸感，安全避让系统红黄绿控制按钮，绝不截断)
            sidebarView
                .frame(width: 248)
                .layoutPriority(2)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.92))

            Divider().opacity(0.35)

            // MARK: - 2. 主内容工作区 (根据 Tab 路由分流)
            mainContentRouter
                .frame(minWidth: 500, maxWidth: .infinity)
                .background(VisualEffectView(material: .contentBackground, blendingMode: .behindWindow))

            // MARK: - 3. 右侧详情检查器 (仅在时间轴和挂起看板中展现)
            if (selectedTab == "timeline" || selectedTab == "suspended"), let selected = currentSelectedSession {
                Divider().opacity(0.35)
                inspectorView(session: selected)
                    .frame(width: 280)
                    .layoutPriority(1)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
                    .transition(.move(edge: .trailing))
            }
        }
        .frame(minWidth: 980, minHeight: 620)
        .overlay(alignment: .top) {
            if let toast = copyToastText {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(toast)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .padding(.top, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            loadInitialData()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ContextFlow.SwitchDashboardTab"))) { notif in
            if let tab = notif.object as? String {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.selectedTab = tab
                }
                if tab == "daily" && dailyWrapUp == nil { loadDailyReport() }
                if tab == "weekly" && weeklyWrapUp == nil { loadWeeklyReport() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ContextFlow.AskQuestion"))) { notif in
            if let q = notif.object as? String {
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.selectedTab = "chat"
                }
                self.sendChatMessage(q)
            }
        }
    }

    // MARK: - 数据加载与初始化
    private func loadInitialData() {
        if chatMessages.isEmpty {
            chatMessages.append(MemoryChatMessage(
                isUser: false,
                text: "您好！我是全局记忆助手。我可以根据您在 macOS 上的真实窗口轨迹、代码修改、文档及浏览器痕迹回答您的问题。试着问问我今天的工作进展吧！",
                timestamp: Date()
            ))
        }
        if selectedTab == "daily" { loadDailyReport() }
        if selectedTab == "weekly" { loadWeeklyReport() }
    }

    private func showToast(_ text: String) {
        withAnimation(.spring()) {
            copyToastText = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut) {
                copyToastText = nil
            }
        }
    }

    // MARK: - 主内容路由器
    @ViewBuilder
    private var mainContentRouter: some View {
        switch selectedTab {
        case "chat":
            chatMemoryWorkspace
        case "daily":
            dailyReportWorkspace
        case "weekly":
            weeklyReportWorkspace
        default:
            timelineWorkspace
        }
    }

    // MARK: - 1. 左侧侧边栏 (Sidebar)
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // App 品牌区域 (留出顶部 34pt 避让红黄绿窗口按钮，左侧留足安全呼吸区)
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(themeMgr.currentTheme.accentColor.opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(themeMgr.currentTheme.accentColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("全局记忆精灵")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text("全景工作台 · v2.1")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.leading, 20)
            .padding(.trailing, 14)
            .padding(.top, 34) // 关键：避开红黄绿交通灯高度

            // 今日专注统计看板小卡片
            VStack(alignment: .leading, spacing: 6) {
                Text("今日专注概览")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(totalFocusMinutes)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("专注分钟")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }

                    Divider().frame(height: 24)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(allSessions.count)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(themeMgr.currentTheme.accentColor)
                        Text("攻坚现场")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
            .cornerRadius(8)
            .padding(.leading, 18)
            .padding(.trailing, 14)

            // 核心功能一级导航栏 (时间轴、对话搜索、日报、周报、挂起)
            VStack(spacing: 3) {
                sidebarNavItem(
                    id: "timeline",
                    title: "全景时间轴",
                    icon: "clock.arrow.circlepath",
                    count: allSessions.count
                )
                sidebarNavItem(
                    id: "chat",
                    title: "AI 记忆对话",
                    icon: "bubble.left.and.bubble.right.fill",
                    count: nil,
                    badge: "推荐"
                )
                sidebarNavItem(
                    id: "daily",
                    title: "今日日报",
                    icon: "sun.max.fill",
                    count: nil
                )
                sidebarNavItem(
                    id: "weekly",
                    title: "本周周报",
                    icon: "calendar.badge.clock",
                    count: nil
                )
                sidebarNavItem(
                    id: "suspended",
                    title: "挂起看板",
                    icon: "bolt.badge.clock.fill",
                    count: engine.suspendedSessions.count
                )
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)

            Spacer()

            // 底部快捷工具条：5套主题一键切换与偏好设置
            VStack(alignment: .leading, spacing: 10) {
                // 主题快速切换器 (直观单选圆环)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("外观主题")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(themeMgr.currentTheme.displayName)
                            .font(.system(size: 9.5))
                            .foregroundColor(themeMgr.currentTheme.accentColor)
                    }

                    HStack(spacing: 6) {
                        ForEach(AppTheme.allCases) { th in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    themeMgr.applyTheme(th)
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(th.previewColors.first ?? Color.gray)
                                        .frame(width: 18, height: 18)

                                    if themeMgr.currentTheme == th {
                                        Circle()
                                            .stroke(Color.primary, lineWidth: 1.5)
                                            .frame(width: 22, height: 22)
                                    }
                                }
                                .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                            .help(th.displayName)
                        }
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                .cornerRadius(7)

                // 偏好设置按钮
                Button(action: {
                    SettingsWindowController.shared.showWindow()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11))
                        Text("偏好设置 (AI/模型/同步)")
                            .font(.system(size: 11))
                        Spacer()
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 18)
            .padding(.trailing, 14)
            .padding(.bottom, 16)
        }
    }

    private func sidebarNavItem(id: String, title: String, icon: String, count: Int? = nil, badge: String? = nil) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = id
            }
            if id == "daily" && dailyWrapUp == nil { loadDailyReport() }
            if id == "weekly" && weeklyWrapUp == nil { loadWeeklyReport() }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(selectedTab == id ? themeMgr.currentTheme.accentColor : .secondary)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 12, weight: selectedTab == id ? .semibold : .regular))
                    .foregroundColor(selectedTab == id ? .primary : .secondary)

                Spacer()

                if let b = badge {
                    Text(b)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(themeMgr.currentTheme.accentColor.opacity(0.18))
                        .foregroundColor(themeMgr.currentTheme.accentColor)
                        .cornerRadius(4)
                } else if let c = count, c > 0 {
                    Text("\(c)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(selectedTab == id ? themeMgr.currentTheme.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
                        .foregroundColor(selectedTab == id ? themeMgr.currentTheme.accentColor : .secondary)
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selectedTab == id ? Color.primary.opacity(0.06) : Color.clear)
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. 全景时间轴工作区 (Timeline Workspace)
    private var timelineWorkspace: some View {
        VStack(spacing: 0) {
            topToolbarView
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.35))

            Divider().opacity(0.35)

            ScrollView(.vertical, showsIndicators: true) {
                if displaySessions.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.4))
                            .padding(.top, 40)
                        Text(searchText.isEmpty ? "当前分类暂无记录" : "未搜索到匹配的记忆或现场")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 14)], spacing: 14) {
                        ForEach(displaySessions) { session in
                            DashboardSessionCard(
                                session: session,
                                isSelected: (selectedSessionId == session.id) || (selectedSessionId == nil && displaySessions.first?.id == session.id),
                                onSelect: {
                                    selectedSessionId = session.id
                                },
                                onRestore: {
                                    engine.restoreSession(id: session.id)
                                },
                                onComplete: {
                                    engine.completeSession(id: session.id)
                                }
                            )
                        }
                    }
                    .padding(18)
                }
            }
        }
    }

    // 顶部工具栏与多维 Chips (流式自适应横向排版，永不截断)
    private var topToolbarView: some View {
        HStack(spacing: 8) {
            // 全局搜索输入框 (支持回车切换至 AI 问答)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11.5))
                    .foregroundColor(themeMgr.currentTheme.accentColor)

                TextField("搜索记忆、业务实体或输入问题按回车问 AI...", text: $searchText, onCommit: {
                    if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                        chatInputText = searchText
                        withAnimation { selectedTab = "chat" }
                        sendChatMessage(searchText)
                    }
                })
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        chatInputText = searchText
                        withAnimation { selectedTab = "chat" }
                        sendChatMessage(searchText)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9))
                            Text("问记忆")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(themeMgr.currentTheme.accentColor.opacity(0.15))
                        .foregroundColor(themeMgr.currentTheme.accentColor)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .frame(minWidth: 200, maxWidth: 320)

            // 多维分类过滤 Chips: 横向自适应滚动容器，确保任何分辨率完整展现
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(ContextEngine.FilterCategory.allCases) { cat in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedCategory = cat
                            }
                        }) {
                            HStack(spacing: 3) {
                                Text(cat.iconOnly)
                                    .font(.system(size: 10))
                                Text(cat.nameOnly)
                                    .font(.system(size: 11, weight: selectedCategory == cat ? .semibold : .regular))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(selectedCategory == cat ? themeMgr.currentTheme.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
                            .foregroundColor(selectedCategory == cat ? themeMgr.currentTheme.accentColor : .secondary)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }

            Spacer(minLength: 4)

            // 收起至菜单栏
            Button(action: {
                DashboardWindowController.shared.closeWindow()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 9.5))
                    Text("收起")
                        .font(.system(size: 10.5))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("收起并常驻菜单栏")
        }
    }

    // MARK: - 3. AI 记忆对话专页 (Chat Memory Workspace)
    private var chatMemoryWorkspace: some View {
        VStack(spacing: 0) {
            // 对话头部工具栏
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundColor(themeMgr.currentTheme.accentColor)
                    Text("AI 全局记忆对话搜索")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                Button("清空对话") {
                    chatMessages.removeAll()
                    loadInitialData()
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.35))

            Divider().opacity(0.35)

            // 对话消息列表
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(chatMessages) { msg in
                            chatMessageBubble(msg)
                                .id(msg.id)
                        }

                        if isAskingAI {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                                Text("AI 正在穿透检索全局足迹与视觉实体...")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                            .cornerRadius(8)
                            .id("LOADING_INDICATOR")
                        }
                    }
                    .padding(20)
                }
                .onChange(of: chatMessages.count) { _ in
                    if let last = chatMessages.last?.id {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }

            Divider().opacity(0.35)

            // 快捷问题建议 Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chatSuggestionChip("✨ 总结今天在各个应用的花费时间")
                    chatSuggestionChip("✨ 今天推进了哪些核心项目？")
                    chatSuggestionChip("✨ 微信开发者工具中改了什么？")
                    chatSuggestionChip("✨ 有哪些挂起未完成的任务？")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.2))

            // 底部输入框
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundColor(themeMgr.currentTheme.accentColor)

                TextField("问问你的全局记忆（例如：今天在微信开发者工具做了什么？）...", text: $chatInputText, onCommit: {
                    sendChatMessage(chatInputText)
                })
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))

                Button(action: {
                    sendChatMessage(chatInputText)
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(chatInputText.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary.opacity(0.4) : themeMgr.currentTheme.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(chatInputText.trimmingCharacters(in: .whitespaces).isEmpty || isAskingAI)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(themeMgr.currentTheme.accentColor.opacity(0.25), lineWidth: 1)
            )
            .padding(16)
        }
    }

    private func chatSuggestionChip(_ text: String) -> some View {
        Button(action: {
            chatInputText = text
            sendChatMessage(text)
        }) {
            Text(text)
                .font(.system(size: 11))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05))
                .foregroundColor(.secondary)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func chatMessageBubble(_ msg: MemoryChatMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if msg.isUser {
                Spacer()
                Text(msg.text)
                    .font(.system(size: 12.5))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(themeMgr.currentTheme.accentColor)
                    .cornerRadius(10)
            } else {
                ZStack {
                    Circle()
                        .fill(themeMgr.currentTheme.accentColor.opacity(0.18))
                        .frame(width: 24, height: 24)
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(themeMgr.currentTheme.accentColor)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(msg.text)
                        .font(.system(size: 12.5))
                        .lineSpacing(4)
                        .foregroundColor(.primary)

                    if !msg.relatedSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("关联业务现场：")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)

                            ForEach(msg.relatedSessions.prefix(3)) { s in
                                HStack(spacing: 6) {
                                    Image(nsImage: AppIconManager.shared.icon(for: s.primaryApp))
                                        .resizable()
                                        .frame(width: 14, height: 14)
                                    Text("[\(s.primaryApp)] \(s.title)")
                                        .font(.system(size: 11))
                                        .lineLimit(1)
                                    Spacer()
                                    Button("恢复") {
                                        engine.restoreSession(id: s.id)
                                    }
                                    .font(.system(size: 10))
                                    .foregroundColor(themeMgr.currentTheme.accentColor)
                                    .buttonStyle(.plain)
                                }
                                .padding(5)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(4)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                )

                Spacer()
            }
        }
    }

    private func sendChatMessage(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty && !isAskingAI else { return }

        chatInputText = ""
        chatMessages.append(MemoryChatMessage(isUser: true, text: clean, timestamp: Date()))
        isAskingAI = true

        engine.askMemory(query: clean) { reply in
            let related = self.engine.searchSessions(query: clean, category: .all, status: .all, timeRange: .all)
            self.chatMessages.append(MemoryChatMessage(
                isUser: false,
                text: reply,
                timestamp: Date(),
                relatedSessions: related
            ))
            self.isAskingAI = false
        }
    }

    // MARK: - 4. 今日全景日报大屏页面 (Daily Report Workspace)
    private var dailyReportWorkspace: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 18) {
                // 顶部 Hero 统计栏
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "sun.max.fill")
                                .foregroundColor(themeMgr.currentTheme.accentColor)
                            Text("☀️ 今日全景复盘与工作日报")
                                .font(.system(size: 16, weight: .bold))
                        }
                        Text("基于 Apple Neural Engine 端侧离线提炼 · 拒绝套话直击业务")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        if let briefing = dailyWrapUp {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(briefing.markdown, forType: .string)
                            showToast("已复制今日日报 Markdown")
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("复制日报 Markdown")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(themeMgr.currentTheme.accentColor.opacity(0.12))
                        .foregroundColor(themeMgr.currentTheme.accentColor)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Button(action: { loadDailyReport() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .padding(6)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("重新提炼今日复盘")
                }
                .padding(.bottom, 4)

                if isGeneratingDaily {
                    HStack(spacing: 10) {
                        ProgressView().scaleEffect(0.7)
                        Text("正在生成今日工作全景复盘...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(30)
                    .frame(maxWidth: .infinity)
                } else if let wrapUp = dailyWrapUp {
                    // 指标卡片
                    HStack(spacing: 14) {
                        statBadge(title: "今日专注时长", value: "\(wrapUp.totalFocusMinutes) 分钟", icon: "clock.fill")
                        statBadge(title: "攻坚现场总数", value: "\(wrapUp.sessionCount) 个", icon: "bolt.fill")
                        statBadge(title: "涉及核心项目", value: "\(wrapUp.keyProjects.count) 个", icon: "target")
                    }

                    // 核心综述
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🎯 核心攻坚综述与业务突破")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundColor(.primary)

                        Text(wrapUp.summary)
                            .font(.system(size: 12.5))
                            .lineSpacing(5)
                            .foregroundColor(.primary.opacity(0.9))
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                    }

                    // 攻坚项目标签
                    if !wrapUp.keyProjects.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("🚀 攻坚项目实体")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                ForEach(wrapUp.keyProjects, id: \.self) { p in
                                    Text(p)
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(themeMgr.currentTheme.badgeBackground)
                                        .foregroundColor(themeMgr.currentTheme.accentColor)
                                        .cornerRadius(5)
                                }
                            }
                        }
                    }

                    // 明日建议
                    if !wrapUp.suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("⏳ 明日重点跟进与规划")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(wrapUp.suggestions, id: \.self) { sug in
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle")
                                            .font(.system(size: 10.5))
                                            .foregroundColor(themeMgr.currentTheme.accentColor)
                                        Text(sug)
                                            .font(.system(size: 11.5))
                                    }
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                            .cornerRadius(8)
                        }
                    }
                } else {
                    Text("暂无今日足迹记录，随工作展开将自动聚合。")
                        .foregroundColor(.secondary)
                        .padding(20)
                }
            }
            .padding(24)
        }
    }

    private func loadDailyReport() {
        isGeneratingDaily = true
        engine.generateTodayWrapUp { wrap in
            Task { @MainActor in
                self.dailyWrapUp = wrap
                self.isGeneratingDaily = false
            }
        }
    }

    // MARK: - 5. 本周深度工作周报大屏页面 (Weekly Report Workspace)
    private var weeklyReportWorkspace: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 18) {
                // 顶部 Hero 统计栏
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(themeMgr.currentTheme.accentColor)
                            Text("📅 本周工作周报与项目投入深度分析")
                                .font(.system(size: 16, weight: .bold))
                        }
                        Text(weeklyWrapUp?.weekRange ?? "跨 7 天工作轨迹聚合 · 包含项目研发投入占比与每日脉络")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        if let wrap = weeklyWrapUp {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(wrap.markdown, forType: .string)
                            showToast("已复制本周周报 Markdown")
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("复制周报 Markdown")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(themeMgr.currentTheme.accentColor.opacity(0.12))
                        .foregroundColor(themeMgr.currentTheme.accentColor)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Button(action: { loadWeeklyReport() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .padding(6)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("重新提炼本周周报")
                }
                .padding(.bottom, 4)

                if isGeneratingWeekly {
                    HStack(spacing: 10) {
                        ProgressView().scaleEffect(0.7)
                        Text("正在聚合跨 7 天历史并计算项目投入占比...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(30)
                    .frame(maxWidth: .infinity)
                } else if let wrap = weeklyWrapUp {
                    // 指标卡片
                    HStack(spacing: 14) {
                        statBadge(title: "本周累计专注", value: "\(wrap.totalFocusMinutes) 分钟 (\(String(format: "%.1f", Double(wrap.totalFocusMinutes)/60.0))h)", icon: "clock.badge.checkmark")
                        statBadge(title: "处理攻坚现场", value: "\(wrap.totalSessionCount) 个", icon: "square.grid.3x3.fill")
                        statBadge(title: "主攻项目数", value: "\(wrap.projectDistribution.count) 个", icon: "folder.fill")
                    }

                    // 核心突破综述
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🌟 本周核心攻坚突破综述")
                            .font(.system(size: 12.5, weight: .bold))
                        Text(wrap.summary)
                            .font(.system(size: 12.5))
                            .lineSpacing(5)
                            .foregroundColor(.primary.opacity(0.9))
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                    }

                    // 核心杀手级特性：项目时间投入占比进度条
                    VStack(alignment: .leading, spacing: 8) {
                        Text("📊 项目研发时间投入占比分布")
                            .font(.system(size: 12.5, weight: .bold))

                        VStack(spacing: 10) {
                            ForEach(wrap.projectDistribution) { p in
                                VStack(spacing: 4) {
                                    HStack {
                                        Text(p.projectName)
                                            .font(.system(size: 11.5, weight: .semibold))
                                        Text("(\(p.primaryApp))")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)

                                        Spacer()

                                        Text("\(p.focusMinutes) 分钟")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.secondary)
                                        Text("\(p.percentage)%")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(themeMgr.currentTheme.accentColor)
                                            .frame(width: 36, alignment: .trailing)
                                    }

                                    // 可视化占比进度条
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.primary.opacity(0.06))
                                                .frame(height: 6)

                                            Capsule()
                                                .fill(themeMgr.currentTheme.accentColor)
                                                .frame(width: max(8, geo.size.width * CGFloat(p.percentage) / 100.0), height: 6)
                                        }
                                    }
                                    .frame(height: 6)
                                }
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                                .cornerRadius(6)
                            }
                        }
                    }

                    // 每日脉络追踪
                    if !wrap.dailyBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🗓 每日推进脉络")
                                .font(.system(size: 12.5, weight: .bold))

                            VStack(spacing: 6) {
                                ForEach(wrap.dailyBreakdown) { d in
                                    HStack(spacing: 12) {
                                        HStack(spacing: 4) {
                                            Text(d.dayOfWeek)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(themeMgr.currentTheme.accentColor)
                                            Text(d.date)
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(width: 100, alignment: .leading)

                                        Text(d.highlight)
                                            .font(.system(size: 11))
                                            .lineLimit(1)

                                        Spacer()

                                        Text("\(d.focusMinutes) 分钟")
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                                    .cornerRadius(5)
                                }
                            }
                        }
                    }

                    // 下周重点规划
                    if !wrap.nextWeekPlans.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("🎯 下周重点推进规划")
                                .font(.system(size: 12.5, weight: .bold))

                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(wrap.nextWeekPlans, id: \.self) { plan in
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .font(.system(size: 10.5))
                                            .foregroundColor(themeMgr.currentTheme.accentColor)
                                        Text(plan)
                                            .font(.system(size: 11.5))
                                    }
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                            .cornerRadius(8)
                        }
                    }
                } else {
                    Text("暂无本周历史记录。")
                        .foregroundColor(.secondary)
                        .padding(20)
                }
            }
            .padding(24)
        }
    }

    private func loadWeeklyReport() {
        isGeneratingWeekly = true
        engine.generateThisWeekWrapUp { wrap in
            Task { @MainActor in
                self.weeklyWrapUp = wrap
                self.isGeneratingWeekly = false
            }
        }
    }

    private func statBadge(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(themeMgr.currentTheme.accentColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(themeMgr.currentTheme.accentColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - Computed Properties
    private var allSessions: [ContextSession] {
        var statusFilter: ContextEngine.FilterStatus = .all
        if selectedTab == "suspended" {
            statusFilter = .suspended
        }

        return engine.searchSessions(
            query: searchText,
            category: selectedCategory,
            status: statusFilter,
            timeRange: .all
        )
    }

    private var currentSelectedSession: ContextSession? {
        if let id = selectedSessionId {
            return allSessions.first(where: { $0.id == id })
        }
        return allSessions.first
    }

    private var displaySessions: [ContextSession] {
        let cleanQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseList: [ContextSession]
        if !cleanQuery.isEmpty {
            baseList = ContextStore.shared.search(query: cleanQuery)
        } else {
            baseList = allSessions
        }

        if selectedCategory == .all {
            return baseList
        } else {
            return baseList.filter { selectedCategory.matches(appName: $0.primaryApp) }
        }
    }

    private var totalFocusMinutes: Int {
        let totalSecs = allSessions.reduce(0) { $0 + $1.totalActiveSeconds }
        return max(1, totalSecs / 60)
    }

    // MARK: - 右侧详情检查器 (Inspector)
    private func inspectorView(session: ContextSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(nsImage: AppIconManager.shared.icon(for: session.primaryApp))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 1) {
                    Text(session.primaryApp)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                    Text(session.totalActiveDescription)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.top, 14)
            .padding(.horizontal, 14)

            Divider().opacity(0.35)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // 业务实体主标题
                    VStack(alignment: .leading, spacing: 3) {
                        Text("业务现场实体")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(session.title)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.primary)
                    }

                    // 视窗微缩图
                    if let thumb = session.thumbnailPath,
                       FileManager.default.fileExists(atPath: thumb),
                       let img = NSImage(contentsOfFile: thumb) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("离开瞬间快照")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)

                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                                )
                                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                        }
                    }

                    // 下一步行动
                    if let sug = session.suggestion, !sug.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("下一步行动指引")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)

                            HStack(spacing: 5) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(themeMgr.currentTheme.accentColor)
                                Text(sug)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(themeMgr.currentTheme.accentColor)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(themeMgr.currentTheme.accentColor.opacity(0.08))
                            .cornerRadius(6)
                        }
                    }

                    // 关联窗口与文档轨迹
                    VStack(alignment: .leading, spacing: 6) {
                        Text("关联窗口与视窗 (\(session.items.count))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        ForEach(session.items) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.windowTitle)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .lineLimit(2)

                                if let u = item.url {
                                    Text(u)
                                        .font(.system(size: 9))
                                        .foregroundColor(.blue)
                                        .lineLimit(1)
                                }

                                if let txt = item.extractedText {
                                    Text(txt)
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                            .cornerRadius(5)
                        }
                    }
                }
                .padding(.horizontal, 14)
            }

            Spacer()

            // 底部一键恢复按钮 (确保文字完全展现，不被挤压)
            Button(action: {
                engine.restoreSession(id: session.id)
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 12))
                    Text("恢复当时视窗现场")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(themeMgr.currentTheme.accentColor)
                .foregroundColor(.white)
                .cornerRadius(7)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }
}

// MARK: - 全景工作台现场大卡片组件
struct DashboardSessionCard: View {
    let session: ContextSession
    let isSelected: Bool
    let onSelect: () -> Void
    let onRestore: () -> Void
    let onComplete: () -> Void
    @ObservedObject var themeMgr = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 顶部 App 与时间
            HStack(spacing: 8) {
                Image(nsImage: AppIconManager.shared.icon(for: session.primaryApp))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .cornerRadius(5)

                VStack(alignment: .leading, spacing: 1) {
                    Text(session.primaryApp)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let proj = session.detectedProject {
                        Text(proj)
                            .font(.system(size: 9.5))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(session.suspendedAgoDescription)
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
            }

            // 业务实体主标题
            Text(session.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)

            // 下一步行动胶囊
            if let sug = session.suggestion, !sug.isEmpty {
                Button(action: onRestore) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8))
                            .foregroundColor(themeMgr.currentTheme.accentColor)
                        Text("下一步：\(sug)")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(themeMgr.currentTheme.accentColor)
                            .lineLimit(1)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 7))
                            .foregroundColor(themeMgr.currentTheme.accentColor.opacity(0.8))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(themeMgr.currentTheme.accentColor.opacity(0.08))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }

            // 微缩快照
            if let thumb = session.thumbnailPath,
               FileManager.default.fileExists(atPath: thumb),
               let img = NSImage(contentsOfFile: thumb) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 90)
                    .cornerRadius(5)
                    .clipped()
            }

            // 底部操作
            HStack {
                Text(session.totalActiveDescription)
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)

                Spacer()

                Button("收尾") {
                    onComplete()
                }
                .font(.system(size: 10))
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Button("恢复现场") {
                    onRestore()
                }
                .font(.system(size: 10, weight: .medium))
                .buttonStyle(.plain)
                .foregroundColor(themeMgr.currentTheme.accentColor)
            }
            .padding(.top, 2)
        }
        .padding(11)
        .background(Color(NSColor.controlBackgroundColor).opacity(isSelected ? 0.9 : 0.45))
        .cornerRadius(9)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(isSelected ? themeMgr.currentTheme.accentColor.opacity(0.7) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .shadow(color: .black.opacity(isSelected ? 0.08 : 0.02), radius: 3, y: 1)
    }
}
