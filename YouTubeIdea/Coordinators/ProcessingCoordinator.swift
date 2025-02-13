import Foundation
import CoreData

class ProcessingCoordinator: ObservableObject {
    private let viewContext: NSManagedObjectContext
    @Published private(set) var currentRecord: VideoRecord?
    @Published private(set) var downloadProgress: Double = 0
    @Published private(set) var errorMessage: String?
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        // 加载上次未完成的记录
        loadUnfinishedRecord()
    }
    
    private func loadUnfinishedRecord() {
        let request = NSFetchRequest<VideoRecord>(entityName: "VideoRecord")
        request.predicate = NSPredicate(format: "statusValue < %d", ProcessStatus.completed.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \VideoRecord.createdAt, ascending: false)]
        request.fetchLimit = 1
        
        if let record = try? viewContext.fetch(request).first {
            currentRecord = record
        }
    }
    
    // 删除记录
    func deleteRecord(_ record: VideoRecord) async {
        let objectID = record.objectID
        let tempURL = record.tempAudioURL
        
        // 创建后台上下文
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        
        await backgroundContext.perform {
            // 1. 获取后台上下文中的记录
            guard let backgroundRecord = try? backgroundContext.existingObject(with: objectID) as? VideoRecord else {
                return
            }
            
            // 2. 删除临时文件
            if let url = tempURL {
                try? FileManager.default.removeItem(at: url)
            }
            
            // 3. 删除记录
            backgroundContext.delete(backgroundRecord)
            
            do {
                try backgroundContext.save()
                
                // 4. 在主线程更新 UI
                Task { @MainActor in
                    // 同步删除结果到主上下文
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: [NSDeletedObjectsKey: [objectID]],
                        into: [self.viewContext]
                    )
                    
                    // 如果删除的是当前记录，清空当前记录
                    if self.currentRecord?.objectID == objectID {
                        self.currentRecord = nil
                    }
                }
            } catch {
                Task { @MainActor in
                    self.errorMessage = "删除失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // 开始新的处理流程
    func startNewProcessing(url: String) async throws {
        print("startNewProcessing")
        
        // 1. 创建新记录
        let record = VideoRecord.createPending(in: viewContext, url: url)
        try viewContext.save()
        
        await MainActor.run {
            self.currentRecord = record
            self.downloadProgress = 0
            self.errorMessage = nil
        }

        // 2. 开始自动处理流程
        try await processRecord(record)

    }
    
    // 继续处理现有记录
    func continueProcessing(_ record: VideoRecord) async throws {
        await MainActor.run {
            self.currentRecord = record
            self.downloadProgress = 0
            self.errorMessage = nil
        }
        
        try await processRecord(record)
    }
    
    // 处理记录的主流程
    private func processRecord(_ record: VideoRecord) async throws {
        do {
            // 1. 下载阶段
            if record.status == .pending {
                try await downloadAudio(for: record)
            }
            
            // 2. 转录阶段
            if record.status == .downloaded {
                try await transcribeAudio(for: record)
            }
            
            // 3. 翻译阶段（如果需要）
            if record.status == .transcribed && record.needsTranslation {
                try await translateText(for: record)
            }
            
            // 4. 润色阶段
            if record.status == .translated {
                try await refineText(for: record)
            }
        } catch {
            await handleError(error, for: record)
        }
    }
    
    // 下载阶段
    private func downloadAudio(for record: VideoRecord) async throws {
        // 所有 UI 更新操作都在一个 MainActor 上下文中
        await MainActor.run {
            record.startProcessing()
            downloadProgress = 0
        }
        
        // 创建进度更新器
        let updateProgress = { @MainActor [self] in
            self.downloadProgress = $0
        }
        
        // 执行下载
        let url = try await APIService.shared.downloadYouTubeAudio(
            from: record.url,
            progressHandler: updateProgress
        )
        
        // 更新状态
        try await MainActor.run {
            record.tempAudioURL = url
            record.updateStatus(.downloaded)
            record.completeProcessing()
            try viewContext.save()
        }
    }
    
    // 转录阶段
    private func transcribeAudio(for record: VideoRecord) async throws {
        guard let audioURL = record.tempAudioURL else {
            throw APIError.invalidResponse("找不到音频文件")
        }
        
        await MainActor.run {
            record.startProcessing()
        }
        
        let transcription = try await APIService.shared.transcribeAudio(from: audioURL)
        
        try await MainActor.run {
            // 1. 更新转录文本和状态
            record.updateTranscription(transcription)
            record.updateStatus(transcription.needsTranslation ? .transcribed : .translated)
            record.completeProcessing()
            
            // 2. 清理音频文件
            try? FileManager.default.removeItem(at: audioURL)
            record.tempAudioURL = nil
            
            // 3. 保存更改
            try viewContext.save()
        }
    }
    
    // 翻译阶段
    private func translateText(for record: VideoRecord) async throws {
        await MainActor.run {
            record.startProcessing()
        }
        
        let translation = try await APIService.shared.translateText(record.transcription)
        
        try await MainActor.run {
            record.updateTranslation(translation)
            record.updateStatus(.translated)
            record.completeProcessing()
            try viewContext.save()
        }
    }
    
    // 润色阶段
    private func refineText(for record: VideoRecord) async throws {
        await MainActor.run {
            record.startProcessing()
        }
        
        // 使用翻译文本或原文本
        let textToRefine = record.translation.isEmpty ? record.transcription : record.translation
        let refined = try await APIService.shared.refineText(textToRefine)
        let tags = extractTags(from: refined)
        
        try await MainActor.run {
            record.updateRefinedText(refined, tags: tags)
            record.updateStatus(.completed)
            record.completeProcessing()
            try viewContext.save()
        }
    }
    
    // 错误处理
    @MainActor
    private func handleError(_ error: Error, for record: VideoRecord) {
        let errorMessage = error.localizedDescription
        self.errorMessage = errorMessage
        record.failProcessing(error)
        try? viewContext.save()
        
        // 显示系统通知
        let notification = NSUserNotification()
        notification.title = "处理出错"
        notification.informativeText = errorMessage
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    // 提取标签
    private func extractTags(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        guard let lastLine = lines.last else { return [] }
        
        return lastLine.components(separatedBy: " ")
            .filter { $0.hasPrefix("#") }
            .map { String($0.dropFirst()) }
    }
} 
