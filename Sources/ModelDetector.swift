import Foundation
import Cocoa

// MARK: - DeepSeek Harness 插件化模型与授权适配器架构
// 借鉴 github.com/deepseek-ai/deepseek-harness 的 "Everything is a Plugin" 核心设计
// 每个模型端点、本地开发软件、以及云端提供商均为独立的可插拔适配器 (Model Adapter Plugin)

/// 插件分类
public enum ModelPluginCategory: String, Sendable, Codable {
    case localRuntime = "local_runtime"       // 本地离线大模型推理端点 (Ollama, LM Studio, vLLM, LocalAI)
    case ideSoftware = "ide_software"         // 本地开发工具与 AI 客户端 (Cursor, Claude Desktop, VS Code, Continue, Aider)
    case cloudProvider = "cloud_provider"     // 主流云端模型授权服务 (DeepSeek, Agnes, Zhipu, Qwen, Kimi, OpenAI)
}

/// 模型服务插件描述实体
public struct ModelServicePlugin: Identifiable, Sendable {
    public let id: String                     // 插件唯一标识符 (例如: "deepseek.official", "ollama.local", "cursor.imported")
    public let name: String                   // 显示名称
    public let category: ModelPluginCategory  // 插件类别
    public let provider: String               // 服务提供商标识 (deepseek, ollama, custom, openai, etc.)
    public let baseURL: String                // 接口基础地址
    public let models: [String]               // 探测到或支持的模型清单
    public let detectedKey: String?           // 自动嗅探或提取到的有效授权凭据 (脱敏展示)
    public let isKeyMasked: String            // 用于 UI 安全展示的掩码
    public let authStatus: String             // 授权状态描述 (例如: "已授权 (来自 Cursor)", "在线无需密钥", "就绪可绑定")
    public let portalURL: String?             // 官方授权/控制台跳转网址
    public let isAvailable: Bool              // 当前是否在线/可用
    public let description: String            // 详细说明

    public init(
        id: String,
        name: String,
        category: ModelPluginCategory,
        provider: String,
        baseURL: String,
        models: [String],
        detectedKey: String? = nil,
        authStatus: String = "未授权",
        portalURL: String? = nil,
        isAvailable: Bool = true,
        description: String = ""
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.provider = provider
        self.baseURL = baseURL
        self.models = models
        self.detectedKey = detectedKey
        if let k = detectedKey, k.count >= 8 {
            let prefix = String(k.prefix(6))
            let suffix = String(k.suffix(4))
            self.isKeyMasked = "\(prefix)••••••••\(suffix)"
        } else if detectedKey != nil {
            self.isKeyMasked = "••••••••"
        } else {
            self.isKeyMasked = "无密钥"
        }
        self.authStatus = authStatus
        self.portalURL = portalURL
        self.isAvailable = isAvailable
        self.description = description
    }
}

/// 本地已识别的软件应用
public struct DiscoveredSoftwareApp: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let bundleId: String
    public let isRunning: Bool
    public let iconName: String
    public let hasConfigImportable: Bool
    public let configPath: String?
}

/// DeepSeek Harness 全景检测与插件装配报告
public struct HarnessDetectionReport: Sendable {
    public var plugins: [ModelServicePlugin]
    public var installedApps: [DiscoveredSoftwareApp]
    public var detectedKeysPool: [String]
    public var summaryText: String
}

// MARK: - ModelPluginHarness: 综合模型插件与授权探测引擎
public final class ModelPluginHarness: @unchecked Sendable {
    public static let shared = ModelPluginHarness()

    private init() {}

    /// 执行全方位异步并发深度探查 (本地模型 + 软件配置 + 环境变量 + 主流提供商)
    public func scanAll(completion: @escaping @Sendable (HarnessDetectionReport) -> Void) {
        Task {
            var plugins: [ModelServicePlugin] = []
            var foundKeys: [String] = []

            // 1. 并发探测本地离线运行环境 (Ollama, LM Studio, vLLM, LocalAI)
            async let ollamaProbe = probeOllamaPlugin()
            async let lmStudioProbe = probeLMStudioPlugin()
            async let vllmProbe = probeVLLMPlugin()
            async let localAIProbe = probeLocalAIPlugin()

            let (ollama, lmStudio, vllm, localAI) = await (ollamaProbe, lmStudioProbe, vllmProbe, localAIProbe)
            if let o = ollama { plugins.append(o) }
            if let lm = lmStudio { plugins.append(lm) }
            if let v = vllm { plugins.append(v) }
            if let lai = localAI { plugins.append(lai) }

            // 2. 扫描并提取本地主流 AI 开发工具中的授权配置 (Cursor, Continue, Aider, Claude Desktop, Roo Code)
            let idePlugins = extractIDEConfigurations()
            for p in idePlugins {
                plugins.append(p)
                if let k = p.detectedKey, !k.isEmpty && !foundKeys.contains(k) {
                    foundKeys.append(k)
                }
            }

            // 3. 扫描本地 Shell 配置与环境变量中的主流模型凭据
            let envPlugins = scanEnvironmentAndShellKeys()
            for p in envPlugins {
                if !plugins.contains(where: { $0.id == p.id }) {
                    plugins.append(p)
                }
                if let k = p.detectedKey, !k.isEmpty && !foundKeys.contains(k) {
                    foundKeys.append(k)
                }
            }

            // 4. 注入主流模型厂商预设插件 (DeepSeek, Agnes, Zhipu, Qwen, Kimi, OpenAI)
            let cloudPresets = buildMainstreamCloudPresets(withExistingKeys: foundKeys)
            for cp in cloudPresets {
                if !plugins.contains(where: { $0.id == cp.id }) {
                    plugins.append(cp)
                }
            }

            // 5. 扫描本地已安装与运行中的开发及 AI 软件
            let detectedApps = scanInstalledAndRunningSoftware()

            let summary = "DeepSeek Harness 探测就绪: 发现 \(plugins.count) 个模型插件与授权通道，\(foundKeys.count) 组安全凭据，\(detectedApps.count) 款本地软件。"
            let report = HarnessDetectionReport(
                plugins: plugins,
                installedApps: detectedApps,
                detectedKeysPool: foundKeys,
                summaryText: summary
            )

            AppLogger.shared.log(tag: "HARNESS", message: summary)
            completion(report)
        }
    }

    // MARK: - 1. 本地离线模型插件探测 (Local Runtime Plugins)

    /// Ollama 本地推理插件 (11434 端口)
    private func probeOllamaPlugin() async -> ModelServicePlugin? {
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

            let finalModels = modelNames.isEmpty ? ["deepseek-r1:8b", "qwen2.5-coder:7b", "llama3.2"] : modelNames
            return ModelServicePlugin(
                id: "ollama.local",
                name: "Ollama 本地推理引擎",
                category: .localRuntime,
                provider: "ollama",
                baseURL: "http://127.0.0.1:11434/v1",
                models: finalModels,
                detectedKey: "ollama-local",
                authStatus: "无需密钥 · 完全离线私有化运行",
                portalURL: "https://ollama.ai",
                isAvailable: true,
                description: "本地 11434 端口在线，已就绪 \(finalModels.count) 个本地离线模型"
            )
        } catch {
            return nil
        }
    }

    /// LM Studio 本地服务插件 (1234 端口)
    private func probeLMStudioPlugin() async -> ModelServicePlugin? {
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

            return ModelServicePlugin(
                id: "lmstudio.local",
                name: "LM Studio 本地引擎",
                category: .localRuntime,
                provider: "custom",
                baseURL: "http://127.0.0.1:1234/v1",
                models: modelNames.isEmpty ? ["local-model"] : modelNames,
                detectedKey: "lm-studio",
                authStatus: "无需密钥 · 本地 API 响应正常",
                portalURL: "https://lmstudio.ai",
                isAvailable: true,
                description: "本机 1234 端口在线，加载了 \(modelNames.count) 个本地量化模型"
            )
        } catch {
            return nil
        }
    }

    /// vLLM 高并发推理插件 (8000 端口)
    private func probeVLLMPlugin() async -> ModelServicePlugin? {
        guard let url = URL(string: "http://127.0.0.1:8000/v1/models") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.0
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return ModelServicePlugin(
                id: "vllm.local",
                name: "vLLM 高并发端点",
                category: .localRuntime,
                provider: "custom",
                baseURL: "http://127.0.0.1:8000/v1",
                models: ["vllm-default"],
                detectedKey: "vllm-key",
                authStatus: "本地端点就绪",
                portalURL: "https://vllm.ai",
                isAvailable: true,
                description: "本机 8000 端口在线"
            )
        } catch {
            return nil
        }
    }

    /// LocalAI 兼容推理插件 (8080 端口)
    private func probeLocalAIPlugin() async -> ModelServicePlugin? {
        guard let url = URL(string: "http://127.0.0.1:8080/v1/models") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.0
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return ModelServicePlugin(
                id: "localai.local",
                name: "LocalAI 本地服务",
                category: .localRuntime,
                provider: "custom",
                baseURL: "http://127.0.0.1:8080/v1",
                models: ["local-model"],
                detectedKey: "localai",
                authStatus: "本地端点就绪",
                portalURL: "https://localai.io",
                isAvailable: true,
                description: "本机 8080 端口在线"
            )
        } catch {
            return nil
        }
    }

    // MARK: - 2. 主流 AI 开发工具与客户端配置扫描与授权导入 (IDE Software Plugins)

    /// 扫描提取 Cursor, Continue, Aider, Claude Desktop, Roo Code 的本地配置
    private func extractIDEConfigurations() -> [ModelServicePlugin] {
        var results: [ModelServicePlugin] = []
        let home = FileManager.default.homeDirectoryForCurrentUser

        // 1. Cursor: 扫描 Cursor 用户设置与全局存储
        let cursorPath = home.appendingPathComponent("Library/Application Support/Cursor/User/settings.json")
        if FileManager.default.fileExists(atPath: cursorPath.path),
           let content = try? String(contentsOf: cursorPath, encoding: .utf8) {
            var foundKey: String? = nil
            if let json = try? JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any] {
                if let k = json["cursor.openaiApiKey"] as? String, !k.isEmpty {
                    foundKey = k
                } else if let k = json["cursor.anthropicApiKey"] as? String, !k.isEmpty {
                    foundKey = k
                }
            }
            results.append(ModelServicePlugin(
                id: "cursor.imported",
                name: "Cursor AI 开发环境",
                category: .ideSoftware,
                provider: "cursor",
                baseURL: "https://api.cursor.com/v1",
                models: ["claude-3-5-sonnet", "cursor-fast", "gpt-4o"],
                detectedKey: foundKey,
                authStatus: foundKey != nil ? "已从 Cursor 配置中安全导入密钥" : "已发现 Cursor 配置文件",
                portalURL: "https://cursor.com",
                isAvailable: true,
                description: "本地已安装 Cursor，支持直接同步已授权模型配置"
            ))
        }

        // 2. Continue: 扫描 ~/.continue/config.json
        let continuePath = home.appendingPathComponent(".continue/config.json")
        if FileManager.default.fileExists(atPath: continuePath.path),
           let content = try? String(contentsOf: continuePath, encoding: .utf8) {
            var extractedModels: [String] = []
            var extractedKey: String? = nil
            var extractedBaseURL = "https://api.openai.com/v1"

            if let json = try? JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any],
               let modelsArr = json["models"] as? [[String: Any]] {
                for m in modelsArr {
                    if let title = m["title"] as? String { extractedModels.append(title) }
                    if extractedKey == nil, let k = m["apiKey"] as? String, !k.isEmpty { extractedKey = k }
                    if let url = m["apiBase"] as? String, !url.isEmpty { extractedBaseURL = url }
                }
            }

            results.append(ModelServicePlugin(
                id: "continue.imported",
                name: "Continue IDE 插件",
                category: .ideSoftware,
                provider: "continue",
                baseURL: extractedBaseURL,
                models: extractedModels.isEmpty ? ["deepseek-chat", "gpt-4o"] : extractedModels,
                detectedKey: extractedKey,
                authStatus: extractedKey != nil ? "已提取 Continue 模型与 API Key" : "已发现 Continue 配置",
                portalURL: "https://continue.dev",
                isAvailable: true,
                description: "已识别 Continue 配置文件，支持一键装配"
            ))
        }

        // 3. Aider: 扫描 ~/.aider.conf.yml
        let aiderPath = home.appendingPathComponent(".aider.conf.yml")
        if FileManager.default.fileExists(atPath: aiderPath.path) {
            results.append(ModelServicePlugin(
                id: "aider.imported",
                name: "Aider 终端协同工具",
                category: .ideSoftware,
                provider: "deepseek",
                baseURL: "https://api.deepseek.com/v1",
                models: ["deepseek/deepseek-chat", "deepseek/deepseek-reasoner"],
                detectedKey: nil,
                authStatus: "已发现 Aider 本地配置文件",
                portalURL: "https://aider.chat",
                isAvailable: true,
                description: "检测到本地 Aider 配置文件 (~/.aider.conf.yml)"
            ))
        }

        // 4. Claude Desktop: 扫描配置
        let claudeDesktopPath = home.appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
        if FileManager.default.fileExists(atPath: claudeDesktopPath.path) {
            results.append(ModelServicePlugin(
                id: "claude.desktop",
                name: "Claude Desktop 客户端",
                category: .ideSoftware,
                provider: "custom",
                baseURL: "https://api.anthropic.com/v1",
                models: ["claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022"],
                detectedKey: nil,
                authStatus: "已探测到 MCP 与客户端配置",
                portalURL: "https://claude.ai",
                isAvailable: true,
                description: "已就绪 Claude Desktop 客户端生态配置"
            ))
        }

        return results
    }

    // MARK: - 3. 环境变量与 Shell Profile 凭据嗅探

    private func scanEnvironmentAndShellKeys() -> [ModelServicePlugin] {
        var services: [ModelServicePlugin] = []
        let env = ProcessInfo.processInfo.environment
        let shellKeys = readShellProfileKeys()

        // 1. DeepSeek 官方
        if let key = env["DEEPSEEK_API_KEY"] ?? shellKeys["DEEPSEEK_API_KEY"] {
            services.append(ModelServicePlugin(
                id: "deepseek.official",
                name: "DeepSeek 官方开放平台 (已嗅探密钥)",
                category: .cloudProvider,
                provider: "deepseek",
                baseURL: "https://api.deepseek.com/v1",
                models: ["deepseek-chat (V3)", "deepseek-reasoner (R1)"],
                detectedKey: key,
                authStatus: "已自动从环境变量提取有效 API Key",
                portalURL: "https://platform.deepseek.com/api_keys",
                isAvailable: true,
                description: "超高性价比推理主力，原生支持 DeepSeek-V3 与 DeepSeek-R1"
            ))
        }

        // 2. OpenAI
        if let key = env["OPENAI_API_KEY"] ?? shellKeys["OPENAI_API_KEY"] {
            services.append(ModelServicePlugin(
                id: "openai.official",
                name: "OpenAI 官方服务 (已嗅探密钥)",
                category: .cloudProvider,
                provider: "openai",
                baseURL: env["OPENAI_BASE_URL"] ?? "https://api.openai.com/v1",
                models: ["gpt-4o-mini", "gpt-4o"],
                detectedKey: key,
                authStatus: "已自动从环境变量提取有效 API Key",
                portalURL: "https://platform.openai.com/api-keys",
                isAvailable: true,
                description: "标准工业级 OpenAI API 端点"
            ))
        }

        // 3. 智谱 BigModel
        if let key = env["ZHIPU_API_KEY"] ?? env["ZHIPUAI_API_KEY"] ?? shellKeys["ZHIPU_API_KEY"] {
            services.append(ModelServicePlugin(
                id: "zhipu.official",
                name: "智谱 BigModel (已嗅探密钥)",
                category: .cloudProvider,
                provider: "zhipu",
                baseURL: "https://open.bigmodel.cn/api/paas/v4",
                models: ["glm-4-flash", "glm-4-plus"],
                detectedKey: key,
                authStatus: "已自动从环境变量提取有效 API Key",
                portalURL: "https://open.bigmodel.cn/usercenter/apikeys",
                isAvailable: true,
                description: "智谱开放平台，GLM-4-Flash 极速低成本"
            ))
        }

        return services
    }

    /// 读取用户 `~/.zshrc` / `~/.bash_profile` 中的导出 API 密钥 (纯本地无开销)
    private func readShellProfileKeys() -> [String: String] {
        var res: [String: String] = [:]
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidateFiles = [".zshrc", ".bash_profile", ".bashrc", ".profile"]
        let targetNames = ["DEEPSEEK_API_KEY", "OPENAI_API_KEY", "ZHIPU_API_KEY", "ZHIPUAI_API_KEY", "SILICONFLOW_API_KEY", "AGNES_API_KEY"]

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

    // MARK: - 4. 主流云端大模型授权通道预设 (Cloud Provider Presets)

    private func buildMainstreamCloudPresets(withExistingKeys keys: [String]) -> [ModelServicePlugin] {
        return [
            ModelServicePlugin(
                id: "deepseek.preset",
                name: "DeepSeek 深度求索 (官方平台)",
                category: .cloudProvider,
                provider: "deepseek",
                baseURL: "https://api.deepseek.com/v1",
                models: ["deepseek-chat", "deepseek-reasoner"],
                detectedKey: keys.first(where: { $0.hasPrefix("sk-") && !$0.contains("agnes") }),
                authStatus: "支持一键打开 DeepSeek 授权获取 Key",
                portalURL: "https://platform.deepseek.com/api_keys",
                isAvailable: true,
                description: "推荐主力模型，支持 DeepSeek-V3 与 R1 满血思考"
            ),
            ModelServicePlugin(
                id: "agnes.preset",
                name: "Agnes 官方智能引擎 (推荐 · 全功能支持)",
                category: .cloudProvider,
                provider: "agnes",
                baseURL: "https://api.agnes-ai.cn/v1",
                models: ["agnes-3.0-flash", "agnes-3.0-pro"],
                detectedKey: keys.first(where: { $0.contains("agnes") }),
                authStatus: "支持多 Key 轮换容灾与专线加速",
                portalURL: "https://agnes-ai.cn",
                isAvailable: true,
                description: "企业级高可用服务，开箱即用支持多密钥轮换池"
            ),
            ModelServicePlugin(
                id: "qwen.preset",
                name: "阿里云 通义千问 (DashScope 百炼)",
                category: .cloudProvider,
                provider: "qwen",
                baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
                models: ["qwen-plus", "qwen-turbo", "qwen-max"],
                detectedKey: nil,
                authStatus: "支持阿里云百炼 API Key 授权",
                portalURL: "https://bailian.console.aliyun.com/?apiKey=1",
                isAvailable: true,
                description: "通义千问系列商业模型，国内超低延迟"
            ),
            ModelServicePlugin(
                id: "kimi.preset",
                name: "月之暗面 Kimi (Moonshot AI)",
                category: .cloudProvider,
                provider: "kimi",
                baseURL: "https://api.moonshot.cn/v1",
                models: ["moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"],
                detectedKey: nil,
                authStatus: "支持 Moonshot 开放平台 API Key",
                portalURL: "https://platform.moonshot.cn/console/api-keys",
                isAvailable: true,
                description: "超长上下文长文本大模型"
            )
        ]
    }

    // MARK: - 5. 本地主流 AI 软件与开发者工具识别

    private func scanInstalledAndRunningSoftware() -> [DiscoveredSoftwareApp] {
        let runningApps = NSWorkspace.shared.runningApplications
        let runningBundleIds = Set(runningApps.compactMap { $0.bundleIdentifier })

        let targetApps: [(name: String, bundleId: String, icon: String, configRel: String?)] = [
            ("Antigravity", "com.google.antigravity", "sparkles.square.filled.on.square", nil),
            ("Cursor", "com.todesktop.230313mzl4w4u92", "chevron.left.forwardslash.chevron.right", "Library/Application Support/Cursor/User/settings.json"),
            ("Claude Desktop", "com.anthropic.claudefordesktop", "message.fill", "Library/Application Support/Claude/claude_desktop_config.json"),
            ("Visual Studio Code", "com.microsoft.VSCode", "curlybraces.square.fill", "Library/Application Support/Code/User/settings.json"),
            ("Xcode", "com.apple.dt.Xcode", "hammer.fill", nil),
            ("微信开发者工具", "com.tencent.wechat.devtools", "app.connected.to.app.below.fill", nil),
            ("Trae", "com.trae.app", "wand.and.stars", nil),
            ("Windsurf", "com.exafunction.windsurf", "wind", nil),
            ("ChatGPT", "com.openai.chat", "bubble.left.and.text.bubble.right.fill", nil),
            ("Chatbox", "xyz.chatboxapp.chatbox", "bubble.middle.bottom.fill", nil),
            ("Cherry Studio", "com.cherry.studio", "app.gift.fill", nil)
        ]

        var result: [DiscoveredSoftwareApp] = []
        let home = FileManager.default.homeDirectoryForCurrentUser

        for item in targetApps {
            let isRunning = runningBundleIds.contains(item.bundleId) ||
                runningApps.contains(where: { ($0.localizedName ?? "").lowercased().contains(item.name.lowercased()) })

            let isInstalled = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleId) != nil || isRunning

            if isInstalled {
                var configFound = false
                var fullConfigPath: String? = nil
                if let rel = item.configRel {
                    let p = home.appendingPathComponent(rel).path
                    if FileManager.default.fileExists(atPath: p) {
                        configFound = true
                        fullConfigPath = p
                    }
                }

                result.append(DiscoveredSoftwareApp(
                    name: item.name,
                    bundleId: item.bundleId,
                    isRunning: isRunning,
                    iconName: item.icon,
                    hasConfigImportable: configFound,
                    configPath: fullConfigPath
                ))
            }
        }

        return result
    }
}

// 兼容别名
public typealias DiscoveredModelService = ModelServicePlugin
public typealias DetectionReport = HarnessDetectionReport
public typealias ModelDetector = ModelPluginHarness
