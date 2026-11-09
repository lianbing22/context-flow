import Foundation
import Cocoa
import Vision
import CoreGraphics

/// 毫秒级单窗口微缩快照与离线视觉神经引擎 (杜绝全屏截取、杜绝时序张冠李戴、严格遵循设置开关)
public final class SnapshotManager: @unchecked Sendable {
    public static let shared = SnapshotManager()

    private let snapshotFolder: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.snapshotFolder = home.appendingPathComponent(".contextflow/snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: snapshotFolder, withIntermediateDirectories: true)
    }

    /// 单窗口原生安全抓取 + macOS 原生 Apple Neural Engine 离线 OCR (P0-03 严格修复)
    /// - Parameters:
    ///   - sessionId: 会话 ID
    ///   - windowId: 离开瞬间的特定窗口 ID (若窗口已销毁或最小化，严禁全屏盲抓)
    ///   - appName: 应用名 (用于隐私黑名单验证)
    ///   - bundleId: Bundle ID
    public func captureWindowSnapshotWithOCR(
        sessionId: UUID,
        windowId: CGWindowID? = nil,
        appName: String? = nil,
        bundleId: String? = nil
    ) -> (path: String?, ocrText: String?) {
        // 1. 严格检查设置中的截图开关 (P0-03)
        let settings = ContextStore.shared.load().settings
        guard settings.enableThumbnails else {
            AppLogger.shared.log(tag: "SNAPSHOT", message: "用户已关闭屏幕快照采集 (enableThumbnails=false)，跳过截图与 OCR。")
            return (nil, nil)
        }

        // 2. 严格检查系统敏感授权窗口与用户隐私黑名单
        if let bId = bundleId, WindowInspector.shared.isSystemOrSecurityProcess(bundleId: bId, appName: appName ?? "") {
            AppLogger.shared.log(tag: "SNAPSHOT", message: "命中系统级安全或隐私应用 [\(bId)]，已彻底阻断截屏。")
            return (nil, nil)
        }

        if let name = appName {
            let nameLower = name.lowercased()
            for ignored in settings.customIgnoredApps {
                let ig = ignored.trimmingCharacters(in: .whitespaces).lowercased()
                if !ig.isEmpty && nameLower.contains(ig) {
                    AppLogger.shared.log(tag: "SNAPSHOT", message: "命中自定义隐私黑名单 [\(name)]，已彻底阻断截屏。")
                    return (nil, nil)
                }
            }
        }

        // 3. 必须通过 CGWindowID 精准捕获单个目标窗口，绝不全屏盲抓 (P0-03: 杜绝新前台应用画面错配给旧会话)
        guard let wid = windowId, wid > 0 else {
            AppLogger.shared.log(tag: "SNAPSHOT", message: "未获取到有效目标窗口 ID，拒绝全屏盲抓以保护隐私。")
            return (nil, nil)
        }

        // 调用 CoreGraphics 高速内存抓取单窗口（无子进程开销、非阻塞、无声音、不弹窗）
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            wid,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            AppLogger.shared.log(tag: "SNAPSHOT", message: "目标窗口 (ID: \(wid)) 已关闭或不可见，安全跳过截图。")
            return (nil, nil)
        }

        // 验证图像尺寸有效性（过滤极小或全透明空白窗口）
        guard cgImage.width > 50 && cgImage.height > 50 else {
            return (nil, nil)
        }

        // 4. 使用本地 Apple Neural Engine (Vision.framework) 执行离线 OCR
        let extractedOCRText = performLocalVisionOCR(cgImage: cgImage)

        // 5. 将单窗口微缩图转为 JPEG 并保存 (内存中纯 Swift 原生压制，无外部命令行依赖)
        let targetFile = snapshotFolder.appendingPathComponent("\(sessionId.uuidString).jpg")
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.72]) {
            try? jpegData.write(to: targetFile)
        }

        let savedPath = FileManager.default.fileExists(atPath: targetFile.path) ? targetFile.path : nil
        if savedPath != nil {
            AppLogger.shared.log(tag: "SNAPSHOT", message: "单窗口离开快照已安全保存: \(targetFile.lastPathComponent)")
        }

        return (savedPath, extractedOCRText)
    }

    /// 兼容旧调用接口 (内部委托单窗口安全引擎)
    public func captureSnapshotWithOCR(sessionId: UUID) -> (path: String?, ocrText: String?) {
        return captureWindowSnapshotWithOCR(sessionId: sessionId, windowId: nil, appName: nil, bundleId: nil)
    }

    public func captureSnapshot(sessionId: UUID) -> String? {
        return captureWindowSnapshotWithOCR(sessionId: sessionId).path
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
