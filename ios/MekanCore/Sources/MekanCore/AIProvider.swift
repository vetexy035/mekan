import Foundation

/// Image services that speak the OpenAI Images API (`/images/edits`, `/images/generations`).
public enum AIProviderKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case pollinations, openai

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .pollinations: "Pollinations (ücretsiz test)"
        case .openai: "OpenAI"
        }
    }

    public var baseURL: URL {
        switch self {
        case .pollinations: URL(string: "https://gen.pollinations.ai/v1/images/")!
        case .openai: URL(string: "https://api.openai.com/v1/images/")!
        }
    }

    /// Pollinations: free (Quest Pollen) model that edits photos. OpenAI: recommended for edit precision.
    public var defaultModel: String {
        switch self {
        case .pollinations: "microsoft/mai-image-2.6-flash"
        case .openai: "gpt-image-2.5-sunburst"
        }
    }

    /// Where the user creates a key.
    public var keyPageURL: URL {
        switch self {
        case .pollinations: URL(string: "https://enter.pollinations.ai/keys")!
        case .openai: URL(string: "https://platform.openai.com/api-keys")!
        }
    }

    private var keyPrefix: String {
        switch self {
        case .pollinations: "sk_"
        case .openai: "sk-"
        }
    }

    /// Recognizes a copied secret key and which service it belongs to.
    public static func detect(key raw: String) -> AIProviderKind? {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count >= 20, !key.contains(where: \.isWhitespace) else { return nil }
        return allCases.first { key.hasPrefix($0.keyPrefix) }
    }
}
