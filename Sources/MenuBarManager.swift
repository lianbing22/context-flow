import Cocoa
import SwiftUI

@MainActor
public final class MenuBarManager: NSObject {
    public static let shared = MenuBarManager()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?

    private override init() {
        super.init()
    }

    public func setup() {
        // 创建常驻状态栏 Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // 初始化 Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 390, height: 480)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MainPopoverView())

        // 监听状态变化更新角标
        ContextEngine.shared.onStateChanged = { [weak self] in
            self?.updateBadge()
        }

        updateBadge()
    }

    public func updateBadge() {
        guard let button = statusItem.button else { return }

        let count = ContextEngine.shared.suspendedSessions.count
        if count > 0 {
            button.title = "⚡️ \(count)"
        } else {
            button.title = "⚡️"
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard statusItem.button != nil else { return }

        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }

    public func showPopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        // 唤醒并置顶显示
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // 点击外部区域自动关闭监听
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closePopover(event)
        }
    }

    public func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
