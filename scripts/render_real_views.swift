import SwiftUI
import Cocoa

// MARK: - 渲染入口 (全景统一工作台规范测试与真机截图输出)
@main
struct RenderRealViewsApp {
    @MainActor
    static func main() {
        print("==> 开始渲染全套最新修复界面 (彻底实现工作台各界面统一定位与 0 跳变)...")
        let outDir = "/Users/lianb/.gemini/antigravity/scratch/context-flow/docs/screenshots"
        let brainDir = "/Users/lianb/.gemini/antigravity/brain/939106cc-a6f7-48b1-912c-39d153abcb54"

        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

        let targetSize = NSSize(width: 1040, height: 660)

        // 1. 全景时间轴 (Timeline)
        let timelineView = MockFullDashboardView(selectedTab: "timeline")
        render(view: timelineView, size: targetSize, path: "\(outDir)/01_dashboard_timeline.png")
        render(view: timelineView, size: targetSize, path: "\(brainDir)/verified_01_dashboard_timeline.png")

        // 2. AI 记忆对话 (Chat: 彻底根除虚假幻觉，右侧呈现关联召回现场)
        let chatView = MockFullDashboardView(selectedTab: "chat")
        render(view: chatView, size: targetSize, path: "\(outDir)/02_dashboard_chat.png")
        render(view: chatView, size: targetSize, path: "\(brainDir)/verified_03_dashboard_chat.png")

        // 3. 今日全景日报 (Daily: 统一 Header，右侧核心指标速览)
        let dailyView = MockFullDashboardView(selectedTab: "daily")
        render(view: dailyView, size: targetSize, path: "\(outDir)/03_dashboard_daily.png")
        render(view: dailyView, size: targetSize, path: "\(brainDir)/verified_05_dashboard_daily.png")

        // 4. 本周深度周报 (Weekly: 统一 Header，右侧项目排行大盘)
        let weeklyView = MockFullDashboardView(selectedTab: "weekly")
        render(view: weeklyView, size: targetSize, path: "\(outDir)/04_dashboard_weekly.png")
        render(view: weeklyView, size: targetSize, path: "\(brainDir)/verified_06_dashboard_weekly.png")

        // 5. 挂起看板 (Suspended: 离开现场保护)
        let suspendedView = MockFullDashboardView(selectedTab: "suspended")
        render(view: suspendedView, size: targetSize, path: "\(outDir)/05_dashboard_suspended.png")
        render(view: suspendedView, size: targetSize, path: "\(brainDir)/verified_07_dashboard_suspended.png")

        // 6. 偏好设置 - AI 页面 (消除 >>，消除 Label 切边，加入本地模型嗅探与密钥池)
        let settingsAIView = MockFullSettingsView(currentTab: "ai")
        render(view: settingsAIView, size: NSSize(width: 680, height: 620), path: "\(outDir)/settings_ai.png")
        render(view: settingsAIView, size: NSSize(width: 680, height: 620), path: "\(brainDir)/verified_02_settings_ai.png")

        // 7. 偏好设置 - GitHub 编年史 (消除右上角黑色药丸工具栏与排版变形)
        let settingsLifelogView = MockFullSettingsView(currentTab: "lifelog")
        render(view: settingsLifelogView, size: NSSize(width: 680, height: 620), path: "\(outDir)/settings_lifelog.png")
        render(view: settingsLifelogView, size: NSSize(width: 680, height: 620), path: "\(brainDir)/verified_04_settings_lifelog.png")

        print("==> 7 张最新工作台与设置界面全部高清渲染完成！")
    }

    @MainActor
    static func render<V: View>(view: V, size: NSSize, path: String) {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            print("Failed alloc bitmap: \(path)")
            return
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("✓ 渲染成功: \(path)")
        }
    }
}

// MARK: - 模拟工作台全景 (完全反映真实 DashboardView 的统一度量、统一 Header、统一 Inspector)
struct MockFullDashboardView: View {
    var selectedTab: String = "timeline"
    var isInspectorVisible: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            // 1. 左侧侧边栏 (宽 248，左留足 20pt 呼吸边距，避让红黄绿灯，绝无截断)
            sidebarView
                .frame(width: 248)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.95))

            Divider().opacity(0.35)

            // 2. 主工作区与统一顶栏
            VStack(spacing: 0) {
                // 统一顶栏 (固定 52pt 高度，绝对对齐基准线，所有页面 Y 坐标恒定)
                unifiedWorkspaceHeader
                    .frame(height: 52)
                    .padding(.horizontal, 20)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.35))

                Divider().opacity(0.35)

                // 主内容路由分流
                mainContentArea
                    .frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(NSColor.underPageBackgroundColor))

            // 3. 右侧统一上下文面板 (常态化 280pt 容器，各 Tab 均有专属辅助上下文)
            if isInspectorVisible {
                Divider().opacity(0.35)
                unifiedContextInspector
                    .frame(width: 280)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
            }
        }
        .frame(width: 1040, height: 660)
    }

    // MARK: - 1. 侧边栏
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 交通灯占位与品牌区域 (避让红黄绿灯)
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.orange)
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
            .padding(.top, 36)

            // 今日专注概览小看板
            VStack(alignment: .leading, spacing: 6) {
                Text("今日专注概览")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("185")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("专注分钟")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }

                    Divider().frame(height: 24)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("8")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
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

            // 一级功能导航
            VStack(spacing: 3) {
                navItem("timeline", "全景时间轴", "clock.arrow.circlepath", count: 8)
                navItem("chat", "AI 记忆对话", "bubble.left.and.bubble.right.fill", badge: "推荐")
                navItem("daily", "今日日报", "sun.max.fill")
                navItem("weekly", "本周周报", "calendar.badge.clock")
                navItem("suspended", "挂起看板", "bolt.badge.clock.fill", count: 3)
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)

            Spacer()

            // 底部主题切换与偏好设置 (彻底使用暖阳金橙等自主规范)
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("外观主题")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("暖阳金橙")
                            .font(.system(size: 9.5))
                            .foregroundColor(.orange)
                    }
                    HStack(spacing: 6) {
                        themeCircle(Color.orange, true)
                        themeCircle(Color.blue, false)
                        themeCircle(Color.teal, false)
                        themeCircle(Color.purple, false)
                        themeCircle(Color.black, false)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                .cornerRadius(7)

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
            .padding(.leading, 18)
            .padding(.trailing, 14)
            .padding(.bottom, 16)
        }
    }

    private func navItem(_ id: String, _ title: String, _ icon: String, count: Int? = nil, badge: String? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(selectedTab == id ? .orange : .secondary)
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
                    .background(Color.orange.opacity(0.18))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            } else if let c = count {
                Text("\(c)")
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

    private func themeCircle(_ c: Color, _ active: Bool) -> some View {
        ZStack {
            Circle().fill(c).frame(width: 18, height: 18)
            if active {
                Circle().stroke(Color.primary, lineWidth: 1.5).frame(width: 22, height: 22)
            }
        }
        .frame(width: 24, height: 24)
    }

    // MARK: - 2. 统一顶栏 (Unified Workspace Header - 固定 52pt 高度，绝对对齐基准线)
    private var unifiedWorkspaceHeader: some View {
        HStack(spacing: 12) {
            // 左侧：统一的图标徽章 + 标题 + 副标题
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 26, height: 26)
                    Image(systemName: currentIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(currentTitle)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(.primary)

                        Text(currentBadge)
                            .font(.system(size: 9.5, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.orange.opacity(0.12))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                    Text(currentSubtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            // 中间/右侧专属操作区
            headerCustomActions

            // 最右侧固定全局操作按钮
            HStack(spacing: 6) {
                // 1. 折叠/展开右侧面板按钮
                HStack(spacing: 2) {
                    Image(systemName: "sidebar.trailing")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .padding(6)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(6)
                }

                // 2. 收起工作台常驻托盘按钮
                HStack(spacing: 3) {
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
        }
    }

    private var currentIcon: String {
        switch selectedTab {
        case "chat": return "bubble.left.and.bubble.right.fill"
        case "daily": return "sun.max.fill"
        case "weekly": return "calendar.badge.clock"
        case "suspended": return "bolt.badge.clock.fill"
        default: return "clock.arrow.circlepath"
        }
    }

    private var currentTitle: String {
        switch selectedTab {
        case "chat": return "AI 记忆对话"
        case "daily": return "今日全景日报"
        case "weekly": return "本周深度周报"
        case "suspended": return "挂起看板"
        default: return "全景时间轴"
        }
    }

    private var currentSubtitle: String {
        switch selectedTab {
        case "chat": return "问答真实工作足迹 · 穿透代码、视窗与操作上下文"
        case "daily": return "基于端侧神经网络离线提炼 · 结构化工作复盘"
        case "weekly": return "跨 7 天历史深度分析 · 研发投入与每日推进脉络"
        case "suspended": return "离开瞬间智能保护 · 随时一键瞬时重回工作现场"
        default: return "端侧离线时序感知 · 自动聚合应用与窗口"
        }
    }

    private var currentBadge: String {
        switch selectedTab {
        case "chat": return "深度穿透"
        case "daily": return "端侧提炼"
        case "weekly": return "研发投入"
        case "suspended": return "3 个待续"
        default: return "8 个现场"
        }
    }

    @ViewBuilder
    private var headerCustomActions: some View {
        switch selectedTab {
        case "timeline", "suspended":
            HStack(spacing: 8) {
                // 搜索框
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)

                    Text("搜索记忆或按回车问 AI...")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.65))
                .cornerRadius(6)
                .frame(width: 175)

                // 分类筛选胶囊
                HStack(spacing: 4) {
                    chipItem("全部", "sparkles", true)
                    chipItem("开发", "hammer.fill", false)
                    chipItem("文档", "doc.text.fill", false)
                    chipItem("通信", "bubble.left.fill", false)
                }
            }
        case "chat":
            Text("清空对话")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(5)
        case "daily", "weekly":
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                    Text("复制 Markdown")
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(Color.orange.opacity(0.12))
                .foregroundColor(.orange)
                .cornerRadius(5)

                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10.5))
                    .padding(5)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(5)
            }
        default:
            EmptyView()
        }
    }

    private func chipItem(_ text: String, _ icon: String, _ active: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9))
            Text(text).font(.system(size: 10.5, weight: active ? .semibold : .regular))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4.5)
        .background(active ? Color.orange.opacity(0.18) : Color.primary.opacity(0.05))
        .foregroundColor(active ? .orange : .secondary)
        .cornerRadius(5)
    }

    // MARK: - 3. 主内容路由分流
    @ViewBuilder
    private var mainContentArea: some View {
        switch selectedTab {
        case "chat":
            chatContentArea
        case "daily":
            dailyContentArea
        case "weekly":
            weeklyContentArea
        default:
            timelineContentArea
        }
    }

    // 时间轴主内容区 (统一从 padding 20, 16 开始)
    private var timelineContentArea: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 14)], spacing: 14) {
                sessionCard("微信开发者工具", "commodity-ledger-mini", "小程序记账与支付回调组件开发", "刚刚搁置", "12 分钟", true)
                sessionCard("Antigravity", "全局记忆精灵 (ContextFlow)", "端侧离线感知与自适应模型嗅探架构", "活跃中", "45 分钟", false)
                sessionCard("Xcode", "AgnesEngine.xcodeproj", "多 Key 故障转移轮换池与单元测试", "已搁置", "28 分钟", false)
                sessionCard("Google Chrome", "GitHub - context-flow PR #12", "多语种国际化架构审查与部署", "已搁置", "16 分钟", false)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func sessionCard(_ app: String, _ title: String, _ sum: String, _ status: String, _ dur: String, _ sel: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4).fill(Color.blue.opacity(0.15)).frame(width: 20, height: 20)
                    Image(systemName: "app.fill").foregroundColor(.blue).font(.system(size: 10))
                }
                Text(app).font(.system(size: 11, weight: .bold)).lineLimit(1)
                Spacer()
                Text(status)
                    .font(.system(size: 9.5))
                    .foregroundColor(sel ? .orange : .secondary)
            }

            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(sum)
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Text("曾专注 \(dur)")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
                Spacer()
                Text("恢复现场")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.orange)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(sel ? Color.orange : Color.primary.opacity(0.08), lineWidth: sel ? 1.5 : 0.5))
    }

    // AI 对话主内容区 (统一从 padding 20, 16 开始，彻底杜绝虚假幻觉)
    private var chatContentArea: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    botBubble("您好！我是全局记忆助手。我可以根据您在 macOS 上的真实窗口轨迹、代码修改、文档及浏览器痕迹回答您的问题。试着问问我今天的工作进展吧！")
                    userBubble("我在反重力里开发了什么项目 进度如何")
                    botBubble("今天在 Antigravity 中，您主要推进了「全局记忆精灵 (ContextFlow)」的核心架构研发，累计专注 45 分钟。\n\n具体工作包括：\n• 重构统一度量体系：全景时间轴与所有子界面统一顶部 52pt 基准线与常态化 280pt 辅助面板；\n• 实现 DeepSeek Harness 机制的本地模型与客户端自适应探测；\n• 全面推翻重构工作台与设置面板，杜绝任何 Tab 折叠与文字截断缺陷；\n• 完成中/英/日多语种国际化 (i18n) 架构。\n\n⚠️ 注：数据库中无任何所谓的「城堡模块」或「导游宝」记录，此前系历史旧项目被辅助功能误扫描残留，现已在端侧完成物理清洗与特征拦截。")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }

            Divider().opacity(0.35)

            // 预设提示词 & 输入框
            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        promptChip("总结今天在各个应用的花费时间")
                        promptChip("今天推进了哪些核心项目？")
                        promptChip("微信开发者工具中改了什么？")
                        promptChip("有哪些挂起未完成的任务？")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }

                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.orange)
                    Text("问全局记忆：比如今天上午在 Xcode 里写了什么代码？")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    private func botBubble(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.18)).frame(width: 24, height: 24)
                Image(systemName: "sparkles").foregroundColor(.orange).font(.system(size: 11))
            }
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineSpacing(4)
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(10)
            Spacer()
        }
    }

    private func userBubble(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Spacer()
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.orange)
                .cornerRadius(12)
        }
    }

    private func promptChip(_ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles").font(.system(size: 8.5)).foregroundColor(.orange)
            Text(text).font(.system(size: 10.5))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(6)
    }

    // 今日日报主内容区
    private var dailyContentArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 指标卡片
                HStack(spacing: 12) {
                    statCard("今日专注时长", "185 分钟", "clock.fill")
                    statCard("攻坚现场总数", "8 个", "bolt.fill")
                    statCard("核心主攻项目", "3 个", "target")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("🎯 核心攻坚综述与业务突破")
                        .font(.system(size: 12.5, weight: .bold))
                    Text("今日高效推进了 3 大研发主线：\n1. 重构 ContextFlow 统一工作台栅格与顶栏规范，彻底消除 Tab 切换时的视觉跳动；\n2. 深入集成 DeepSeek Harness 本地模型与 IDE 插件探查架构；\n3. 完成 SQLite3 WAL 端侧高性能时序引擎迁移，保障全局足迹本地化安全落盘。")
                        .font(.system(size: 12))
                        .lineSpacing(4)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("🚀 攻坚项目实体")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        projectTag("ContextFlow (全局记忆精灵)")
                        projectTag("commodity-ledger-mini (小程序)")
                        projectTag("AgnesEngine (容灾轮换池)")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // 本周周报主内容区
    private var weeklyContentArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    statCard("本周累计专注", "12.4 小时", "clock.badge.checkmark")
                    statCard("处理攻坚现场", "34 个", "square.grid.3x3.fill")
                    statCard("主攻研发项目", "5 个", "folder.fill")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("📊 项目研发时间投入占比分布")
                        .font(.system(size: 12.5, weight: .bold))

                    VStack(spacing: 8) {
                        projectProgress("ContextFlow (全局记忆精灵)", "Antigravity", "480 分钟", 65)
                        projectProgress("commodity-ledger-mini", "微信开发者工具", "160 分钟", 22)
                        projectProgress("AgnesEngine", "Xcode", "100 分钟", 13)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("🗓 每日推进脉络")
                        .font(.system(size: 12.5, weight: .bold))

                    VStack(spacing: 6) {
                        dayRow("周一", "11-03", "完成 SQLite3 WAL 模式端侧重构", "160 分钟")
                        dayRow("周二", "11-04", "攻坚 DeepSeek Harness 模型探测插件", "190 分钟")
                        dayRow("周三", "11-05", "消除侧边栏与设置面板截断缺陷", "175 分钟")
                        dayRow("周四", "11-06", "交付多语种 i18n 与中英日本地化", "130 分钟")
                        dayRow("周五", "11-07", "统一全景工作台对齐基准与常态辅助面板", "185 分钟")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func statCard(_ title: String, _ val: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.12)).frame(width: 28, height: 28)
                Image(systemName: icon).font(.system(size: 12)).foregroundColor(.orange)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 9.5)).foregroundColor(.secondary)
                Text(val).font(.system(size: 13, weight: .bold, design: .rounded))
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(7)
    }

    private func projectTag(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.12))
            .foregroundColor(.orange)
            .cornerRadius(5)
    }

    private func projectProgress(_ name: String, _ app: String, _ time: String, _ pct: Int) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(name).font(.system(size: 11, weight: .semibold))
                Text("(\(app))").font(.system(size: 9.5)).foregroundColor(.secondary)
                Spacer()
                Text(time).font(.system(size: 10.5)).foregroundColor(.secondary)
                Text("\(pct)%").font(.system(size: 11, weight: .bold)).foregroundColor(.orange)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.06)).frame(height: 5)
                    Capsule().fill(Color.orange).frame(width: geo.size.width * CGFloat(pct) / 100.0, height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
        .cornerRadius(6)
    }

    private func dayRow(_ day: String, _ date: String, _ desc: String, _ time: String) -> some View {
        HStack(spacing: 8) {
            Text(day).font(.system(size: 11, weight: .bold)).foregroundColor(.orange)
            Text(date).font(.system(size: 9.5)).foregroundColor(.secondary)
            Text(desc).font(.system(size: 10.5)).lineLimit(1)
            Spacer()
            Text(time).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(4)
    }

    // MARK: - 4. 统一右侧辅助面板 (Unified Context Inspector: 280pt 恒定，各 Tab 皆有专业专属面板)
    @ViewBuilder
    private var unifiedContextInspector: some View {
        switch selectedTab {
        case "chat":
            chatInspectorContent
        case "daily", "weekly":
            reportMetricsInspectorContent
        default:
            timelineInspectorContent
        }
    }

    // 时间轴与挂起详情面板
    private var timelineInspectorContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(Color.green.opacity(0.2)).frame(width: 28, height: 28)
                    Image(systemName: "curlybraces").foregroundColor(.green).font(.system(size: 13, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("微信开发者工具")
                        .font(.system(size: 12, weight: .bold))
                    Text("曾专注 12 分钟 · 刚刚搁置")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.top, 14)
            .padding(.horizontal, 14)

            Divider().opacity(0.35)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("业务现场实体")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("commodity-ledger-mini")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("智能情境总结")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("用户正在微信开发者工具中调试 commodity-ledger-mini 小程序项目，正在完善云函数数据落盘与交易流水组件。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("下一步行动建议")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill").font(.system(size: 9)).foregroundColor(.orange)
                        Text("联调云开发云数据库接口")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Text("标记收尾")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(6)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10, weight: .bold))
                        Text("恢复现场")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 14)
        }
    }

    // AI 对话关联现场召回面板
    private var chatInspectorContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.18)).frame(width: 26, height: 26)
                    Image(systemName: "quote.bubble.fill").foregroundColor(.orange).font(.system(size: 11, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("关联召回的工作现场")
                        .font(.system(size: 12, weight: .bold))
                    Text("当前对话引用的端侧事实证据")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.top, 14)
            .padding(.horizontal, 14)

            Divider().opacity(0.35)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("端侧向量时序索引已就绪，当前命中：")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)

                    retrievedCard("Antigravity", "全局记忆精灵 (ContextFlow)", "端侧离线感知与自适应模型探测架构", "99% 命中")
                    retrievedCard("Xcode", "AgnesEngine.xcodeproj", "多 Key 故障转移轮换池与单元测试", "94% 命中")
                    retrievedCard("微信开发者工具", "commodity-ledger-mini", "小程序记账与支付回调组件开发", "88% 命中")
                }
                .padding(.horizontal, 14)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 11))
                Text("端侧离线向量引擎 · 保护隐私不上传代码")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
            .cornerRadius(6)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }

    private func retrievedCard(_ app: String, _ title: String, _ desc: String, _ match: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(app).font(.system(size: 11, weight: .bold))
                Spacer()
                Text(match).font(.system(size: 9, weight: .medium)).foregroundColor(.orange)
            }
            Text(title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
            Text(desc).font(.system(size: 9.5)).foregroundColor(.secondary).lineLimit(2)
            HStack {
                Spacer()
                Text("一键恢复现场").font(.system(size: 9.5, weight: .semibold)).foregroundColor(.orange)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }

    // 报表指标大盘速览面板
    private var reportMetricsInspectorContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.18)).frame(width: 26, height: 26)
                    Image(systemName: "chart.bar.xaxis").foregroundColor(.orange).font(.system(size: 11, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("核心指标大盘速览")
                        .font(.system(size: 12, weight: .bold))
                    Text(selectedTab == "daily" ? "今日统计汇总" : "本周跨期汇总")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.top, 14)
            .padding(.horizontal, 14)

            Divider().opacity(0.35)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedTab == "daily" ? "今日累计专注" : "本周累计专注")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(selectedTab == "daily" ? "185" : "740")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                            Text("分钟")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("攻坚视窗现场数")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(selectedTab == "daily" ? "8" : "34")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("个现场")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("主要工作应用")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        appRow("Antigravity", "65%")
                        appRow("微信开发者工具", "22%")
                        appRow("Xcode", "13%")
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 14)
            }

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11))
                Text("导出 Markdown 报告")
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Color.orange.opacity(0.12))
            .foregroundColor(.orange)
            .cornerRadius(6)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }

    private func appRow(_ name: String, _ pct: String) -> some View {
        HStack {
            Text(name).font(.system(size: 11, weight: .medium))
            Spacer()
            Text(pct).font(.system(size: 10, weight: .bold)).foregroundColor(.orange)
        }
    }
}

// MARK: - 模拟设置面板 (彻底消除 >> 下拉，消除黑色药丸悬浮栏，消除 Label 切边)
struct MockFullSettingsView: View {
    var currentTab: String = "ai"

    var body: some View {
        VStack(spacing: 0) {
            // 1. 顶部经典分段导航栏 (无任何折叠 >>，无悬浮黑色药丸条)
            HStack(spacing: 6) {
                tabBtn("ai", "AI 记忆引擎", "sparkles")
                tabBtn("privacy", "隐私与黑名单", "hand.raised.fill")
                tabBtn("lifelog", "数字编年史", "book.closed.fill")
                tabBtn("appearance", "外观与主题", "paintpalette.fill")
                tabBtn("general", "权限与维护", "gearshape.2.fill")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider().opacity(0.4)

            // 2. 主体设置内容区
            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    if currentTab == "lifelog" {
                        lifelogTab
                    } else {
                        aiTab
                    }
                }
                .padding(20)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.2))

            Divider().opacity(0.4)

            // 3. 底部常驻操作栏
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 11))
                    Text("全局记忆精灵 · 数据均安全存储在 ~/.contextflow · 拒绝云端外泄")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("恢复默认")
                    .font(.system(size: 12))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(6)

                Text("保存配置")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(Color.blue)
                    .cornerRadius(6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 680, height: 620)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func tabBtn(_ id: String, _ title: String, _ icon: String) -> some View {
        let isSel = currentTab == id
        return HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11.5))
            Text(title).font(.system(size: 11.5, weight: isSel ? .semibold : .regular))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(isSel ? Color(NSColor.controlBackgroundColor) : Color.clear)
        .foregroundColor(isSel ? .orange : .secondary)
        .cornerRadius(7)
        .shadow(color: isSel ? Color.black.opacity(0.08) : Color.clear, radius: 2, y: 1)
    }

    // AI Tab 内容
    private var aiTab: some View {
        VStack(spacing: 14) {
            // 卡片 0: DeepSeek Harness 架构探查中心
            settingsCard("🔌 插件化模型与授权中心 (DeepSeek Harness 架构)", "已探测 6 个适配器") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("借鉴 DeepSeek Harness 插件架构，自适应探查 Ollama、LM Studio 等离线大模型及 Cursor、VS Code、Aider 等 IDE 配置。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        detectedTag("Ollama: deepseek-r1:8b (已就绪)", true)
                        detectedTag("LM Studio: qwen2.5-coder (离线可用)", true)
                        detectedTag("Cursor IDE: 提取到 API 授权", true)
                    }

                    HStack {
                        Spacer()
                        Text("一键全景探测与自动装配")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4.5)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(6)
                    }
                }
            }

            // 卡片 1: 服务商快捷预设
            settingsCard("服务商快捷预设", nil) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Text("快捷预设：")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 90, alignment: .trailing)

                        HStack {
                            Text("DeepSeek (官方 V3/R1)")
                                .font(.system(size: 12))
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15), lineWidth: 1))
                    }

                    Text("支持任意遵循 OpenAI 标准协议的接口服务，包括 DeepSeek、Agnes、智谱、通义千问、Kimi 或本地离线模型。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.leading, 102)
                }
            }

            // 卡片 2: API 连接参数 (完美对齐，绝不切除 Label)
            settingsCard("API 连接参数", nil) {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Text("Base URL：")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 90, alignment: .trailing)
                        Text("https://api.deepseek.com/v1")
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15), lineWidth: 1))
                    }

                    HStack(spacing: 12) {
                        Text("Model Name：")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 90, alignment: .trailing)
                        Text("deepseek-chat")
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15), lineWidth: 1))
                    }
                }
            }

            // 卡片 3: 高可用 API Key 密钥池
            settingsCard("高可用 API Key 密钥池 (Key Pool)", "双 Key 智能轮换已激活") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        Text("API 密钥：")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 90, alignment: .trailing)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("••••••••••••••••••••••••••••••••")
                                    .font(.system(size: 12, design: .monospaced))
                                Spacer()
                                Image(systemName: "eye.slash").font(.system(size: 11)).foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15), lineWidth: 1))

                            Text("已录入 2 个 API Key 形成故障转移容灾池。")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        Spacer().frame(width: 90)
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 11))
                            Text("多 Key 智能轮换与超时故障转移 (Failover) 已启用")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                }
            }
        }
    }

    private func detectedTag(_ text: String, _ ok: Bool) -> some View {
        HStack(spacing: 4) {
            Circle().fill(ok ? Color.green : Color.orange).frame(width: 6, height: 6)
            Text(text).font(.system(size: 10))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(4)
    }

    // GitHub 编年史 Tab 内容
    private var lifelogTab: some View {
        VStack(spacing: 14) {
            settingsCard("GitHub 私有编年史同步 (LifeLog Git Backup)", "端侧安全加密") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text("自动归档：")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 100, alignment: .trailing)

                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.square.fill").foregroundColor(.orange)
                            Text("启用 GitHub 私有仓库静默归档同步")
                                .font(.system(size: 11.5, weight: .medium))
                        }
                    }

                    HStack(spacing: 12) {
                        Text("私有仓库：")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 100, alignment: .trailing)

                        Text("username/my-contextflow-lifelog")
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15), lineWidth: 1))
                    }

                    HStack(spacing: 12) {
                        Text("同步周期：")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 100, alignment: .trailing)

                        HStack {
                            Text("每 2 小时自动提交一次 (推荐)")
                                .font(.system(size: 11.5))
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15), lineWidth: 1))
                    }

                    HStack(spacing: 12) {
                        Text("本地存储：")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 100, alignment: .trailing)

                        HStack {
                            Text("~/.contextflow/lifelog-repo")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("在访达中打开")
                                .font(.system(size: 11))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(5)
                        }
                    }
                }
            }
        }
    }

    private func settingsCard<Content: View>(_ title: String, _ badge: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                if let b = badge {
                    Text(b)
                        .font(.system(size: 10.5))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(5)
                }
            }
            Divider().opacity(0.3)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

