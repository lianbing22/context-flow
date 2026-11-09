import SwiftUI
import Cocoa

@main
struct RenderV24SettingsApp {
    @MainActor
    static func main() {
        print("==> 开始渲染 V2.4 纯正 macOS 原生设置界面...")
        let brainDir = "/Users/lianb/.gemini/antigravity/brain/939106cc-a6f7-48b1-912c-39d153abcb54"
        let outDir = "/Users/lianb/.gemini/antigravity/scratch/context-flow/docs/screenshots"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

        let targetSize = NSSize(width: 680, height: 620)

        // 1. 渲染数字编年史与 GitHub 归档 (重点验收用户截图反人类排版修复)
        let lifelogView = SettingsView(initialTab: "lifelog")
        renderView(view: lifelogView, size: targetSize, brainPath: "\(brainDir)/verified_04_settings_lifelog.png", outPath: "\(outDir)/settings_lifelog.png")

        // 2. 渲染 AI 记忆与模型参数
        let aiView = SettingsView(initialTab: "ai")
        renderView(view: aiView, size: targetSize, brainPath: "\(brainDir)/verified_02_settings_ai.png", outPath: "\(outDir)/settings_ai.png")

        print("==> V2.4 设置界面渲染保存完毕！")
    }

    @MainActor
    static func renderView<V: View>(view: V, size: NSSize, brainPath: String, outPath: String) {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: brainPath))
            try? png.write(to: URL(fileURLWithPath: outPath))
            print("✓ 已输出高清验证图像: \(brainPath)")
        }
    }
}
