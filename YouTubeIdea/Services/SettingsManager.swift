import Foundation

class SettingsManager {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    private let siliconFlowKeyKey = "SiliconFlowAPIKey"
    private let deepseekKeyKey = "DeepSeekAPIKey"
    
    private init() {}
    
    var siliconFlowKey: String? {
        get { defaults.string(forKey: siliconFlowKeyKey) }
        set { defaults.set(newValue, forKey: siliconFlowKeyKey) }
    }
    
    var deepseekKey: String? {
        get { defaults.string(forKey: deepseekKeyKey) }
        set { defaults.set(newValue, forKey: deepseekKeyKey) }
    }
    
    var isSiliconFlowKeySet: Bool {
        return siliconFlowKey != nil && !siliconFlowKey!.isEmpty
    }
    
    var isDeepSeekKeySet: Bool {
        return deepseekKey != nil && !deepseekKey!.isEmpty
    }
} 