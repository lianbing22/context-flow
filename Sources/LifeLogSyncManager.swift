import Foundation
import Cocoa

@MainActor
public final class LifeLogSyncManager: ObservableObject {
    public static let shared = LifeLogSyncManager()

    @Published public var isSyncing: Bool = false
    @Published public var lastSyncTimeText: String? = nil
    @Published public var syncMessage: String? = nil

    private let scriptPath = (FileManager.default.homeDirectoryForCurrentUser.path as NSString).appendingPathComponent(".contextflow/sync_lifelog.py")
    private var autoSyncTimer: Timer?

    private init() {
        startAutoSyncTimer()
    }

    private func startAutoSyncTimer() {
        // 每 2 小时静默自动同步一次到 GitHub
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: 7200, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.triggerSync(isManual: false)
            }
        }
    }

    /// 触发同步 (可手动或定时调用)
    public func triggerSync(isManual: Bool = true) {
        let settings = ContextStore.shared.load().settings
        guard settings.enableGitHubSync else {
            if isManual {
                self.syncMessage = "未开启 GitHub 归档，可在设置中启用"
            }
            return
        }

        let repo = settings.gitHubRepo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repo.isEmpty else {
            if isManual {
                self.syncMessage = "请先在设置中填写你的 GitHub 仓库地址"
            }
            return
        }

        guard !isSyncing else { return }
        isSyncing = true
        syncMessage = "正在归档并推送到 GitHub..."
        AppLogger.shared.log(tag: "LIFELOG", message: "启动 GitHub 私有编年史自动同步: [\(repo)]...")

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            task.arguments = [self.scriptPath, repo]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let success = (task.terminationStatus == 0)
                let nowStr = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)

                Task { @MainActor in
                    self.isSyncing = false
                    if success {
                        self.lastSyncTimeText = "已同步 (\(nowStr))"
                        self.syncMessage = "已同步至 GitHub: \(repo)"
                        AppLogger.shared.log(tag: "LIFELOG", message: "✓ GitHub 编年史同步成功！")
                    } else {
                        self.syncMessage = "同步失败，请检查网络或 SSH/Token 权限"
                        AppLogger.shared.log(tag: "LIFELOG", message: "Git 同步执行非零退出码")
                    }
                }
            } catch {
                Task { @MainActor in
                    self.isSyncing = false
                    self.syncMessage = "同步出错: \(error.localizedDescription)"
                    AppLogger.shared.log(tag: "LIFELOG", message: "无法启动同步脚本: \(error)")
                }
            }
        }
    }

    /// 打开 GitHub 仓库页面
    public func openGitHubRepo() {
        let settings = ContextStore.shared.load().settings
        let repo = settings.gitHubRepo.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlStr = repo.isEmpty ? "https://github.com" : (repo.starts(with: "http") ? repo : "https://github.com/\(repo)")
        if let url = URL(string: urlStr) {
            NSWorkspace.shared.open(url)
        }
    }
}
