import Foundation
import Security

/// Minimal Keychain wrapper for the API key (stays on device, not in UserDefaults).
enum KeychainStore {
    private static let service = "app.mekan.apikeys"

    static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String, for account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        guard !value.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}

enum AISettings {
    static let openAIKeyAccount = "openai"
    static let modelDefaultsKey = "openai.model"
    /// OpenAI's recommended model when edit precision matters (gpt-image-1 shut down 2026-10-23).
    static let defaultModel = "gpt-image-2.5-sunburst"
    /// Models OpenAI has shut down or is shutting down; saved values are migrated.
    static let retiredModels: Set<String> = ["gpt-image-1", "gpt-image-1.5", "gpt-image-1-mini", "dall-e-2", "dall-e-3"]

    static var model: String {
        let m = (UserDefaults.standard.string(forKey: modelDefaultsKey) ?? "").trimmingCharacters(in: .whitespaces)
        if m.isEmpty || retiredModels.contains(m) {
            UserDefaults.standard.set(defaultModel, forKey: modelDefaultsKey)
            return defaultModel
        }
        return m
    }

    static func provider() -> ImageProvider {
        OpenAIImageProvider(apiKey: KeychainStore.get(openAIKeyAccount) ?? "", model: model)
    }
}
