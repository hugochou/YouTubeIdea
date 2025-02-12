import Foundation

struct TestConfig {
    static let deepseekKey: String = {
        if let key = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] {
            return key
        }
        return "deepseek api key"  // 默认值或测试用的 key
    }()
    
    static let timeout: TimeInterval = 30
} 
