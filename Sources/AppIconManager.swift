import Cocoa
import Foundation

@MainActor
public final class AppIconManager {
    public static let shared = AppIconManager()

    private var iconCache: [String: NSImage] = [:]

    private init() {}

    /// 获取指定应用的高清图标 (自动根据 bundleId 或 appName 匹配，带内存缓存)
    public func icon(for appName: String, bundleId: String? = nil) -> NSImage {
        let cacheKey = bundleId ?? appName
        if let cached = iconCache[cacheKey] {
            return cached
        }

        // 1. 尝试通过 Bundle Identifier 寻找已安装应用的真实路径
        if let bid = bundleId, !bid.isEmpty,
           let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            let img = NSWorkspace.shared.icon(forFile: appUrl.path)
            img.size = NSSize(width: 32, height: 32)
            iconCache[cacheKey] = img
            return img
        }

        // 2. 尝试在 runningApplications 中根据 localizedName 匹配
        if let running = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.lowercased() == appName.lowercased() ||
            $0.bundleIdentifier?.lowercased().contains(appName.lowercased()) == true
        }) {
            if let icon = running.icon {
                icon.size = NSSize(width: 32, height: 32)
                iconCache[cacheKey] = icon
                return icon
            }
        }

        // 3. 尝试在 /Applications 目录下寻找
        let appPaths = [
            "/Applications/\(appName).app",
            "/System/Applications/\(appName).app",
            "/System/Applications/Utilities/\(appName).app",
            "/Applications/\(appName) CN.app"
        ]

        for p in appPaths {
            if FileManager.default.fileExists(atPath: p) {
                let img = NSWorkspace.shared.icon(forFile: p)
                img.size = NSSize(width: 32, height: 32)
                iconCache[cacheKey] = img
                return img
            }
        }

        // 4. 默认系统应用通用图标兜底
        let defaultIcon = NSWorkspace.shared.icon(for: .application)
        defaultIcon.size = NSSize(width: 32, height: 32)
        iconCache[cacheKey] = defaultIcon
        return defaultIcon
    }
}
