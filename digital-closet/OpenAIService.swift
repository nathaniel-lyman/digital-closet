import Foundation
import UIKit

class OpenAIService {
    static let shared = OpenAIService()
    
    private let apiKey: String
    private let apiURL = "https://api.openai.com/v1/chat/completions"
    
    private init() {
        // Get API key from SecureConfig
        self.apiKey = SecureConfig.openAIKey
        
        // In production, use environment variables or keychain storage
    }
    
    struct ClothingAnalysis: Codable {
        let category: String
        let color: String
        let season: String
    }
    
    func analyzeClothing(imageData: Data) async throws -> ClothingAnalysis {
        guard !apiKey.isEmpty && apiKey != "YOUR_OPENAI_API_KEY" else {
            throw OpenAIError.missingAPIKey
        }
        
        // Convert image to base64
        let base64Image = imageData.base64EncodedString()
        
        // Prepare the request
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4-vision-preview",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a fashion expert analyzing clothing items. Respond ONLY with valid JSON in this exact format: {\"category\": \"category\", \"color\": \"color\", \"season\": \"season\"}. For category, use only: Shirt, Pants, Jacket, Dress, Shoes, or Accessory. For season, use: Spring, Summer, Fall, Winter, or All-Season."
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Analyze this clothing item and provide its category, primary color, and most suitable season."
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)",
                                "detail": "low"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 100,
            "temperature": 0.3
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode)
        }
        
        // Parse the response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }
        
        // Parse the JSON response from the model
        guard let jsonData = content.data(using: .utf8),
              let analysis = try? JSONDecoder().decode(ClothingAnalysis.self, from: jsonData) else {
            throw OpenAIError.parsingError
        }
        
        return analysis
    }
}

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int)
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is missing"
        case .invalidResponse:
            return "Invalid response from OpenAI"
        case .apiError(let code):
            return "OpenAI API error: \(code)"
        case .parsingError:
            return "Failed to parse clothing analysis"
        }
    }
} 