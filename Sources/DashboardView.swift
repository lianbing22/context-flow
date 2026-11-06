import SwiftUI
import Cocoa

@MainActor
public final class DashboardWindowController: NSObject {
    public static let shared = DashboardWindowController()

    private var window: NSWindow?

    public func showWindow() {
        // 先关闭菜单栏小 Popover，避免双重焦点
        MenuBarManager.shared.closePopover(nil)

        if let w = window {
            w.level = .normal
            w.center()
            w.makeKeyAndOrderFront(nil)
            w.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let dashboardView = DashboardView()
        let hostingController = NSHostingController(rootView: dashboardView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1020, height: 680),
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
        newWindow.minSize = NSSize(width: 860, height: 560)

        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    public func closeWindow() {
        window?.close()
    }
}

public struct DashboardView: View {
    @ObservedObject var engine = ContextEngine.shared
    @ObservedObject var lifelog = LifeLogSyncManager.shared

    @State private var selectedTab: String = "timeline" // timeline, suspended, projects
    @State private var searchText: String = ""
    @State private var selectedSessionId: UUID? = nil

    // 弹窗状态
    @State private var activeBriefing: DailyWrapUp? = nil
    @State private var showingBriefingSheet: Bool = false
    @State private var isWrapUpGenerating: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // MARK: - 1. 左侧侧边栏 (Sidebar)
                sidebarView
                    .frame(width: 230)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.85))

                Divider().opacity(0.4)

                // MARK: - 2. 主内容工作区 (Content Workspace)
                VStack(spacing: 0) {
                    topToolbarView
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.35))

                    Divider().opacity(0.4)

                    mainContentArea
                }
                .background(VisualEffectView(material: .contentBackground, blendingMode: .behindWindow))

                // MARK: - 3. 右侧详情检查器 (Inspector)
                if let selected = currentSelectedSession {
                    Divider().opacity(0.4)
                    inspectorView(session: selected)
                        .frame(width: 300)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.75))
                        .transition(.move(edge: .trailing))
                }
            }

            // 全景复盘弹窗
            if showingBriefingSheet, let briefing = activeBriefing {
                DailyBriefingModal(briefing: briefing, onClose: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingBriefingSheet = false
                    }
                })
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .frame(minWidth: 860, minHeight: 560)
    }

    // MARK: - Computed Properties

    private var allSessions: [ContextSession] {
        var list: [ContextSession] = []
        if let act = engine.activeSession {
            list.append(act)
        }
        list.append(contentsOf: engine.suspendedSessions)
        list.append(contentsOf: engine.completedSessions)

        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return list
        }

        let q = searchText.lowercased()
        return list.filter { s in
            s.title.lowercased().contains(q) ||
            s.primaryApp.lowercased().contains(q) ||
            (s.aiSummary?.lowercased().contains(q) ?? false) ||
            (s.detectedProject?.lowercased().contains(q) ?? false)
        }
    }

    private var currentSelectedSession: ContextSession? {
        if let id = selectedSessionId {
            return allSessions.first(where: { $0.id == id })
        }
        return allSessions.first
    }

    private var totalFocusMinutes: Int {
        let totalSecs = allSessions.reduce(0) { $0 + $1.totalActiveSeconds }
        return max(1, totalSecs / 60)
    }

    // MARK: - Subviews

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // App 品牌区域
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("全局记忆精灵")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("全景工作台 · v2.0")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            // 今日专注统计看板
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
                            .foregroundColor(.orange)
                        Text("攻坚现场")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .padding(.horizontal, 14)

            // 导航切换
            VStack(spacing: 3) {
                sidebarNavItem(
                    id: "timeline",
                    title: "全景时间轴",
                    icon: "clock.arrow.circlepath",
                    count: allSessions.count
                )
                sidebarNavItem(
                    id: "suspended",
                    title: "挂起看板",
                    icon: "bolt.badge.clock.fill",
                    count: engine.suspendedSessions.count
                )
                sidebarNavItem(
                    id: "completed",
                    title: "已归档足迹",
                    icon: "checkmark.circle.fill",
                    count: engine.completedSessions.count
                )
            }
            .padding(.horizontal, 10)

            Spacer()

            // 底部控制
            VStack(spacing: 8) {
                Button(action: {
                    triggerWrapUp()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text("全景工作复盘")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.orange.opacity(0.12))
                    .foregroundColor(.orange)
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)

                Button(action: {
                    SettingsWindowController.shared.showWindow()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11))
                        Text("偏好设置")
                            .font(.system(size: 12))
                        Spacer()
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
    }

    private func sidebarNavItem(id: String, title: String, icon: String, count: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = id
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(selectedTab == id ? .orange : .secondary)

                Text(title)
                    .font(.system(size: 12, weight: selectedTab == id ? .semibold : .regular))
                    .foregroundColor(selectedTab == id ? .primary : .secondary)

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(selectedTab == id ? Color.orange.opacity(0.15) : Color.primary.opacity(0.06))
                        .foregroundColor(selectedTab == id ? .orange : .secondary)
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

    // 顶部工具栏与搜索
    private var topToolbarView: some View {
        HStack(spacing: 12) {
            // 全局语义搜索
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                TextField("搜索记忆、业务实体、网址或文件...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )

            Spacer()

            // 快捷操作
            Button(action: {
                DashboardWindowController.shared.closeWindow()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 10))
                    Text("收起至菜单栏")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("收起并常驻菜单栏")
        }
    }

    // 主内容工作区
    private var mainContentArea: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 310, maximum: 420), spacing: 14)], spacing: 14) {
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

    private var displaySessions: [ContextSession] {
        switch selectedTab {
        case "suspended":
            return engine.suspendedSessions
        case "completed":
            return engine.completedSessions
        default:
            return allSessions
        }
    }

    // 右侧详情检查器
    private func inspectorView(session: ContextSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(nsImage: AppIconManager.shared.icon(for: session.primaryApp))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.primaryApp)
                        .font(.system(size: 12, weight: .bold))
                    Text(session.totalActiveDescription)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)

            Divider().opacity(0.4)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // 业务实体主标题
                    VStack(alignment: .leading, spacing: 4) {
                        Text("业务现场实体")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(session.title)
                            .font(.system(size: 13, weight: .semibold))
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

                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.orange)
                                Text(sug)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.08))
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
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(2)

                                if let u = item.url {
                                    Text(u)
                                        .font(.system(size: 9.5))
                                        .foregroundColor(.blue)
                                        .lineLimit(1)
                                }

                                if let txt = item.extractedText {
                                    Text(txt)
                                        .font(.system(size: 9.5))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                            .cornerRadius(5)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer()

            // 底部一键恢复
            Button(action: {
                engine.restoreSession(id: session.id)
            }) {
                HStack {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                    Text("恢复当时视窗现场")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(7)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func triggerWrapUp() {
        isWrapUpGenerating = true
        engine.generateTodayWrapUp { wrapUp in
            Task { @MainActor in
                self.isWrapUpGenerating = false
                if let wrapUp = wrapUp {
                    self.activeBriefing = wrapUp
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        self.showingBriefingSheet = true
                    }
                }
            }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 顶部 App 与时间
            HStack(spacing: 8) {
                Image(nsImage: AppIconManager.shared.icon(for: session.primaryApp))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .cornerRadius(5)

                VStack(alignment: .leading, spacing: 1) {
                    Text(session.primaryApp)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)

                    if let proj = session.detectedProject {
                        Text(proj)
                            .font(.system(size: 9.5))
                            .foregroundColor(.blue)
                    }
                }

                Spacer()

                Text(session.suspendedAgoDescription)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // 业务实体主标题
            Text(session.title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)

            // 下一步行动胶囊
            if let sug = session.suggestion, !sug.isEmpty {
                Button(action: onRestore) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                        Text("下一步：\(sug)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 7))
                            .foregroundColor(.orange.opacity(0.8))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.08))
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
                    .frame(height: 100)
                    .cornerRadius(5)
                    .clipped()
            }

            // 底部操作
            HStack {
                Text(session.totalActiveDescription)
                    .font(.system(size: 10))
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
                .foregroundColor(.orange)
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(isSelected ? 0.9 : 0.45))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.orange.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .shadow(color: .black.opacity(isSelected ? 0.08 : 0.02), radius: 4, y: 1)
    }
}
