import Foundation
import Cocoa

@MainActor
public final class LifeLogSyncManager: ObservableObject {
    public static let shared = LifeLogSyncManager()

    @Published public var isSyncing: Bool = false
    @Published public var lastSyncTimeText: String? = nil
    @Published public var syncMessage: String? = nil

    private let scriptPath: String
    private var autoSyncTimer: Timer?

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let folder = (home as NSString).appendingPathComponent(".contextflow")
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        self.scriptPath = (folder as NSString).appendingPathComponent("sync_lifelog.py")

        ensureSyncScriptExists()
        restartAutoSyncTimer()
    }

    /// 确保 ~/.contextflow/sync_lifelog.py 脚本已就绪 (P1)
    private func ensureSyncScriptExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: scriptPath) {
            let bundledScript = Bundle.main.path(forResource: "sync_lifelog", ofType: "py")
            if let src = bundledScript, fm.fileExists(atPath: src) {
                try? fm.copyItem(atPath: src, toPath: scriptPath)
            } else {
                // 如果未打包进资源，直接写入自包含 Python 引擎代码
                let pythonCode = """
                #!/usr/bin/env python3
                # -*- coding: utf-8 -*-
                import sys, os, shutil, subprocess, datetime, sqlite3

                def run_cmd(cmd, cwd=None):
                    try:
                        res = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
                        return True, res.stdout.strip()
                    except subprocess.CalledProcessError as e:
                        return False, e.stderr.strip()

                def export_daily_markdown(db_path, output_dir):
                    os.makedirs(output_dir, exist_ok=True)
                    if not os.path.exists(db_path): return
                    try:
                        conn = sqlite3.connect(db_path)
                        cursor = conn.cursor()
                        cursor.execute("SELECT date, summary, key_projects, suggestions, total_focus_minutes, session_count FROM daily_reports ORDER BY date DESC")
                        for row in cursor.fetchall():
                            dt, summary, projects, suggestions, focus_mins, count = row
                            with open(os.path.join(output_dir, f"{dt}.md"), "w", encoding="utf-8") as f:
                                f.write(f"# 工作记忆编年史 · {dt}\\n\\n- 专注时长：{focus_mins} 分钟\\n- 记录现场数：{count} 个\\n\\n## 核心工作概述\\n{summary}\\n\\n## 关联工程实体\\n{projects}\\n\\n## 复盘与下一步建议\\n{suggestions}\\n")
                        conn.close()
                    except Exception as e:
                        print(f"[WARN] 导出 Markdown 失败: {e}", file=sys.stderr)

                def main():
                    if len(sys.argv) < 2:
                        sys.exit(1)
                    repo_arg = sys.argv[1].strip()
                    branch = sys.argv[2].strip() if len(sys.argv) > 2 else "main"
                    home = os.path.expanduser("~")
                    cf_dir = os.path.join(home, ".contextflow")
                    db_file = os.path.join(cf_dir, "contextflow.sqlite3")
                    local_repo_dir = os.path.join(cf_dir, "lifelog-repo")
                    os.makedirs(local_repo_dir, exist_ok=True)

                    export_daily_markdown(db_file, os.path.join(local_repo_dir, "chronicle"))
                    if os.path.exists(db_file):
                        shutil.copy2(db_file, os.path.join(local_repo_dir, "contextflow_backup.sqlite3"))

                    readme_path = os.path.join(local_repo_dir, "README.md")
                    if not os.path.exists(readme_path):
                        with open(readme_path, "w", encoding="utf-8") as f:
                            f.write("# ContextFlow Lifelog Backup\\n\\nPersonal encrypted and automated work activity chronicle backed up via ContextFlow.\\n")

                    git_dir = os.path.join(local_repo_dir, ".git")
                    if not os.path.exists(git_dir):
                        run_cmd(["git", "init"], cwd=local_repo_dir)

                    remote_url = repo_arg if (repo_arg.startswith("git@") or repo_arg.startswith("http")) else f"git@github.com:{repo_arg}.git"
                    run_cmd(["git", "remote", "remove", "origin"], cwd=local_repo_dir)
                    run_cmd(["git", "remote", "add", "origin", remote_url], cwd=local_repo_dir)

                    run_cmd(["git", "add", "-A"], cwd=local_repo_dir)
                    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    run_cmd(["git", "commit", "-m", f"Auto sync lifelog: {now_str}"], cwd=local_repo_dir)

                    ok, err = run_cmd(["git", "push", "-u", "origin", f"HEAD:{branch}"], cwd=local_repo_dir)
                    if not ok:
                        ok2, _ = run_cmd(["git", "push", "origin", "HEAD"], cwd=local_repo_dir)
                        if not ok2: sys.exit(1)
                    sys.exit(0)

                if __name__ == "__main__":
                    main()
                """
                try? pythonCode.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            }
            // 赋可执行权限
            let _ = chmod(scriptPath, 0o755)
        }
    }

    /// 动态根据用户配置的周期更新定时器 (P1)
    public func restartAutoSyncTimer() {
        autoSyncTimer?.invalidate()
        let settings = ContextStore.shared.load().settings
        let intervalHours = max(1, settings.syncIntervalHours)
        let intervalSeconds = Double(intervalHours * 3600)

        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.triggerSync(isManual: false)
            }
        }
    }

    /// 触发同步 (可手动或定时调用)
    public func triggerSync(isManual: Bool = true) {
        ensureSyncScriptExists()
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
