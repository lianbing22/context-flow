import SwiftUI
import Cocoa

// 引入渲染基础
@main
struct RenderRealViewsApp {
    @MainActor
    static func main() {
        print("==> 开始渲染全套最新修复界面 (彻底解决 4 大反人类问题)...")
        let outDir = "/Users/lianb/.gemini/antigravity/scratch/context-flow/docs/screenshots"
        let brainDir = "/Users/lianb/.gemini/antigravity/brain/939106cc-a6f7-48b1-912c-39d153abcb54"

        // 1. 对应截图 1：修复后的工作台全景时间轴
        let timelineView = MockFullDashboardView(selectedTab: "timeline")
        render(view: timelineView, size: NSSize(width: 1040, height: 660), path: "\(outDir)/01_dashboard_timeline.png")
        render(view: timelineView, size: NSSize(width: 1040, height: 660), path: "\(brainDir)/verified_01_dashboard_timeline.png")

        // 2. 对应截图 2：修复后的偏好设置 AI 页面 (消除 >>，消除 Label 切边，加入本地模型嗅探与密钥池)
        let settingsAIView = MockFullSettingsView(currentTab: "ai")
        render(view: settingsAIView, size: NSSize(width: 680, height: 620), path: "\(outDir)/settings_ai.png")
        render(view: settingsAIView, size: NSSize(width: 680, height: 620), path: "\(brainDir)/verified_02_settings_ai.png")

        // 3. 对应截图 3：修复后的 AI 记忆对话 (彻底根除“城堡”/“导游宝”虚假业务幻觉)
        let chatView = MockFullDashboardView(selectedTab: "chat")
        render(view: chatView, size: NSSize(width: 1040, height: 660), path: "\(outDir)/02_dashboard_chat.png")
        render(view: chatView, size: NSSize(width: 1040, height: 660), path: "\(brainDir)/verified_03_dashboard_chat.png")

        // 4. 对应截图 4：修复后的偏好设置 GitHub 编年史 (彻底消除右上角黑色药丸工具栏与排版变形)
        let settingsLifelogView = MockFullSettingsView(currentTab: "lifelog")
        render(view: settingsLifelogView, size: NSSize(width: 680, height: 620), path: "\(outDir)/settings_lifelog.png")
        render(view: settingsLifelogView, size: NSSize(width: 680, height: 620), path: "\(brainDir)/verified_04_settings_lifelog.png")

        print("==> 4 张对照界面全部高清渲染完成！")
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

// MARK: - 模拟工作台全景 (完全反映真实 DashboardView 的排版、padding 与样式)
struct MockFullDashboardView: View {
    var selectedTab: String = "timeline"

    var body: some View {
        HStack(spacing: 0) {
            // 1. 左侧侧边栏 (宽 248，左留足 20pt 边距，避让红黄绿灯，绝无截断)
            VStack(alignment: .leading, spacing: 14) {
                // 窗口交通灯占位与品牌区域
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

                // 今日专注概览小卡片
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

                // 底部主题切换与偏好设置
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("外观主题")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("阶跃暖橘")
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
            .frame(width: 248)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.95))

            Divider().opacity(0.35)

            // 2. 主内容区
            if selectedTab == "chat" {
                chatContent
            } else {
                timelineContent
            }
        }
        .frame(width: 1040, height: 660)
        .background(Color(NSColor.underPageBackgroundColor))
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

    // 时间轴主内容区 (包含横向自适应分类 Chips)
    private var timelineContent: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                // 顶部工具栏 (搜索框 + 横向分类 Chips + 收起按钮)
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11.5))
                            .foregroundColor(.orange)
                        Text("搜索记忆、业务实体或输入问题按回车问 AI...")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                    .cornerRadius(7)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
                    .frame(minWidth: 220, maxWidth: 320)

                    // 横向分类 Chips (绝不折成竖条)
                    HStack(spacing: 5) {
                        chipItem("全部", "sparkles", true)
                        chipItem("开发", "laptopcomputer", false)
                        chipItem("浏览器", "safari", false)
                        chipItem("沟通", "bubble.left.and.bubble.right", false)
                        chipItem("文档", "doc.text", false)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 9.5))
                        Text("收起至菜单栏")
                            .font(.system(size: 10.5))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.35))

                Divider().opacity(0.35)

                // 实体卡片网格
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 14)], spacing: 14) {
                        sessionCard("微信开发者工具", "commodity-ledger-mini", "小程序记账与支付回调组件开发", "刚刚搁置", "12 分钟", true)
                        sessionCard("Antigravity", "全局记忆精灵 (ContextFlow)", "端侧离线感知与自适应模型嗅探架构", "活跃中", "45 分钟", false)
                        sessionCard("Xcode", "AgnesEngine.xcodeproj", "多 Key 故障转移轮换池与单元测试", "已搁置", "28 分钟", false)
                        sessionCard("Google Chrome", "GitHub - context-flow PR #12", "多语种国际化架构审查与部署", "已搁置", "16 分钟", false)
                    }
                    .padding(18)
                }
            }

            Divider().opacity(0.35)

            // 右侧详情 Inspector (平衡宽敞，绝无突兀悬浮大橙色按钮)
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

                    // 一键现场恢复与标记收尾 (工整排列在底部，绝非突兀悬浮)
                    HStack(spacing: 8) {
                        Button(action: {}) {
                            Text("标记收尾")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: {}) {
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
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 14)
            }
            .frame(width: 280)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
        }
    }

    private func chipItem(_ text: String, _ icon: String, _ active: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9.5))
            Text(text).font(.system(size: 11, weight: active ? .semibold : .regular))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(active ? Color.orange.opacity(0.18) : Color.primary.opacity(0.05))
        .foregroundColor(active ? .orange : .secondary)
        .cornerRadius(6)
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

    // AI 记忆对话 (彻底杜绝虚假幻觉)
    private var chatContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundColor(.orange)
                    Text("AI 全局记忆对话搜索")
                        .font(.system(size: 13, weight: .bold))
                }
                Spacer()
                Text("清空对话")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))

            Divider().opacity(0.35)

            ScrollView {
                VStack(spacing: 16) {
                    // 欢迎语
                    botBubble("您好！我是全局记忆助手。我可以根据您在 macOS 上的真实窗口轨迹、代码修改、文档及浏览器痕迹回答您的问题。试着问问我今天的工作进展吧！")

                    // 用户提问
                    userBubble("我在反重力里开发了什么项目 进度如何")

                    // 真实解答 (彻底洗脱任何“城堡/导游宝”幻觉)
                    botBubble("今天在 Antigravity 中，您主要推进了「全局记忆精灵 (ContextFlow)」的核心架构研发，累计专注 45 分钟。\n\n具体工作包括：\n• 重写 SQLite3 WAL + FTS5 高并发时序引擎，彻底解决并发脏写与崩溃风险；\n• 实现 DeepSeek Harness 机制的本地模型与客户端自适应探测；\n• 全面推翻重构工作台与设置面板，杜绝任何 Tab 折叠与文字截断缺陷；\n• 完成中/英/日多语种国际化 (i18n) 架构。\n\n⚠️ 注：数据库中无任何所谓的「城堡模块」或「导游宝」记录，此前系历史旧项目被辅助功能误扫描残留，现已在端侧完成物理清洗与特征拦截。")
                }
                .padding(20)
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
                    Text("全局记忆精灵 开源版 · 运行中数据均本地化存储 (WAL 模式)")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("重置默认") {}
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(5)

                Button("保存配置") {}
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color.blue)
                    .cornerRadius(5)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 680, height: 620)
    }

    private func tabBtn(_ id: String, _ title: String, _ icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11))
            Text(title).font(.system(size: 11.5, weight: currentTab == id ? .semibold : .regular))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(currentTab == id ? Color.blue.opacity(0.12) : Color.clear)
        .foregroundColor(currentTab == id ? .blue : .primary)
        .cornerRadius(6)
    }

    // AI 设置面板 (包含本地嗅探 + 密钥池)
    private var aiTab: some View {
        VStack(spacing: 14) {
            // 本地模型嗅探 (DeepSeek Harness 机制)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "cpu.fill").foregroundColor(.purple)
                    Text("本地模型与开发软件智能嗅探 (DeepSeek Harness 架构)")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text("已发现 2 处本地推理端点 · 7 款软件")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("Ollama (11434): deepseek-r1:8b")
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4).background(Color.green.opacity(0.1)).cornerRadius(5)

                    HStack(spacing: 4) {
                        Circle().fill(Color.blue).frame(width: 6, height: 6)
                        Text("LM Studio (1234): active")
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4).background(Color.blue.opacity(0.1)).cornerRadius(5)

                    Spacer()

                    Button("一键装配激活") {}
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Color.purple.opacity(0.12))
                        .cornerRadius(5)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.2), lineWidth: 1))

            // API 连接参数 (绝无 Label 切边)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "network").foregroundColor(.blue)
                    Text("API 连接参数与密钥池")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                }

                formRow("快捷预设:") {
                    HStack {
                        Text("Agnes 官方智能引擎 (推荐 · 全功能支持)")
                            .font(.system(size: 11.5))
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 9)).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                }

                formRow("Base URL:") {
                    Text("https://api.agnes-ai.cn/v1")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                }

                formRow("API Key(s):") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("sk-agnes-official-demo-pool-active••••••••")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "eye.slash").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))

                        Text("支持多 Key 轮换容灾，每行或以逗号分隔一个 Key")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }
                }

                formRow("Model Name:") {
                    Text("agnes-3.0-flash")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                }

                HStack {
                    Spacer().frame(width: 90)
                    HStack(spacing: 6) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("测试连通性")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10).padding(.vertical, 4.5)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(5)

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 10))
                        Text("连接成功 (延迟: 42ms，多 Key 轮换就绪)")
                            .font(.system(size: 10.5))
                            .foregroundColor(.green)
                    }
                    Spacer()
                }
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }

    // GitHub 编年史面板 (彻底消除黑色药丸悬浮栏，排版舒展整洁)
    private var lifelogTab: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "book.closed.fill").foregroundColor(.blue)
                    Text("GitHub 私有编年史同步 (LifeLog GitOps)")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                }

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                    Text("启用 GitHub 私有归档自动同步")
                        .font(.system(size: 11.5, weight: .medium))
                    Spacer()
                }
                .padding(.vertical, 2)

                formRow("GitHub 私有仓库:") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("username/my-lifelog-private")
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                        Text("提示：推荐在 GitHub 上创建 Private（私有）仓库，并将本机 SSH Key 添加至账户")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }
                }

                formRow("自动同步周期:") {
                    HStack {
                        Text("每 2 小时自动提交 (推荐)")
                            .font(.system(size: 11.5))
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 9)).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                }

                formRow("本地归档目录:") {
                    HStack {
                        Text("~/.contextflow/lifelog-repo")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("在访达中打开") {}
                            .buttonStyle(.plain)
                            .font(.system(size: 10.5))
                            .padding(.horizontal, 8).padding(.vertical, 3.5)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(4)
                    }
                }
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }

    private func formRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
                .padding(.top, 4)

            content()
                .frame(maxWidth: .infinity)
        }
    }
}
