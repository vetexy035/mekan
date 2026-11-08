import Foundation
import Security
import MekanCore

/// Minimal Keychain wrapper for API keys (stay on device, not in UserDefaults).
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

/// Which service generates designs, plus per-service key and model.
enum AISettings {
    private static let providerKey = "ai.provider"
    /// Models the services have shut down or are shutting down; saved values are migrated.
    static let retiredModels: Set<String> = ["gpt-image-1", "gpt-image-1.5", "gpt-image-1-mini", "dall-e-2", "dall-e-3"]

    static var selected: AIProviderKind {
        get { UserDefaults.standard.string(forKey: providerKey).flatMap(AIProviderKind.init) ?? .pollinations }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: providerKey) }
    }

    /// Keychain account; "openai" keeps keys saved by earlier versions.
    static func keyAccount(_ p: AIProviderKind) -> String { p.rawValue }
    /// "openai.model" is the key earlier versions used.
    private static func modelKey(_ p: AIProviderKind) -> String { "\(p.rawValue).model" }

    static func apiKey(_ p: AIProviderKind) -> String { KeychainStore.get(keyAccount(p)) ?? "" }
    static func setAPIKey(_ key: String, for p: AIProviderKind) {
        KeychainStore.set(key.trimmingCharacters(in: .whitespacesAndNewlines), for: keyAccount(p))
    }

    static func model(_ p: AIProviderKind) -> String {
        let m = (UserDefaults.standard.string(forKey: modelKey(p)) ?? "").trimmingCharacters(in: .whitespaces)
        if m.isEmpty || retiredModels.contains(m) {
            UserDefaults.standard.set(p.defaultModel, forKey: modelKey(p))
            return p.defaultModel
        }
        return m
    }
    static func setModel(_ model: String, for p: AIProviderKind) {
        UserDefaults.standard.set(model.trimmingCharacters(in: .whitespaces), forKey: modelKey(p))
    }

    static func provider() -> ImageProvider {
        let p = selected
        return OpenAIImageProvider(apiKey: apiKey(p), model: model(p), base: p.baseURL, providerName: p.displayName)
    }
}
