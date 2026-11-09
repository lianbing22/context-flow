import Foundation
import Security

/// macOS 系统级钥匙串 (Keychain) 原生安全存储工具
/// 确保 AI API Key、企业级私有 Token 经由 Apple 硬件级加密保护，杜绝明文落盘 (P0-04)
public final class KeychainHelper: Sendable {
    public static let shared = KeychainHelper()

    private let defaultService = "app.contextflow.ai"
    private let defaultAccount = "primary_api_key"

    private init() {}

    /// 安全存储 API Key 到 macOS Keychain
    @discardableResult
    public func saveApiKey(_ key: String, service: String? = nil, account: String? = nil) -> Bool {
        let s = service ?? defaultService
        let a = account ?? defaultAccount

        // 如果为空，视为删除
        if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return deleteApiKey(service: s, account: a)
        }

        guard let data = key.data(using: .utf8) else { return false }

        // 先尝试删除已有凭据
        deleteApiKey(service: s, account: a)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: s,
            kSecAttrAccount as String: a,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        let success = (status == errSecSuccess)
        if success {
            AppLogger.shared.log(tag: "KEYCHAIN", message: "API Key 已成功加密写入 macOS 系统钥匙串 (Keychain)。")
        } else {
            AppLogger.shared.log(tag: "KEYCHAIN_ERR", message: "写入系统钥匙串失败，OSStatus: \(status)")
        }
        return success
    }

    /// 从 macOS Keychain 安全读取 API Key
    public func loadApiKey(service: String? = nil, account: String? = nil) -> String? {
        let s = service ?? defaultService
        let a = account ?? defaultAccount

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: s,
            kSecAttrAccount as String: a,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// 从 macOS Keychain 移除 API Key
    @discardableResult
    public func deleteApiKey(service: String? = nil, account: String? = nil) -> Bool {
        let s = service ?? defaultService
        let a = account ?? defaultAccount

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: s,
            kSecAttrAccount as String: a
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
