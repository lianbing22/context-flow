import Cocoa
import CoreGraphics

// 命令行权限诊断模式
if CommandLine.arguments.contains("--check-permissions") {
    let ax = AXIsProcessTrusted()
    let sc: Bool
    if #available(macOS 10.15, *) {
        sc = CGPreflightScreenCaptureAccess()
    } else {
        sc = true
    }

    var ae = false
    let script = "tell application \"System Events\" to return name of first application process whose frontmost is true"
    var error: NSDictionary?
    if let s = NSAppleScript(source: script) {
        let res = s.executeAndReturnError(&error)
        ae = (error == nil && res.stringValue != nil)
    }

    print("CHECK_RESULT: Accessibility=\(ax), ScreenCapture=\(sc), AppleEvents=\(ae)")
    exit(0)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // 初始化状态栏图标与事件监听 (纯静默运行，绝不主动弹出任何权限弹窗)
        MenuBarManager.shared.setup()

        AppLogger.shared.log(tag: "STARTUP", message: "ContextFlow 启动完毕，静默守护运行中")

        // 监听外部控制通知 (支持即时远程唤起指定窗口与问答)
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("app.memoryelf.open"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            if let query = notif.userInfo?["query"] as? String {
                DashboardWindowController.shared.showWindow(tab: "chat")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    NotificationCenter.default.post(name: NSNotification.Name("ContextFlow.AskQuestion"), object: query)
                }
                return
            }
            guard let action = notif.userInfo?["action"] as? String else { return }
            self?.handleOpenAction(action)
        }

        // 处理命令行启动参数
        let args = CommandLine.arguments
        if args.contains("--all") || args.contains("--open-all") {
            handleOpenAction("all")
        } else if args.contains("--dashboard") || args.contains("--open-dashboard") {
            handleOpenAction("dashboard")
        } else if args.contains("--chat") || args.contains("--open-chat") {
            handleOpenAction("chat")
        } else if args.contains("--daily") || args.contains("--open-daily") {
            handleOpenAction("daily")
        } else if args.contains("--weekly") || args.contains("--open-weekly") {
            handleOpenAction("weekly")
        } else if args.contains("--settings") || args.contains("--open-settings") {
            handleOpenAction("settings")
        } else if args.contains("--briefing") || args.contains("--open-briefing") {
            handleOpenAction("briefing")
        } else if args.contains("--popover") || args.contains("--open-popover") {
            handleOpenAction("popover")
        }
    }

    private func handleOpenAction(_ action: String) {
        Task { @MainActor in
            switch action {
            case "dashboard":
                DashboardWindowController.shared.showWindow(tab: "timeline")
            case "chat":
                DashboardWindowController.shared.showWindow(tab: "chat")
            case "daily":
                DashboardWindowController.shared.showWindow(tab: "daily")
            case "weekly":
                DashboardWindowController.shared.showWindow(tab: "weekly")
            case "settings":
                SettingsWindowController.shared.showWindow()
            case "settings-scan":
                SettingsWindowController.shared.showWindow(tab: "ai")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    NotificationCenter.default.post(name: NSNotification.Name("ContextFlow.TriggerModelScan"), object: nil)
                }
            case "settings-ai":
                SettingsWindowController.shared.showWindow(tab: "ai")
            case "settings-privacy":
                SettingsWindowController.shared.showWindow(tab: "privacy")
            case "settings-lifelog":
                SettingsWindowController.shared.showWindow(tab: "lifelog")
            case "settings-appearance":
                SettingsWindowController.shared.showWindow(tab: "appearance")
            case "settings-general":
                SettingsWindowController.shared.showWindow(tab: "general")
            case "briefing":
                BriefingWindowController.shared.showWindow()
            case "popover":
                MenuBarManager.shared.showPopover(nil)
            case "all":
                DashboardWindowController.shared.showWindow()
                SettingsWindowController.shared.showWindow()
                BriefingWindowController.shared.showWindow()
                MenuBarManager.shared.showPopover(nil)
            default:
                break
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        ContextEngine.shared.persistState()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
