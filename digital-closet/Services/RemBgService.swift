import Foundation
import UIKit

class RemBgService {
    static let shared = RemBgService()
    
    private let apiKey: String
    private let apiURL = "https://api.remove.bg/v1.0/removebg"
    
    private init() {
        // Use ConfigurationManager to get API key
        self.apiKey = ConfigurationManager.shared.getAPIKey(for: .removeBg) ?? ""
    }
    
    func removeBackground(from imageData: Data) async throws -> Data {
        guard !apiKey.isEmpty else {
            throw RemBgError.missingAPIKey
        }
        
        guard let url = URL(string: apiURL) else {
            throw RemBgError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let httpBody = createMultipartBody(imageData: imageData, boundary: boundary)
        request.httpBody = httpBody
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemBgError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            return data
        case 400:
            throw RemBgError.badRequest
        case 402:
            throw RemBgError.insufficientCredits
        case 403:
            throw RemBgError.invalidAPIKey
        case 429:
            throw RemBgError.rateLimitExceeded
        default:
            throw RemBgError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    private func createMultipartBody(imageData: Data, boundary: String) -> Data {
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image_file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add size parameter for better quality
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"size\"\r\n\r\n".data(using: .utf8)!)
        body.append("preview\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
}

enum RemBgError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case badRequest
    case insufficientCredits
    case invalidAPIKey
    case rateLimitExceeded
    case serverError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key is missing"
        case .invalidURL:
            return "Invalid remove.bg API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .badRequest:
            return "Invalid image or request"
        case .insufficientCredits:
            return "Insufficient API credits"
        case .invalidAPIKey:
            return "Invalid API key"
        case .rateLimitExceeded:
            return "Too many requests. Please try again later"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
} 