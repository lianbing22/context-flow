import Cocoa
import Foundation
import CoreGraphics

public final class PermissionsManager: @unchecked Sendable {
    public static let shared = PermissionsManager()
    private init() {}

    /// 检查辅助功能权限是否已获得 (静默查询，绝不主动弹出任何弹窗)
    public func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    /// 检查屏幕捕获/录制权限状态 (静默查询，绝不主动弹出任何弹窗)
    public func isScreenCaptureGranted() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }

    /// 用户在设置面板主动发起辅助功能授权引导 (仅在未授权时触发系统引导)
    public func requestAccessibilityIfNeeded() {
        if isAccessibilityGranted() { return }
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// 用户在设置面板主动发起屏幕录制授权引导
    public func requestScreenCaptureIfNeeded() {
        if isScreenCaptureGranted() { return }
        if #available(macOS 11.0, *) {
            CGRequestScreenCaptureAccess()
        }
    }

    /// 打开系统设置对应的隐私面板
    public func openSystemSettings(for pane: String) {
        let urlStr: String
        switch pane {
        case "accessibility":
            urlStr = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case "screenCapture":
            urlStr = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case "automation":
            urlStr = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        default:
            urlStr = "x-apple.systempreferences:com.apple.preference.security"
        }

        if let url = URL(string: urlStr) {
            NSWorkspace.shared.open(url)
        }
    }
}
