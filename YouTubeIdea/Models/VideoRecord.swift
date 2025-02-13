import Foundation
import CoreData
import SwiftUI

@objc(VideoRecord)
public class VideoRecord: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var url: String
    @NSManaged public var title: String?
    @NSManaged public var transcription: String
    @NSManaged public var translation: String
    @NSManaged public var refinedText: String
    @NSManaged public var createdAt: Date
    @NSManaged public var tags: [String]
    @NSManaged public var statusValue: Int16
    @NSManaged public var errorMessage: String?
    @NSManaged public var audioFilePath: String?  // 添加音频文件路径属性
    
    // 临时存储下载的音频文件 URL
    var tempAudioURL: URL? {
        get {
            guard let path = audioFilePath else { return nil }
            return URL(fileURLWithPath: path)
        }
        set {
            audioFilePath = newValue?.path
        }
    }
    
    // 添加持久化的处理状态
    @NSManaged private var isProcessingValue: Bool
    
    var status: ProcessStatus {
        get { ProcessStatus(rawValue: statusValue) ?? .pending }
        set { statusValue = newValue.rawValue }
    }
    
    var isProcessing: Bool {
        get { isProcessingValue }
        set {
            willChangeValue(forKey: "isProcessing")
            isProcessingValue = newValue
            didChangeValue(forKey: "isProcessing")
        }
    }
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        transcription = ""
        translation = ""
        refinedText = ""
        tags = []
        status = .pending
        errorMessage = nil
        isProcessingValue = false  // 初始化处理状态
    }
    
    func updateError(_ message: String?) {
        dispatchPrecondition(condition: .onQueue(.main))
        errorMessage = message
        try? managedObjectContext?.save()
    }
    
    @MainActor
    func startProcessing() {
        isProcessing = true
        errorMessage = nil
    }
    
    @MainActor
    func updateStatus(_ newStatus: ProcessStatus) {
        statusValue = Int16(newStatus.rawValue)
    }
    
    @MainActor
    func completeProcessing() {
        isProcessing = false
        errorMessage = nil
    }
    
    @MainActor
    func failProcessing(_ error: Error) {
        isProcessing = false
        errorMessage = error.localizedDescription
    }
    
    func clearError() {
        dispatchPrecondition(condition: .onQueue(.main))
        errorMessage = nil
        try? managedObjectContext?.save()
    }
    
    // 添加自动恢复处理逻辑
    func resumeProcessing() {
        guard status != .completed else { return }
        NotificationCenter.default.post(name: .init("ResumeProcessing"), object: id)
    }
    
    func recoverFromError() {
        errorMessage = nil
        isProcessing = false
        // 根据当前状态决定是否需要回退状态
        if status == .transcribed && !transcription.isEmpty {
            status = .downloaded
        }
        try? managedObjectContext?.save()
    }
    
    func logStatusChange(from oldStatus: ProcessStatus, to newStatus: ProcessStatus) {
        print("状态变更: \(oldStatus.description) -> \(newStatus.description)")
        NotificationCenter.default.post(
            name: .init("StatusChanged"),
            object: self,
            userInfo: [
                "oldStatus": oldStatus,
                "newStatus": newStatus
            ]
        )
    }
    
    // 添加音频文件管理方法
    func saveAudioFile(from sourceURL: URL) throws {
        // 创建应用程序的音频文件目录
        let fileManager = FileManager.default
        let audioDir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("AudioFiles", isDirectory: true)
        
        try fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true)
        
        // 创建唯一的文件名
        let fileName = "\(id.uuidString).m4a"
        let destinationURL = audioDir.appendingPathComponent(fileName)
        
        // 如果目标文件已存在，先删除
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // 移动文件到永久存储位置
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
        
        // 更新路径
        tempAudioURL = destinationURL
    }
    
    func deleteAudioFile() {
        if let url = tempAudioURL {
            try? FileManager.default.removeItem(at: url)
            tempAudioURL = nil
        }
    }
    
    // 添加一个方法来清理音频文件
    func cleanupAudioFile() {
        if let url = tempAudioURL {
            try? FileManager.default.removeItem(at: url)
            tempAudioURL = nil
            try? managedObjectContext?.save()
        }
    }
    
    @MainActor
    func updateTranscription(_ text: String) {
        transcription = text
    }
    
    @MainActor
    func updateTranslation(_ text: String) {
        translation = text
    }
    
    @MainActor
    func updateRefinedText(_ text: String, tags: [String]) {
        refinedText = text
        self.tags = tags
    }
    
    var statusDescription: String {
        if isProcessing {
            return "正在\(status.nextStep)"
        } else if let error = errorMessage {
            return "处理出错: \(error)"
        } else {
            return status.description
        }
    }
}

extension VideoRecord {
    static func create(
        in context: NSManagedObjectContext,
        url: String,
        title: String? = nil,
        transcription: String,
        translation: String,
        refinedText: String,
        tags: [String]
    ) -> VideoRecord {
        let record = VideoRecord(context: context)
        record.url = url
        record.title = title
        record.transcription = transcription
        record.translation = translation
        record.refinedText = refinedText
        record.tags = tags
        return record
    }
    
    static func createPending(in context: NSManagedObjectContext, url: String) -> VideoRecord {
        let record = VideoRecord(context: context)
        record.id = UUID()
        record.url = url
        record.createdAt = Date()
        record.status = .pending
        record.isProcessing = false
        return record
    }
    
    // 检查是否可以开始处理
    var canStartProcessing: Bool {
        if isProcessing { return false }
        if let error = errorMessage { return false }
        
        // 如果是等待转录状态，需要检查音频文件是否存在
        if status == .downloaded && tempAudioURL == nil {
            return false
        }
        
        return true
    }
    
    // 检查是否需要翻译
    var needsTranslation: Bool {
        transcription.needsTranslation
    }
    
    // 检查是否可以继续处理
    var canContinueProcessing: Bool {
        if isProcessing { return false }
        if let error = errorMessage { return false }
        
        switch status {
        case .pending:
            return true
        case .downloaded:
            return tempAudioURL != nil
        case .transcribed:
            return !transcription.isEmpty
        case .translated:
            return !translation.isEmpty
        case .completed:
            return false
        }
    }
    
    // 检查是否可以重置
    var canReset: Bool {
        status == .completed || (status != .pending && errorMessage != nil)
    }
    
    var currentProcessDescription: String {
        if isProcessing {
            switch status {
            case .pending:
                return "正在下载..."
            case .downloaded:
                return "正在转录..."
            case .transcribed:
                return "正在翻译..."
            case .translated:
                return "正在润色..."
            case .completed:
                return "已完成"
            }
        } else if let error = errorMessage {
            return "处理出错: \(error)"
        } else {
            return "等待\(status.nextStep)"
        }
    }
    
    var statusIcon: String {
        status.icon
    }
    
    var statusColor: Color {
        if isProcessing {
            return .blue
        }
        if errorMessage != nil {
            return .red
        }
        return status.color
    }
    
    func canTransitionTo(_ status: ProcessStatus) -> Bool {
        self.status.canTransitionTo(status)
    }
    
    // 添加一个方法来检查特定状态的内容是否应该显示
    func shouldShowContent(for targetStatus: ProcessStatus) -> Bool {
        switch targetStatus {
        case .downloaded:
            return !transcription.isEmpty || status > .downloaded
        case .transcribed:
            return !translation.isEmpty || status > .transcribed
        case .translated:
            return !refinedText.isEmpty || status > .translated
        default:
            return false
        }
    }
} 
