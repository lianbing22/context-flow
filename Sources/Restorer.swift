import Cocoa
import UserNotifications

public final class Restorer: @unchecked Sendable {
    public static let shared = Restorer()
    private init() {}

    /// 一键恢复任务现场
    public func restore(session: ContextSession) {
        print("[Restorer] 正在恢复现场: \(session.title)")

        // 1. 恢复网页 URL
        let urls = session.items.compactMap { $0.url }.filter { !$0.isEmpty }
        let uniqueUrls = Array(Set(urls))
        for urlStr in uniqueUrls {
            if let url = URL(string: urlStr) {
                NSWorkspace.shared.open(url)
            }
        }

        // 2. 恢复本地文件
        let files = session.items.compactMap { $0.filePath }.filter { !$0.isEmpty }
        let uniqueFiles = Array(Set(files))
        for file in uniqueFiles {
            let path = (file as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: path) {
                let fileURL = URL(fileURLWithPath: path)
                NSWorkspace.shared.open(fileURL)
            }
        }

        // 3. 激活相关应用程序
        let runningApps = NSWorkspace.shared.runningApplications
        for item in session.items {
            if let app = runningApps.first(where: {
                $0.bundleIdentifier == item.bundleId || $0.localizedName == item.appName
            }) {
                app.activate()
            }
        }

        // 4. 发送桌面提醒通知
        sendNotification(
            title: "⚡️ 工作现场已恢复",
            body: "已重新打开 [\(session.title)] 关联的 \(uniqueUrls.count) 个网页和 \(uniqueFiles.count) 个文件"
        )
    }

    private func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request, withCompletionHandler: nil)
    }
}
