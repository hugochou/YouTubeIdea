import Foundation
import AVFoundation

enum APIError: LocalizedError {
    case invalidURL
    case networkError
    case decodingError
    case invalidResponse(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .networkError:
            return "网络连接错误"
        case .decodingError:
            return "数据解析错误"
        case .invalidResponse(let message):
            return message
        }
    }
}

class APIService {
    static let shared = APIService()
    private let siliconFlowURL = "https://api.siliconflow.cn/v1"
    private let deepseekURL = "https://api.deepseek.com/v1"
    
    private var siliconFlowKey: String {
        guard let key = SettingsManager.shared.siliconFlowKey, !key.isEmpty else {
            fatalError("Silicon Flow API Key not set")
        }
        return key
    }
    
    private var deepseekKey: String {
        guard let key = SettingsManager.shared.deepseekKey, !key.isEmpty else {
            fatalError("DeepSeek API Key not set")
        }
        return key
    }
    
    private init() {}
    
    // 下载YouTube视频音频
    func downloadYouTubeAudio(from url: String, progressHandler: @escaping (Double) -> Void) async throws -> URL {
        print("APIService - 开始下载: \(url)")
        return try await DownloadManager.shared.downloadYouTubeAudio(from: url, progressHandler: progressHandler)
    }
    
    // 音频转文字
    func transcribeAudio(from audioURL: URL) async throws -> String {
        print("开始音频转文字，文件路径：\(audioURL.path)")
        
        // 1. 分割音频
        let segments = try await AudioSplitter.shared.splitAudio(at: audioURL)
        var transcriptions: [(startTime: Double, text: String)] = []
        
        // 2. 逐个处理片段
        for segment in segments {
            // 验证片段大小
            guard segment.fileSize <= AudioSplitter.maxFileSize else {
                throw APIError.invalidResponse("音频片段过大：\(segment.fileSize) bytes")
            }
            
            let transcription = try await transcribeSegment(from: segment.url)
            transcriptions.append((segment.startTime, transcription))
            
            // 清理临时文件
            try? FileManager.default.removeItem(at: segment.url)
        }
        
        // 3. 按时间顺序合并结果
        return transcriptions
            .sorted { $0.startTime < $1.startTime }
            .map { $0.text }
            .joined(separator: "\n")
    }
    
    private func transcribeSegment(from url: URL) async throws -> String {
        let request = try createTranscriptionRequest(for: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError
        }
        
        if httpResponse.statusCode == 413 {
            throw APIError.invalidResponse("音频片段过大，请联系开发者")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            try handleAPIError(data, statusCode: httpResponse.statusCode)
            throw APIError.networkError
        }
        
        let transcription = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return transcription.text
    }
    
    // 文字翻译
    func translateText(_ text: String) async throws -> String {
        let url = URL(string: "\(deepseekURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(deepseekKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120  // 保持较长的超时时间
        
        let messages = [
            Message(role: "system", content: "你是一个专业的翻译专家，将用户输入的非中文翻译成中文。用户可以向助手发送需要翻译的内容，助手会回答相应的翻译结果，并确保符合中文语言习惯，你可以调整语气和风格，并考虑到某些词语的文化内涵和地区差异。同时作为翻译家，需将原文翻译成具有信达雅标准的译文。【信】 即忠实于原文的内容与意图；【达】 意味着译文应通顺易懂，表达清晰；【雅】 则追求译文的文化审美和语言的优美。目标是创作出既忠于原作精神，又符合目标语言文化和读者审美的翻译。"),
            Message(role: "user", content: "请翻译成中文（保持原意，使用自然的中文表达）：\n\(text)")
        ]
        
        let body = ChatRequest(
            model: "deepseek-chat",
            messages: messages,
            maxTokens: 8192
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse("翻译服务错误 (\(httpResponse.statusCode))")
            }
        }
        
        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let translation = chatResponse.choices.first?.message.content,
              !translation.isEmpty else {
            throw APIError.invalidResponse("翻译结果为空")
        }
        
        return translation.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    // 文字润色
    func refineText(_ text: String) async throws -> String {
        let url = URL(string: "\(deepseekURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(deepseekKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180  // 保持 3 分钟超时
        
        let prompt = """
        请对以下中文文本进行润色和优化，使其更加流畅自然，并在最后提供三个相关的标签，并以"#标签"的格式展示：
        
        \(text)
        """
        
        let body = ChatRequest(
            model: "deepseek-chat",  // 使用 DeepSeek 的模型
            messages: [
                Message(role: "system", content: "你是一个有趣的灵魂，也是一个专业的文字编辑，擅长优化文本并提供相关标签。你会让文字更加生动有趣，同时保持专业性。"),
                Message(role: "user", content: prompt)
            ],
            maxTokens: 8192  // DeepSeek 支持更大的 token 限制
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("润色服务响应状态码：\(httpResponse.statusCode)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("润色服务错误响应：\(errorString)")
                        // 尝试解析 DeepSeek 的错误格式
                        if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                            let errorMsg = errorResponse.message
                            if httpResponse.statusCode == 504 {
                                throw APIError.invalidResponse("服务暂时繁忙，请稍后重试")
                            }
                            throw APIError.invalidResponse(errorMsg)
                        }
                    }
                    throw APIError.invalidResponse("润色服务暂时不可用，请稍后重试")
                }
            }
            
            // 打印原始响应数据以便调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("润色服务原始响应：\(responseString)")
            }
            
            let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let refinedText = chatResponse.choices.first?.message.content,
                  !refinedText.isEmpty else {
                throw APIError.invalidResponse("润色结果为空")
            }
            
            return refinedText.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("润色处理错误：\(error.localizedDescription)")
            if let apiError = error as? APIError {
                throw apiError
            }
            throw APIError.invalidResponse("润色处理失败，请稍后重试")
        }
    }
    
    private func handleAPIError(_ data: Data, statusCode: Int) throws {
        struct APIErrorResponse: Codable {
            let code: Int
            let message: String
            let data: String?
        }
        
        do {
            let errorResponse = try JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.invalidResponse("服务器错误: \(errorResponse.message)")
        } catch {
            throw APIError.invalidResponse("服务器错误 \(statusCode): \(String(data: data, encoding: .utf8) ?? "未知错误")")
        }
    }
    
    // 添加创建转录请求的方法
    private func createTranscriptionRequest(for url: URL) throws -> URLRequest {
        let apiURL = URL(string: "\(siliconFlowURL)/audio/transcriptions")!
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(siliconFlowKey)", forHTTPHeaderField: "Authorization")
        
        // 创建 multipart/form-data 请求
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        
        // 读取音频文件数据
        let audioData = try Data(contentsOf: url, options: .mappedIfSafe)
        
        // 添加文件数据
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(url.lastPathComponent)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        data.append(audioData)
        data.append("\r\n".data(using: .utf8)!)
        
        // 添加模型参数
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        data.append("FunAudioLLM/SenseVoiceSmall\r\n".data(using: .utf8)!)
        
        // 结束标记
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = data
        return request
    }
}

// API响应模型
struct TranscriptionResponse: Codable {
    let text: String
}

struct ChatRequest: Codable {
    let model: String
    let messages: [Message]
    let max_tokens: Int
    
    init(model: String, messages: [Message], maxTokens: Int = 4096) {
        self.model = model
        self.messages = messages
        self.max_tokens = maxTokens
    }
}

struct Message: Codable {
    let role: String
    let content: String
}

struct ChatResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: Message
}

// 添加错误响应模型
private struct APIErrorResponse: Codable {
    let code: Int
    let message: String
    let data: String?
} 
