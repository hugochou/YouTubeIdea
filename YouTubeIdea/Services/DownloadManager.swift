import Foundation

enum DownloadError: LocalizedError {
    case ytDlpNotInstalled
    case invalidYouTubeURL
    case downloadFailed(String)
    case noAudioTrack
    case conversionFailed
    case sandboxError
    
    var errorDescription: String? {
        switch self {
        case .ytDlpNotInstalled:
            return "未安装yt-dlp，请先在终端运行：brew install yt-dlp"
        case .invalidYouTubeURL:
            return "无效的YouTube视频链接"
        case .downloadFailed(let reason):
            return "下载失败: \(reason)"
        case .noAudioTrack:
            return "未找到音频轨道"
        case .conversionFailed:
            return "音频转换失败"
        case .sandboxError:
            return "沙盒权限错误，请检查应用权限设置"
        }
    }
}

class DownloadManager {
    static let shared = DownloadManager()
    private let fileManager = FileManager.default
    
    private init() {
        setupDownloadDirectory()
    }
    
    private var downloadDirectory: URL {
        // 使用应用程序支持目录而不是缓存目录
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("YouTubeIdea/Downloads")
    }
    
    private func setupDownloadDirectory() {
        do {
            // 使用FileManager的urls方法获取应用支持目录
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            let downloadDirURL = appSupportURL.appendingPathComponent("YouTubeIdea/Downloads")
            
            // 检查目录是否存在，不存在则创建
            var isDirectory: ObjCBool = false
            if !fileManager.fileExists(atPath: downloadDirURL.path, isDirectory: &isDirectory) {
                try fileManager.createDirectory(
                    at: downloadDirURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                print("创建下载目录成功：\(downloadDirURL.path)")
            } else if !isDirectory.boolValue {
                // 如果存在但不是目录，则删除并重新创建
                try fileManager.removeItem(at: downloadDirURL)
                try fileManager.createDirectory(
                    at: downloadDirURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                print("重新创建下载目录：\(downloadDirURL.path)")
            }
        } catch {
            print("设置下载目录失败：\(error.localizedDescription)")
        }
    }
    
    private func isExecutable(atPath path: String) -> Bool {
        // 检查文件是否存在且可执行
        guard fileManager.fileExists(atPath: path) else { return false }
        return fileManager.isExecutableFile(atPath: path)
    }
    
    private func executeShellCommand(_ command: String) throws -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                print("命令输出: \(trimmed)")
                
                // 检查命令是否执行成功
                if process.terminationStatus != 0 {
                    print("命令执行失败，退出码: \(process.terminationStatus)")
                    return ""
                }
                
                return trimmed
            }
            return ""
        } catch {
            print("命令执行异常: \(error.localizedDescription)")
            throw DownloadError.downloadFailed("执行命令失败: \(error.localizedDescription)")
        }
    }
    
    private func checkYtDlp() async throws -> String {
        // 检查常见安装路径
        let commonPaths = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp"
        ]
        
        for path in commonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                // 验证可执行性
                do {
                    let output = try await executeCommand("\(path) --version")
                    print("yt-dlp版本: \(output)")
                    return path
                } catch {
                    print("验证 \(path) 失败: \(error)")
                    continue
                }
            }
        }
        
        throw DownloadError.ytDlpNotInstalled
    }
    
    private func executeCommand(_ command: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.launchPath = "/bin/bash"
            process.arguments = ["-c", command]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: DownloadError.downloadFailed(output))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    func downloadYouTubeAudio(from url: String, progressHandler: @escaping (Double) -> Void) async throws -> URL {
//        print("DownloadManager - 开始下载准备")
        
        // 获取 yt-dlp 完整路径
        let ytDlpPath = try await checkYtDlp()
//        print("使用 yt-dlp 路径: \(ytDlpPath)")
        
        // 创建临时文件路径
        let tempDir = FileManager.default.temporaryDirectory
        let outputFileName = UUID().uuidString + ".mp3"
        let outputURL = tempDir.appendingPathComponent(outputFileName)
        
//        print("DownloadManager - 输出路径: \(outputURL.path)")
        
        // 构建下载命令，使用完整路径，指定输出格式为 mp3
        let command = """
        '\(ytDlpPath)' \
        --no-playlist \
        --extract-audio \
        --audio-format mp3 \
        --audio-quality 0 \
        --output '\(outputURL.path)' \
        '\(url)'
        """
        
//        print("DownloadManager - 执行命令: \(command)")
        
        // 执行下载并返回结果
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.launchPath = "/bin/bash"
            process.arguments = ["-c", command]
            
            // 设置环境变量
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = env
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            // 读取输出以更新进度
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8) {
                    // 解析进度信息
                    if let progress = self.parseProgress(from: output) {
                        progressHandler(progress)
                    }
//                    print("下载输出: \(output)")
                }
            }
            
            process.terminationHandler = { process in
                pipe.fileHandleForReading.readabilityHandler = nil
                
                if process.terminationStatus == 0 {
                    // 验证下载的文件
                    do {
                        try self.validateAudioFile(at: outputURL)
                        continuation.resume(returning: outputURL)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume(throwing: DownloadError.downloadFailed("下载失败，状态码: \(process.terminationStatus)"))
                }
            }
            
            do {
                try process.launch()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func parseProgress(from output: String) -> Double? {
        // yt-dlp 的进度输出格式类似：[download] 25.5% of ~50.75MiB at 2.50MiB/s ...
        if let range = output.range(of: #"\[download\]\s+(\d+\.?\d*)%"#, options: .regularExpression),
           let progressStr = output[range].split(separator: " ").last?.dropLast(1),
           let progress = Double(progressStr) {
            return progress
        }
        return nil
    }
    
    private func validateAudioFile(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw DownloadError.downloadFailed("音频文件不存在")
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            
            // 检查文件大小
            guard let fileSize = attributes[.size] as? NSNumber,
                  fileSize.intValue > 0 else {
                throw DownloadError.downloadFailed("音频文件大小异常")
            }
            
            // 检查文件权限
            guard let permissions = attributes[.posixPermissions] as? NSNumber,
                  permissions.intValue & 0o400 != 0 else {  // 检查是否可读
                throw DownloadError.downloadFailed("音频文件权限错误")
            }
            
            // 尝试打开文件
            guard let _ = try? FileHandle(forReadingFrom: url) else {
                throw DownloadError.downloadFailed("无法打开音频文件")
            }
        } catch let error as DownloadError {
            throw error
        } catch {
            throw DownloadError.downloadFailed("验证文件失败: \(error.localizedDescription)")
        }
    }
} 
