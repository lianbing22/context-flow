import SwiftUI
import Cocoa

// MARK: - 100% 纯虚拟、完全脱敏的开源演示视图 (0 真实用户数据)

struct MockMainPanel: View {
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 7) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 22, height: 22)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                }

                Text("全局记忆精灵")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("MEMORY")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06))
                    .foregroundColor(.secondary)
                    .cornerRadius(4)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    Text("3 现场挂起")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // 搜索输入框
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundColor(.purple)
                Text("问问全局记忆（如：今天我改了什么代码？）")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(8)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            Divider().opacity(0.6)

            // 内容列表
            VStack(spacing: 11) {
                // 当前专注
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                            Text("当前专注").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("28 分钟").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "curlybraces.square.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("开源框架架构设计与核心重构")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(.primary)
                            HStack(spacing: 5) {
                                Text("VS Code").font(.system(size: 10.5)).foregroundColor(.secondary)
                                Text("AwesomeProject")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                        }
                        Spacer()
                        Text("挂起")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(6)
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                    .cornerRadius(10)
                }

                // 挂起现场
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        HStack(spacing: 4) {
                            Circle().fill(Color.orange).frame(width: 6, height: 6)
                            Text("挂起现场").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    // 卡片 1
                    mockCard(
                        iconName: "safari.fill",
                        iconColor: .blue,
                        appName: "Safari",
                        title: "开发者文档 · Swift 并发模型解析",
                        ago: "5 分钟前搁置",
                        suggestion: "阅读第 3 章节 Actor 隔离机制"
                    )

                    // 卡片 2
                    mockCard(
                        iconName: "terminal.fill",
                        iconColor: .black,
                        appName: "Terminal",
                        title: "单元测试套件执行与覆盖率校验",
                        ago: "18 分钟前搁置",
                        suggestion: "查看 Codecov 测试报告并补充用例"
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Spacer()

            Divider().opacity(0.6)

            // 底部栏
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "book.closed").font(.system(size: 10)).foregroundColor(.secondary)
                    Text("数字编年史已就绪").font(.system(size: 10.5)).foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "sparkles").font(.system(size: 9))
                    Text("今日复盘").font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(5)

                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 10)).foregroundColor(.secondary)
                Image(systemName: "gearshape").font(.system(size: 10.5)).foregroundColor(.secondary)
                Image(systemName: "power").font(.system(size: 10.5)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        }
        .frame(width: 390, height: 530)
    }

    private func mockCard(iconName: String, iconColor: Color, appName: String, title: String, ago: String, suggestion: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(appName).font(.system(size: 11, weight: .bold)).foregroundColor(.primary.opacity(0.85))
                        Spacer()
                        Text(ago).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(.primary)
                }
            }

            // 行动胶囊
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill").font(.system(size: 8)).foregroundColor(.orange)
                Text("下一步：\(suggestion)").font(.system(size: 10, weight: .medium)).foregroundColor(.orange).lineLimit(1)
                Image(systemName: "arrow.right").font(.system(size: 7.5)).foregroundColor(.orange.opacity(0.8))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(5)
            .padding(.leading, 34)
        }
        .padding(9)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .cornerRadius(9)
    }
}

// MARK: - 渲染入口

@main
struct RenderSafeScreenshotsApp {
    @MainActor
    static func main() {
        print("==> 开始生成 100% 虚拟脱敏的开源展示截图...")

        // 1. 主面板 (完全由虚拟 Mock 数据渲染，0 真实个人数据)
        let mainView = MockMainPanel()
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .padding(16)
            .background(Color(white: 0.94))

        renderViewToPNG(
            view: mainView,
            size: NSSize(width: 422, height: 562),
            outputPath: "/Users/lianb/.gemini/antigravity/scratch/context-flow/docs/screenshots/01_main_panel.png"
        )

        // 2. 每日复盘与全景晨报模态弹窗 (100% 虚构开源项目数据，无任何人名、无真实项目)
        let safeBriefing = DailyWrapUp(
            date: "2026-11-07",
            summary: "今日聚焦于开源架构重构与端侧神经视觉模型优化，实现了毫秒级本地离线实体提炼。累计推进 3 个核心技术模块，全量测试套件通过率 100%。",
            keyProjects: ["开源架构重构", "端侧神经视觉", "单元测试套件"],
            totalFocusMinutes: 185,
            sessionCount: 7,
            suggestions: [
                "补充核心模块英文开发文档与用例文档",
                "完善不同 macOS 系统的多架构兼容性测试",
                "发布开源 v2.0 正式版本"
            ]
        )

        let briefingView = DailyBriefingModal(briefing: safeBriefing, onClose: {})
            .frame(width: 390, height: 480)
            .background(Color.black.opacity(0.3))
            .padding(16)
            .background(Color(white: 0.94))

        renderViewToPNG(
            view: briefingView,
            size: NSSize(width: 422, height: 512),
            outputPath: "/Users/lianb/.gemini/antigravity/scratch/context-flow/docs/screenshots/03_daily_briefing.png"
        )

        print("🎉 虚拟脱敏安全截图全部生成完毕！")
    }

    @MainActor
    static func renderViewToPNG<V: View>(view: V, size: NSSize, outputPath: String) {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            print("Failed to allocate bitmapImageRep for \(outputPath)")
            return
        }

        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: outputPath))
            print("✓ Safe Rendered: \(outputPath) (\(data.count / 1024) KB)")
        }
    }
}
