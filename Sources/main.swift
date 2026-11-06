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
    }

    func applicationWillTerminate(_ notification: Notification) {
        ContextEngine.shared.persistState()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
