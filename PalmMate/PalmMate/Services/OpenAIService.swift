import Foundation
import UIKit

final class OpenAIService {
    static let defaultModel = "gpt-4o"
    static let imageModel = "gpt-image-1"
    static let modelDefaultsKey = "openai.model"

    struct CompareInvite: Decodable {
        let token: String
        let shareURL: URL
    }

    struct JoinedInviteResult {
        let token: String
        let shareURL: URL?
        let match: PalmMatchReading
        let leftPhoto: UIImage?
    }

    enum ServiceError: LocalizedError {
        case backendUnavailable
        case missingAPIKey
        case imageEncodingFailed
        case invalidResponse
        case parseFailed(String)
        case apiError(String)

        var errorDescription: String? {
            switch self {
            case .backendUnavailable:  return "Backend URL is not configured."
            case .missingAPIKey:       return "The cosmos can't reach OpenAI right now. (No API key configured.)"
            case .imageEncodingFailed: return "Could not prepare the photo for analysis."
            case .invalidResponse:     return "Unexpected response from OpenAI."
            case .parseFailed(let raw): return "The reading came back in an unreadable form. Tap to retry.\n\n\(raw.prefix(200))"
            case .apiError(let msg):   return msg
            }
        }
    }

    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    // MARK: - Solo reading

    func analyzePalm(image: UIImage, identityToken: String? = nil) async throws -> PalmReading {
        if backendBaseURL != nil {
            do {
                return try await analyzePalmViaBackend(image: image, identityToken: identityToken)
            } catch {
                if Config.openAIAPIKey.isEmpty { throw error }
            }
        }
        return try await analyzePalmDirect(image: image)
    }

    // MARK: - Compare reading

    func analyzeMatch(left: UIImage,
                      right: UIImage,
                      leftLabel: String,
                      rightLabel: String,
                      identityToken: String? = nil) async throws -> PalmMatchReading {
        if backendBaseURL != nil {
            do {
                return try await analyzeMatchViaBackend(left: left,
                                                        right: right,
                                                        leftLabel: leftLabel,
                                                        rightLabel: rightLabel,
                                                        identityToken: identityToken)
            } catch {
                if Config.openAIAPIKey.isEmpty { throw error }
            }
        }
        return try await analyzeMatchDirect(left: left, right: right,
                                            leftLabel: leftLabel, rightLabel: rightLabel)
    }

    // MARK: - Invite compare

    func createCompareInvite(left: UIImage,
                             leftLabel: String,
                             identityToken: String? = nil) async throws -> CompareInvite {
        guard let url = backendURL("/v1/invites") else { throw ServiceError.backendUnavailable }
        guard let photo = Self.jpegForUpload(left) else { throw ServiceError.imageEncodingFailed }

        let data = try await postMultipart(
            url: url,
            fields: [
                "leftLabel": leftLabel,
                "identityToken": identityToken ?? "",
            ],
            files: [
                MultipartUpload(fieldName: "photo",
                                filename: "left.jpg",
                                mimeType: "image/jpeg",
                                data: photo),
            ]
        )
        return try JSONDecoder().decode(CompareInvite.self, from: data)
    }

    func joinCompareInvite(token: String,
                           right: UIImage,
                           rightLabel: String,
                           identityToken: String? = nil) async throws -> JoinedInviteResult {
        guard let url = backendURL("/v1/readings/match") else { throw ServiceError.backendUnavailable }
        guard let photo = Self.jpegForUpload(right) else { throw ServiceError.imageEncodingFailed }

        let data = try await postMultipart(
            url: url,
            fields: [
                "inviteToken": token,
                "rightLabel": rightLabel,
                "identityToken": identityToken ?? "",
            ],
            files: [
                MultipartUpload(fieldName: "photo",
                                filename: "right.jpg",
                                mimeType: "image/jpeg",
                                data: photo),
            ]
        )
        let response = try JSONDecoder().decode(BackendJoinInviteResponse.self, from: data)
        return JoinedInviteResult(token: response.token,
                                  shareURL: response.shareURL,
                                  match: response.match,
                                  leftPhoto: response.leftPhoto.flatMap { Self.image(fromDataURL: $0.dataURL) })
    }

    // MARK: - Diagram (image generation)

    /// Generates the line-contour diagram. Used for both solo and match flows
    /// (the prompt itself instructs the model to draw one or two palms).
    func generateDiagram(prompt: String,
                         size: String = "1024x1024",
                         identityToken: String? = nil) async throws -> UIImage {
        if backendBaseURL != nil {
            do {
                return try await generateDiagramViaBackend(prompt: prompt,
                                                           size: size,
                                                           identityToken: identityToken)
            } catch {
                if Config.openAIAPIKey.isEmpty { throw error }
            }
        }
        return try await generateDiagramDirect(prompt: prompt, size: size)
    }

    // MARK: - Backend calls

    private func analyzePalmViaBackend(image: UIImage, identityToken: String?) async throws -> PalmReading {
        guard let url = backendURL("/v1/readings/solo") else { throw ServiceError.backendUnavailable }
        guard let photo = Self.jpegForUpload(image) else { throw ServiceError.imageEncodingFailed }
        let data = try await postMultipart(
            url: url,
            fields: ["identityToken": identityToken ?? ""],
            files: [MultipartUpload(fieldName: "photo", filename: "palm.jpg", mimeType: "image/jpeg", data: photo)]
        )
        let content = String(decoding: data, as: UTF8.self)
        guard let reading = PalmReading.parse(content) else {
            throw ServiceError.parseFailed(content)
        }
        return reading
    }

    private func analyzeMatchViaBackend(left: UIImage,
                                        right: UIImage,
                                        leftLabel: String,
                                        rightLabel: String,
                                        identityToken: String?) async throws -> PalmMatchReading {
        guard let url = backendURL("/v1/readings/match") else { throw ServiceError.backendUnavailable }
        guard let leftPhoto = Self.jpegForUpload(left),
              let rightPhoto = Self.jpegForUpload(right) else {
            throw ServiceError.imageEncodingFailed
        }
        let data = try await postMultipart(
            url: url,
            fields: [
                "leftLabel": leftLabel,
                "rightLabel": rightLabel,
                "identityToken": identityToken ?? "",
            ],
            files: [
                MultipartUpload(fieldName: "leftPhoto", filename: "left.jpg", mimeType: "image/jpeg", data: leftPhoto),
                MultipartUpload(fieldName: "rightPhoto", filename: "right.jpg", mimeType: "image/jpeg", data: rightPhoto),
            ]
        )
        let content = String(decoding: data, as: UTF8.self)
        guard let match = PalmMatchReading.parse(content) else {
            throw ServiceError.parseFailed(content)
        }
        return match
    }

    private func generateDiagramViaBackend(prompt: String,
                                           size: String,
                                           identityToken: String?) async throws -> UIImage {
        guard let url = backendURL("/v1/images/diagram") else { throw ServiceError.backendUnavailable }
        let data = try await postJSON(url: url, body: [
            "prompt": prompt,
            "size": size,
            "identityToken": identityToken ?? "",
        ])
        let response = try JSONDecoder().decode(BackendImageResponse.self, from: data)
        if let b64 = response.b64JSON,
           let bytes = Data(base64Encoded: b64),
           let image = UIImage(data: bytes) {
            return image
        }
        if let url = response.url {
            let (imgData, _) = try await session.data(from: url)
            if let image = UIImage(data: imgData) { return image }
        }
        throw ServiceError.invalidResponse
    }

    // MARK: - Direct OpenAI fallback

    private func analyzePalmDirect(image: UIImage) async throws -> PalmReading {
        let key = try requireKey()

        guard let dataURL = Self.encodeForUpload(image) else {
            throw ServiceError.imageEncodingFailed
        }

        let model = UserDefaults.standard.string(forKey: Self.modelDefaultsKey) ?? Self.defaultModel
        let systemPrompt = SkillLoader.loadPalmReadingSkill()

        let body: [String: Any] = [
            "model": model,
            "temperature": 0.85,
            "max_tokens": 1600,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": [
                    ["type": "text",
                     "text": "Read this palm. Return ONLY a JSON object matching the schema in your instructions. Be specific about what you literally see in the photo."],
                    ["type": "image_url",
                     "image_url": ["url": dataURL, "detail": "high"]]
                ]]
            ]
        ]

        let content = try await postChat(body: body, key: key)
        guard let reading = PalmReading.parse(content) else {
            throw ServiceError.parseFailed(content)
        }
        return reading
    }

    private func analyzeMatchDirect(left: UIImage,
                                    right: UIImage,
                                    leftLabel: String,
                                    rightLabel: String) async throws -> PalmMatchReading {
        let key = try requireKey()

        guard let leftURL = Self.encodeForUpload(left),
              let rightURL = Self.encodeForUpload(right) else {
            throw ServiceError.imageEncodingFailed
        }

        let model = UserDefaults.standard.string(forKey: Self.modelDefaultsKey) ?? Self.defaultModel
        let systemPrompt = SkillLoader.loadPalmCompareSkill()

        let body: [String: Any] = [
            "model": model,
            "temperature": 0.85,
            "max_tokens": 1600,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": [
                    ["type": "text",
                     "text": "Compare these two palms.\nleftLabel: \"\(leftLabel)\"\nrightLabel: \"\(rightLabel)\"\nThe first image is \"\(leftLabel)\". The second image is \"\(rightLabel)\". Return ONLY the JSON object matching the schema in your instructions."],
                    ["type": "image_url",
                     "image_url": ["url": leftURL, "detail": "high"]],
                    ["type": "image_url",
                     "image_url": ["url": rightURL, "detail": "high"]]
                ]]
            ]
        ]

        let content = try await postChat(body: body, key: key)
        guard let match = PalmMatchReading.parse(content) else {
            throw ServiceError.parseFailed(content)
        }
        return match
    }

    private func generateDiagramDirect(prompt: String, size: String) async throws -> UIImage {
        let key = try requireKey()

        let body: [String: Any] = [
            "model": Self.imageModel,
            "prompt": prompt,
            "size": size,
            "n": 1
        ]

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = json["data"] as? [[String: Any]],
              let first = arr.first else {
            throw ServiceError.invalidResponse
        }

        if let b64 = first["b64_json"] as? String, let bytes = Data(base64Encoded: b64),
           let img = UIImage(data: bytes) {
            return img
        }
        if let urlString = first["url"] as? String, let url = URL(string: urlString) {
            let (imgData, _) = try await session.data(from: url)
            if let img = UIImage(data: imgData) { return img }
        }
        throw ServiceError.invalidResponse
    }

    // MARK: - Request helpers

    private var backendBaseURL: URL? { Config.backendBaseURL }

    private func backendURL(_ path: String) -> URL? {
        guard let backendBaseURL else { return nil }
        return URL(string: path, relativeTo: backendBaseURL)?.absoluteURL
    }

    private func postJSON(url: URL, body: [String: String]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 120

        let (data, response) = try await session.data(for: request)
        try validateBackend(response: response, data: data)
        return data
    }

    private func postMultipart(url: URL,
                               fields: [String: String],
                               files: [MultipartUpload]) async throws -> Data {
        let boundary = "PalmMateBoundary-\(UUID().uuidString)"
        var body = Data()

        for (name, value) in fields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }

        for file in files {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.filename)\"\r\n")
            body.append("Content-Type: \(file.mimeType)\r\n\r\n")
            body.append(file.data)
            body.append("\r\n")
        }

        body.append("--\(boundary)--\r\n")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 120

        let (data, response) = try await session.data(for: request)
        try validateBackend(response: response, data: data)
        return data
    }

    private func postChat(body: [String: Any], key: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ServiceError.invalidResponse
        }
        return content
    }

    private static func encodeForUpload(_ image: UIImage) -> String? {
        guard let jpeg = jpegForUpload(image) else { return nil }
        return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
    }

    private static func jpegForUpload(_ image: UIImage) -> Data? {
        guard let resized = image.resizedForUpload(maxDimension: 1280) else { return nil }
        return resized.jpegData(compressionQuality: 0.85)
    }

    private static func image(fromDataURL dataURL: String) -> UIImage? {
        let base64 = dataURL.split(separator: ",", maxSplits: 1).last.map(String.init) ?? dataURL
        guard let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }

    private func requireKey() throws -> String {
        let key = Config.openAIAPIKey
        guard !key.isEmpty else { throw ServiceError.missingAPIKey }
        return key
    }

    private func validateBackend(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
        guard http.statusCode < 400 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = json["error"] as? String {
                throw ServiceError.apiError(msg)
            }
            throw ServiceError.apiError("Backend HTTP \(http.statusCode)")
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
        if http.statusCode >= 400 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = json["error"] as? [String: Any],
               let msg = err["message"] as? String {
                throw ServiceError.apiError(msg)
            }
            throw ServiceError.apiError("HTTP \(http.statusCode)")
        }
    }
}

private struct MultipartUpload {
    let fieldName: String
    let filename: String
    let mimeType: String
    let data: Data
}

private struct BackendImageResponse: Decodable {
    let b64JSON: String?
    let url: URL?
}

private struct BackendJoinInviteResponse: Decodable {
    let token: String
    let shareURL: URL?
    let match: PalmMatchReading
    let leftPhoto: BackendPhoto?
}

private struct BackendPhoto: Decodable {
    let dataURL: String
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}

private extension UIImage {
    func resizedForUpload(maxDimension: CGFloat) -> UIImage? {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
