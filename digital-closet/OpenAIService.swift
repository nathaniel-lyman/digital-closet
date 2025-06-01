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
        
        // Debug: Check API key format (show only first few characters for security)
        let keyPrefix = String(apiKey.prefix(10))
        print("Using OpenAI API key starting with: \(keyPrefix)...")
        
        // Convert image to base64
        let base64Image = imageData.base64EncodedString()
        
        // Prepare the request
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
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
                            "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
                        ]
                    ]
                ]
            ],
            "max_tokens": 100,
            "temperature": 0.3
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("Sending request to OpenAI with model: gpt-4-turbo")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            // Try to get error details from response
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("OpenAI API Error: \(message)")
            }
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