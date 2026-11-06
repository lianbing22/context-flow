import Foundation
import Cocoa
import Vision

public final class SnapshotManager: @unchecked Sendable {
    public static let shared = SnapshotManager()

    private let snapshotFolder: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.snapshotFolder = home.appendingPathComponent(".contextflow/snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: snapshotFolder, withIntermediateDirectories: true)
    }

    /// 离开瞬间为当前前台视窗抓取微缩快照，并使用 macOS 本地 Vision 神经引擎毫秒级提取核心屏幕视觉文字 (0 隐私泄露、0 云端上传)
    public func captureSnapshotWithOCR(sessionId: UUID) -> (path: String?, ocrText: String?) {
        let targetFile = snapshotFolder.appendingPathComponent("\(sessionId.uuidString).jpg")
        let tempRaw = FileManager.default.temporaryDirectory.appendingPathComponent("cf_raw_\(UUID().uuidString).png")

        // 1. 调用 macOS 原生静默全屏/视窗抓取 (无声、不弹窗)
        let captureTask = Process()
        captureTask.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        captureTask.arguments = ["-x", "-m", tempRaw.path] // -x 静音, -m 主显示器
        try? captureTask.run()
        captureTask.waitUntilExit()

        guard FileManager.default.fileExists(atPath: tempRaw.path) else {
            return (nil, nil)
        }

        // 2. 本地 Vision.framework 原生毫秒级离线 OCR 识别 (提取真实视窗大字与核心业务实体)
        var extractedOCRText: String? = nil
        if let img = NSImage(contentsOfFile: tempRaw.path),
           let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            extractedOCRText = performLocalVisionOCR(cgImage: cgImage)
        }

        // 3. 使用 macOS 内置 sips 压制为宽度 360px、质量 75 的超轻量缩略图
        let sipsTask = Process()
        sipsTask.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        sipsTask.arguments = ["-s", "format", "jpeg", "-s", "formatOptions", "75", "-Z", "360", tempRaw.path, "--out", targetFile.path]
        try? sipsTask.run()
        sipsTask.waitUntilExit()

        // 清理临时生图
        try? FileManager.default.removeItem(at: tempRaw)

        let savedPath = FileManager.default.fileExists(atPath: targetFile.path) ? targetFile.path : nil
        if savedPath != nil {
            AppLogger.shared.log(tag: "SNAPSHOT", message: "离开瞬间快照生成成功: \(targetFile.lastPathComponent)")
        }
        if let ocr = extractedOCRText, !ocr.isEmpty {
            AppLogger.shared.log(tag: "VISION_OCR", message: "✨ Vision 视觉引擎毫秒级穿透屏幕核心文本: [\(ocr.prefix(45))...]")
        }

        return (savedPath, extractedOCRText)
    }

    /// 兼容旧接口
    public func captureSnapshot(sessionId: UUID) -> String? {
        return captureSnapshotWithOCR(sessionId: sessionId).path
    }

    /// 使用 macOS 本地系统原生神经引擎 (Apple Neural Engine / Vision.framework) 进行离线 OCR
    private func performLocalVisionOCR(cgImage: CGImage) -> String? {
        var detectedLines: [String] = []
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNRecognizeTextRequest { req, err in
            defer { semaphore.signal() }
            guard let observations = req.results as? [VNRecognizedTextObservation], !observations.isEmpty else { return }

            // 过滤系统顶栏、极短纯符号以及常见杂项
            let ignoredKeywords = ["File", "Edit", "View", "Window", "Help", "Terminal", "Finder", "Safari", "访达", "编辑", "显示", "窗口", "帮助"]

            for obs in observations {
                guard let candidate = obs.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines),
                      candidate.count >= 2 else { continue }

                if ignoredKeywords.contains(candidate) { continue }
                detectedLines.append(candidate)
            }
        }

        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            _ = semaphore.wait(timeout: .now() + 1.2)
        } catch {
            return nil
        }

        guard !detectedLines.isEmpty else { return nil }

        // 筛选保留前 12 个最重要的文本块，去重并拼接
        var seen = Set<String>()
        var keyBlocks: [String] = []
        for line in detectedLines {
            if !seen.contains(line) {
                seen.insert(line)
                keyBlocks.append(line)
                if keyBlocks.count >= 12 { break }
            }
        }

        return keyBlocks.joined(separator: " ")
    }
}
