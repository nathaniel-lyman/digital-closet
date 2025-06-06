import Foundation

/// Manages API keys and configuration from multiple sources
class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    private init() {}
    
    /// Get API key from environment variables, plist, or SecureConfig
    func getAPIKey(for service: APIService) -> String? {
        // 1. First check environment variables (highest priority)
        if let envKey = getEnvironmentVariable(for: service) {
            return envKey
        }
        
        // 2. Check Config.plist if it exists
        if let plistKey = getPlistValue(for: service) {
            return plistKey
        }
        
        // 3. Fall back to SecureConfig
        return getSecureConfigValue(for: service)
    }
    
    private func getEnvironmentVariable(for service: APIService) -> String? {
        let key = ProcessInfo.processInfo.environment[service.environmentKey]
        return key?.isEmpty == false ? key : nil
    }
    
    private func getPlistValue(for service: APIService) -> String? {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let value = plist[service.environmentKey] as? String,
              !value.isEmpty else {
            return nil
        }
        return value
    }
    
    private func getSecureConfigValue(for service: APIService) -> String? {
        switch service {
        case .openAI:
            return SecureConfig.openAIKey.isEmpty ? nil : SecureConfig.openAIKey
        case .removeBg:
            return SecureConfig.remBgKey.isEmpty ? nil : SecureConfig.remBgKey
        }
    }
}

enum APIService {
    case openAI
    case removeBg
    
    var environmentKey: String {
        switch self {
        case .openAI:
            return "OPENAI_KEY"
        case .removeBg:
            return "REMBG_KEY"
        }
    }
    
    var serviceName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .removeBg:
            return "Remove.bg"
        }
    }
} 