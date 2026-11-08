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
    case missingAPIKey(String)
    case http(Int, String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            "Ayarlar'dan (dişli simgesi) bir \(provider) anahtarı gir."
        case .http(401, _):
            "Anahtar geçersiz ya da süresi dolmuş. Ayarlar'dan yeni anahtar gir."
        case .http(402, _), .http(403, _):
            "Bakiye yetersiz ya da bu model ücretli. Ayarlar'dan ücretsiz modeli seç veya hesabına bakiye ekle."
        case .http(429, _):
            "Çok sık istek gönderildi. Bir dakika bekleyip tekrar dene."
        case .http(let code, let message):
            "Sunucu hatası (\(code)): \(message)"
        case .badResponse:
            "Sunucudan beklenmeyen yanıt geldi."
        }
    }
}
