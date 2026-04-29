import Foundation
import UIKit

final class OpenAIService {
    static let defaultModel = "gpt-4o"
    static let imageModel = "gpt-image-1"
    static let modelDefaultsKey = "openai.model"

    enum ServiceError: LocalizedError {
        case missingAPIKey
        case imageEncodingFailed
        case invalidResponse
        case parseFailed(String)
        case apiError(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:        return "The cosmos can't reach OpenAI right now. (No API key configured.)"
            case .imageEncodingFailed:  return "Could not prepare the photo for analysis."
            case .invalidResponse:      return "Unexpected response from OpenAI."
            case .parseFailed(let raw): return "The reading came back in an unreadable form. Tap to retry.\n\n\(raw.prefix(200))"
            case .apiError(let msg):    return msg
            }
        }
    }

    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    // MARK: - Solo reading

    func analyzePalm(image: UIImage) async throws -> PalmReading {
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

    // MARK: - Compare reading

    func analyzeMatch(left: UIImage,
                      right: UIImage,
                      leftLabel: String,
                      rightLabel: String) async throws -> PalmMatchReading {
        let key = try requireKey()

        guard let leftURL  = Self.encodeForUpload(left),
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

    // MARK: - Diagram (image generation)

    /// Generates the line-contour diagram. Used for both solo and match flows
    /// (the prompt itself instructs the model to draw one or two palms).
    func generateDiagram(prompt: String, size: String = "1024x1024") async throws -> UIImage {
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

    // MARK: - Private helpers

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
        guard let resized = image.resizedForUpload(maxDimension: 1280),
              let jpeg = resized.jpegData(compressionQuality: 0.85) else { return nil }
        return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
    }

    private func requireKey() throws -> String {
        let key = Config.openAIAPIKey
        guard !key.isEmpty else { throw ServiceError.missingAPIKey }
        return key
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
