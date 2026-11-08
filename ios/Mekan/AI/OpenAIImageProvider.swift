import Foundation

/// OpenAI Images API. With a photo it uses /images/edits so the result keeps the
/// room's viewpoint and geometry; without one it falls back to /images/generations.
struct OpenAIImageProvider: ImageProvider {
    var apiKey: String
    var model: String
    var size = "1024x1536" // portrait, matches the phone photo

    private let base = URL(string: "https://api.openai.com/v1/images/")!

    func redesign(_ request: RedesignRequest) async throws -> Data {
        guard !apiKey.isEmpty else { throw ImageProviderError.missingAPIKey }

        var urlRequest: URLRequest
        if let photo = request.photoJPEG {
            urlRequest = URLRequest(url: base.appendingPathComponent("edits"))
            var form = MultipartForm()
            form.field("model", model)
            form.field("prompt", request.prompt)
            form.field("size", size)
            form.file("image", filename: "room.jpg", mime: "image/jpeg", data: photo)
            urlRequest.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = form.finished
        } else {
            urlRequest = URLRequest(url: base.appendingPathComponent("generations"))
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
                "model": model, "prompt": request.prompt, "size": size,
            ])
        }
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 180
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard (200..<300).contains(status) else {
            let message = (json?["error"] as? [String: Any])?["message"] as? String
            throw ImageProviderError.http(status, message ?? String(decoding: data.prefix(300), as: UTF8.self))
        }
        guard let first = (json?["data"] as? [[String: Any]])?.first else { throw ImageProviderError.badResponse }

        if let b64 = first["b64_json"] as? String, let png = Data(base64Encoded: b64) {
            return png
        }
        if let s = first["url"] as? String, let url = URL(string: s) {
            return try await URLSession.shared.data(from: url).0
        }
        throw ImageProviderError.badResponse
    }
}

private struct MultipartForm {
    private let boundary = "mekan-\(UUID().uuidString)"
    private(set) var body = Data()

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    mutating func field(_ name: String, _ value: String) {
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
    }

    mutating func file(_ name: String, filename: String, mime: String, data: Data) {
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\nContent-Type: \(mime)\r\n\r\n")
        body.append(data)
        append("\r\n")
    }

    var finished: Data {
        var d = body
        d.append(Data("--\(boundary)--\r\n".utf8))
        return d
    }

    private mutating func append(_ s: String) { body.append(Data(s.utf8)) }
}
