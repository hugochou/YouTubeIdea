import Foundation
import AVFoundation

enum AudioSplitterError: LocalizedError {
    case ffmpegNotFound
    case ffmpegNotInitialized
    case ffmpegExecutionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .ffmpegNotFound:
            return """
                找不到 ffmpeg，请按照以下步骤安装：

                1. 打开终端 (Terminal)
                2. 安装 Homebrew (如已安装请跳过)：
                   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                3. 安装 ffmpeg：
                   brew install ffmpeg
                4. 安装完成后重启应用
                """
        case .ffmpegNotInitialized:
            return "ffmpeg 未正确初始化，请重启应用"
        case .ffmpegExecutionFailed(let message):
            return "ffmpeg 执行失败: \(message)"
        }
    }
}

class AudioSplitter {
    static let shared = AudioSplitter()
    private init() {
        // 初始化时查找 ffmpeg 路径
        do {
            ffmpegPath = try findFFmpegPath()
        } catch {
            print("Error finding ffmpeg: \(error)")
        }
    }
    
    // 最大文件大小限制：20MB - 1KB 的安全值
    static let maxFileSize = 20 * 1024 * 1024 - 1024
    private var ffmpegPath: String?
    
    struct AudioSegment {
        let url: URL
        let startTime: Double
        let duration: Double
        let fileSize: Int64
    }
    
    private func findFFmpegPath() throws -> String {
        // 常见的 ffmpeg 安装路径
        let possiblePaths = [
            "/usr/local/bin/ffmpeg",
            "/opt/homebrew/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
        
        // 使用 which 命令查找 ffmpeg
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0,
           let path = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return path
        }
        
        // 检查常见路径
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        throw AudioSplitterError.ffmpegNotFound
    }
    
    // 将音频文件分割成多个片段，确保每个片段不超过大小限制
    func splitAudio(at url: URL) async throws -> [AudioSegment] {
        guard let ffmpegPath = ffmpegPath else {
            throw AudioSplitterError.ffmpegNotInitialized
        }
        
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        var segments: [AudioSegment] = []
        
        // 先检查完整文件大小
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let totalSize = fileAttributes[.size] as? Int64 ?? 0
        
        // 如果文件小于限制，直接返回
        if totalSize <= Self.maxFileSize {
            return [AudioSegment(
                url: url,
                startTime: 0,
                duration: duration,
                fileSize: totalSize
            )]
        }
        
        // 计算需要分割的片段数和每个片段的时长
        let avgBytesPerSecond = Double(totalSize) / duration
        let segmentDuration = Double(Self.maxFileSize) / avgBytesPerSecond * 0.9 // 留10%余量
        let segmentCount = Int(ceil(duration / segmentDuration))
        
        // 使用 ffmpeg 分割文件
        for i in 0..<segmentCount {
            let startTime = Double(i) * segmentDuration
            let currentDuration = min(segmentDuration, duration - startTime)
            
            let segmentURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp3")
            
            // 构建 ffmpeg 命令
            let command = [
                "-i", url.path,
                "-ss", String(format: "%.3f", startTime),
                "-t", String(format: "%.3f", currentDuration),
                "-acodec", "copy",
                "-loglevel", "error",  // 只显示错误信息
                segmentURL.path
            ]
            
            // 执行 ffmpeg 命令
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpegPath)  // 使用找到的 ffmpeg 路径
            process.arguments = command
            
            // 添加错误输出管道
            let errorPipe = Pipe()
            process.standardError = errorPipe
            
            try process.run()
            process.waitUntilExit()
            
            // 检查命令是否成功执行
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw AudioSplitterError.ffmpegExecutionFailed(errorMessage)
            }
            
            // 获取分割后文件的大小
            let attributes = try FileManager.default.attributesOfItem(atPath: segmentURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            segments.append(AudioSegment(
                url: segmentURL,
                startTime: startTime,
                duration: currentDuration,
                fileSize: fileSize
            ))
        }
        
        return segments
    }
}