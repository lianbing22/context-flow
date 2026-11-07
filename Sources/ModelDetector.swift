import Foundation
import Cocoa

/// 本地已发现的模型端点与配置信息
public struct DiscoveredModelService: Identifiable, Sendable {
    public let id = UUID()
    public let name: String           // 例如: "Ollama 本地大模型", "LM Studio", "DeepSeek (环境变量)"
    public let provider: String       // ollama, lmstudio, deepseek, openai, zhipu, custom
    public let baseURL: String        // 例如: http://127.0.0.1:11434/v1
    public let models: [String]       // 探测到的可用模型列表，例如 ["qwen2.5:7b", "deepseek-r1:8b"]
    public let detectedKey: String?   // 探测到的有效 API Key (或 "ollama" 占位)
    public let sourceDescription: String // 例如: "本机 11434 端口响应", "来自 ~/.zshrc 环境变量"
    public let isLocalOffline: Bool   // 是否为完全离线本地模型
}

/// 本地已识别的 AI 软件与开发工具
public struct DiscoveredSoftwareApp: Identifiable, Sendable {
    public let id = UUID()
    public let name: String           // 例如: "Antigravity", "Cursor", "Claude", "Xcode"
    public let bundleId: String
    public let isRunning: Bool
    public let iconName: String
}

/// 综合检测报告
public struct DetectionReport: Sendable {
    public var services: [DiscoveredModelService]
    public var installedApps: [DiscoveredSoftwareApp]
    public var detectedKeysPool: [String] // 聚合所有发现的可用 Key
}

/// 自适应识别本地各种模型和软件，兼容主流模型软件授权与配置探测引擎
public final class ModelDetector: @unchecked Sendable {
    public static let shared = ModelDetector()

    private init() {}

    /// 执行全方位异步并发深度探查
    public func scanAll(completion: @escaping @Sendable (DetectionReport) -> Void) {
        Task {
            var discoveredServices: [DiscoveredModelService] = []
            var foundKeys: [String] = []

            // 1. 并发探测本地运行的大模型端口 (Ollama, LM Studio, vLLM, LocalAI)
            async let ollamaResult = probeOllama()
            async let lmStudioResult = probeLMStudio()
            async let localAIResult = probeLocalAI()
            async let vllmResult = probeVLLM()

            let (ollama, lmStudio, localAI, vllm) = await (ollamaResult, lmStudioResult, localAIResult, vllmResult)
            if let o = ollama { discoveredServices.append(o) }
            if let lm = lmStudio { discoveredServices.append(lm) }
            if let lai = localAI { discoveredServices.append(lai) }
            if let v = vllm { discoveredServices.append(v) }

            // 2. 嗅探环境变量与本地配置 (DEEPSEEK_API_KEY, OPENAI_API_KEY, ZHIPU_API_KEY 等)
            let envServices = scanEnvironmentKeys()
            for s in envServices {
                discoveredServices.append(s)
                if let k = s.detectedKey, !k.isEmpty && !foundKeys.contains(k) {
                    foundKeys.append(k)
                }
            }

            // 3. 扫描本地主流客户端与开发工具
            let detectedApps = scanInstalledAndRunningSoftware()

            let report = DetectionReport(
                services: discoveredServices,
                installedApps: detectedApps,
                detectedKeysPool: foundKeys
            )

            AppLogger.shared.log(tag: "DETECTOR", message: "本地自适应探测完成: 发现 \(discoveredServices.count) 个模型服务/端点，\(foundKeys.count) 个可用密钥，\(detectedApps.count) 个开发/AI软件。")

            completion(report)
        }
    }

    // MARK: - 1. 本地大模型运行时探测

    /// 探测 Ollama (默认端口 11434)
    private func probeOllama() async -> DiscoveredModelService? {
        guard let url = URL(string: "http://127.0.0.1:11434/api/tags") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.2
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

            var modelNames: [String] = []
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                for m in models {
                    if let name = m["name"] as? String {
                        modelNames.append(name)
                    }
                }
            }

            let finalModels = modelNames.isEmpty ? ["qwen2.5:7b", "llama3.2"] : modelNames
            return DiscoveredModelService(
                name: "Ollama 本地大模型",
                provider: "ollama",
                baseURL: "http://127.0.0.1:11434/v1",
                models: finalModels,
                detectedKey: "ollama",
                sourceDescription: "本机 11434 端口在线，已就绪 \(finalModels.count) 个离线模型",
                isLocalOffline: true
            )
        } catch {
            return nil
        }
    }

    /// 探测 LM Studio (默认端口 1234)
    private func probeLMStudio() async -> DiscoveredModelService? {
        guard let url = URL(string: "http://127.0.0.1:1234/v1/models") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.2
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

            var modelNames: [String] = []
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArr = json["data"] as? [[String: Any]] {
                for item in dataArr {
                    if let id = item["id"] as? String {
                        modelNames.append(id)
                    }
                }
            }

            return DiscoveredModelService(
                name: "LM Studio 本地服务",
                provider: "custom",
                baseURL: "http://127.0.0.1:1234/v1",
                models: modelNames.isEmpty ? ["local-model"] : modelNames,
                detectedKey: "lm-studio",
                sourceDescription: "本机 1234 端口在线，加载了 \(modelNames.count) 个模型",
                isLocalOffline: true
            )
        } catch {
            return nil
        }
    }

    /// 探测 LocalAI (默认端口 8080)
    private func probeLocalAI() async -> DiscoveredModelService? {
        guard let url = URL(string: "http://127.0.0.1:8080/v1/models") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0
        request.httpMethod = "GET"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return DiscoveredModelService(
                name: "LocalAI 本地服务",
                provider: "custom",
                baseURL: "http://127.0.0.1:8080/v1",
                models: ["local-model"],
                detectedKey: "localai",
                sourceDescription: "本机 8080 端口在线",
                isLocalOffline: true
            )
        } catch {
            return nil
        }
    }

    /// 探测 vLLM (默认端口 8000)
    private func probeVLLM() async -> DiscoveredModelService? {
        guard let url = URL(string: "http://127.0.0.1:8000/v1/models") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0
        request.httpMethod = "GET"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return DiscoveredModelService(
                name: "vLLM 高并发推理端点",
                provider: "custom",
                baseURL: "http://127.0.0.1:8000/v1",
                models: ["vllm-model"],
                detectedKey: "vllm",
                sourceDescription: "本机 8000 端口在线",
                isLocalOffline: true
            )
        } catch {
            return nil
        }
    }

    // MARK: - 2. 环境变量与主流客户端配置扫描

    private func scanEnvironmentKeys() -> [DiscoveredModelService] {
        var services: [DiscoveredModelService] = []
        let env = ProcessInfo.processInfo.environment

        // 辅助方法：读取 shell 配置中的 export KEY=val
        let shellKeys = readShellProfileKeys()

        // 1. DeepSeek
        if let key = env["DEEPSEEK_API_KEY"] ?? shellKeys["DEEPSEEK_API_KEY"] {
            services.append(DiscoveredModelService(
                name: "DeepSeek (已嗅探到密钥)",
                provider: "deepseek",
                baseURL: "https://api.deepseek.com/v1",
                models: ["deepseek-chat", "deepseek-reasoner"],
                detectedKey: key,
                sourceDescription: "来自本地环境变量 DEEPSEEK_API_KEY",
                isLocalOffline: false
            ))
        }

        // 2. OpenAI
        if let key = env["OPENAI_API_KEY"] ?? shellKeys["OPENAI_API_KEY"] {
            services.append(DiscoveredModelService(
                name: "OpenAI (已嗅探到密钥)",
                provider: "openai",
                baseURL: env["OPENAI_BASE_URL"] ?? "https://api.openai.com/v1",
                models: ["gpt-4o-mini", "gpt-4o"],
                detectedKey: key,
                sourceDescription: "来自本地环境变量 OPENAI_API_KEY",
                isLocalOffline: false
            ))
        }

        // 3. 智谱 BigModel
        if let key = env["ZHIPU_API_KEY"] ?? env["ZHIPUAI_API_KEY"] ?? shellKeys["ZHIPU_API_KEY"] {
            services.append(DiscoveredModelService(
                name: "智谱 GLM (已嗅探到密钥)",
                provider: "zhipu",
                baseURL: "https://open.bigmodel.cn/api/paas/v4",
                models: ["glm-4-flash", "glm-4-plus"],
                detectedKey: key,
                sourceDescription: "来自本地环境变量 ZHIPU_API_KEY",
                isLocalOffline: false
            ))
        }

        // 4. SiliconFlow
        if let key = env["SILICONFLOW_API_KEY"] ?? shellKeys["SILICONFLOW_API_KEY"] {
            services.append(DiscoveredModelService(
                name: "SiliconFlow 硅基流动",
                provider: "siliconflow",
                baseURL: "https://api.siliconflow.cn/v1",
                models: ["Qwen/Qwen2.5-7B-Instruct", "deepseek-ai/DeepSeek-V3"],
                detectedKey: key,
                sourceDescription: "来自本地环境变量 SILICONFLOW_API_KEY",
                isLocalOffline: false
            ))
        }

        return services
    }

    /// 读取用户 `~/.zshrc` / `~/.bash_profile` 中的导出 API 密钥 (无网络开销)
    private func readShellProfileKeys() -> [String: String] {
        var res: [String: String] = [:]
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidateFiles = [".zshrc", ".bash_profile", ".bashrc", ".profile"]

        let targetNames = ["DEEPSEEK_API_KEY", "OPENAI_API_KEY", "ZHIPU_API_KEY", "ZHIPUAI_API_KEY", "SILICONFLOW_API_KEY", "ANTHROPIC_API_KEY"]

        for file in candidateFiles {
            let fileURL = home.appendingPathComponent(file)
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("#") && trimmed.contains("=") else { continue }

                for target in targetNames {
                    if trimmed.contains(target) {
                        let parts = trimmed.components(separatedBy: "=")
                        if parts.count >= 2 {
                            var val = parts[1].trimmingCharacters(in: .whitespaces)
                            val = val.replacingOccurrences(of: "\"", with: "")
                                     .replacingOccurrences(of: "'", with: "")
                            if val.starts(with: "export ") {
                                val = val.replacingOccurrences(of: "export ", with: "")
                            }
                            if val.count > 6 && res[target] == nil {
                                res[target] = val
                            }
                        }
                    }
                }
            }
        }

        return res
    }

    // MARK: - 3. 本地主流 AI 软件与开发者工具识别

    private func scanInstalledAndRunningSoftware() -> [DiscoveredSoftwareApp] {
        let runningApps = NSWorkspace.shared.runningApplications
        let runningBundleIds = Set(runningApps.compactMap { $0.bundleIdentifier })

        let targetApps: [(name: String, bundleId: String, icon: String)] = [
            ("Antigravity", "com.google.antigravity", "sparkles.square.filled.on.square"),
            ("Claude Desktop", "com.anthropic.claudefordesktop", "message.fill"),
            ("Cursor", "com.todesktop.230313mzl4w4u92", "chevron.left.forwardslash.chevron.right"),
            ("Visual Studio Code", "com.microsoft.VSCode", "curlybraces.square.fill"),
            ("Xcode", "com.apple.dt.Xcode", "hammer.fill"),
            ("微信开发者工具", "com.tencent.wechat.devtools", "app.connected.to.app.below.fill"),
            ("Trae", "com.trae.app", "wand.and.stars"),
            ("Windsurf", "com.exafunction.windsurf", "wind"),
            ("ChatGPT", "com.openai.chat", "bubble.left.and.text.bubble.right.fill"),
            ("Chatbox", "xyz.chatboxapp.chatbox", "bubble.middle.bottom.fill"),
            ("Cherry Studio", "com.cherry.studio", "app.gift.fill")
        ]

        var result: [DiscoveredSoftwareApp] = []

        for item in targetApps {
            let isRunning = runningBundleIds.contains(item.bundleId) ||
                runningApps.contains(where: { ($0.localizedName ?? "").lowercased().contains(item.name.lowercased()) })

            // 检查系统中是否存在该应用
            let isInstalled = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleId) != nil || isRunning

            if isInstalled {
                result.append(DiscoveredSoftwareApp(
                    name: item.name,
                    bundleId: item.bundleId,
                    isRunning: isRunning,
                    iconName: item.icon
                ))
            }
        }

        return result
    }
}
