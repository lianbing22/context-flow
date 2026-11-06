import Foundation
import Cocoa

public final class AppLogger: @unchecked Sendable {
    public static let shared = AppLogger()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.contextflow.logger", qos: .utility)
    private let dateFormatter: DateFormatter

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folder = home.appendingPathComponent(".contextflow", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.fileURL = folder.appendingPathComponent("contextflow.log")

        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        log(tag: "SYSTEM", message: "=== 全局记忆精灵 v2.0 启动，日志记录器初始化完成 ===")
    }

    public func log(tag: String, message: String) {
        queue.async {
            let nowStr = self.dateFormatter.string(from: Date())
            let line = "[\(nowStr)] [\(tag)] \(message)\n"

            // 打印到标准输出
            print(line, terminator: "")

            // 写入日志文件
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.fileURL.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: self.fileURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        try? fileHandle.close()
                    }
                } else {
                    try? data.write(to: self.fileURL, options: .atomic)
                }
            }

            // 检查文件大小，超过 2MB 截断保留后 1MB
            self.rotateLogIfNeeded()
        }
    }

    private func rotateLogIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? UInt64,
              size > 2 * 1024 * 1024 else { return }

        guard let data = try? Data(contentsOf: fileURL) else { return }
        let keepBytes = 1024 * 1024
        if data.count > keepBytes {
            let trimmed = data.suffix(keepBytes)
            try? trimmed.write(to: fileURL, options: .atomic)
            log(tag: "SYSTEM", message: "日志已滚动截断，保留最新 1MB 记录")
        }
    }

    public func openLogFile() {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            NSWorkspace.shared.open(fileURL)
        }
    }
}
