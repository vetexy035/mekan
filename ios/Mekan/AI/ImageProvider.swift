import Foundation

struct RedesignRequest {
    let prompt: String
    /// JPEG of the room; when nil the provider generates from text only.
    let photoJPEG: Data?
}

protocol ImageProvider {
    /// Returns PNG data of the generated design.
    func redesign(_ request: RedesignRequest) async throws -> Data
}

enum ImageProviderError: LocalizedError {
    case missingAPIKey
    case http(Int, String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "Ayarlar'dan bir OpenAI API anahtarı gir."
        case .http(let code, let message): "Sunucu hatası (\(code)): \(message)"
        case .badResponse: "Sunucudan beklenmeyen yanıt geldi."
        }
    }
}
