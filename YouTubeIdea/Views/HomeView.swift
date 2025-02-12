import SwiftUI
import CoreData

struct HomeView: View, ProcessingProtocol {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var videoURL = ""
    @State private var downloadProgress: Double = 0
    @State private var errorMessage: String?
    
    @Binding var currentRecord: VideoRecord?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \VideoRecord.createdAt, ascending: false)],
        predicate: NSPredicate(format: "statusValue != %d", ProcessStatus.completed.rawValue),
        animation: .default
    ) private var unfinishedRecords: FetchedResults<VideoRecord>
    
    private var lastUnfinishedRecord: VideoRecord? {
        unfinishedRecords.first
    }
    
    private var isProcessing: Bool {
        currentRecord?.isProcessing ?? false
    }
    
    private var canStartProcessing: Bool {
        if isProcessing { return false }
        
        if let record = currentRecord {
            return record.status == .completed || 
                   (!record.isProcessing && errorMessage == nil)
        }
        
        return !videoURL.isEmpty && errorMessage == nil
    }
    
    private var statusDescription: String {
        guard let record = currentRecord else { return "" }
        if record.isProcessing {
            return record.currentProcessDescription
        }
        if let error = record.errorMessage {
            return "处理出错: \(error)"
        }
        return "等待\(record.status.nextStep)"
    }
    
    private var buttonTitle: String {
        if isProcessing {
            return currentRecord?.currentProcessDescription ?? "处理中..."
        }
        if let record = currentRecord {
            if record.status == .completed {
                return "重新处理"
            }
            return "继续\(record.status.nextStep)"
        }
        return "开始处理"
    }
    
    private var shouldShowProgress: Bool {
        guard let record = currentRecord else { return false }
        // 只在下载阶段显示进度条
        return record.isProcessing && record.status == .pending
    }
    
    // 添加一个方法来重置主页状态
    private func resetHomeState() {
        currentRecord = nil
        videoURL = ""
        downloadProgress = 0
        errorMessage = nil
    }
    
    // 修改 clearCurrentRecord 方法
    private func clearCurrentRecord() {
        if let record = currentRecord,
           let context = record.managedObjectContext,
           context.registeredObjects.contains(record) {
            // 只有当记录还在 context 中时才删除
            context.delete(record)
            try? context.save()
        }
        
        resetHomeState()  // 使用新的重置方法
    }
    
    // 添加一个方法来检查记录是否还存在
    private func checkCurrentRecord() {
        Task { @MainActor in
            if let record = currentRecord {
                // 检查记录是否还存在于 CoreData 中
                let request = NSFetchRequest<VideoRecord>(entityName: "VideoRecord")
                request.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
                request.fetchLimit = 1
                
                do {
                    let records = try viewContext.fetch(request)
                    if records.isEmpty {
                        // 记录已被删除，清理当前状态
                        clearCurrentRecord()
                    }
                } catch {
                    print("检查记录失败: \(error.localizedDescription)")
                    clearCurrentRecord()
                }
            }
        }
    }
    
    // 添加一个方法来设置当前记录
    private func setCurrentRecord(_ record: VideoRecord, autoStart: Bool = false) {
        Task { @MainActor in
            currentRecord = record
            videoURL = record.url
            // 如果记录有错误，清除错误状态以便继续处理
            if record.errorMessage != nil {
                record.clearError()
            }
            // 只有在 autoStart 为 true 时才自动开始处理
            if autoStart && !record.isProcessing && record.status != .completed {
                continueProcessing(record)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // URL 输入区域 - 固定在顶部
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    CommonControls.FixedHeightTextField(
                        "请输入YouTube视频链接",
                        text: $videoURL
                    )
                    
                    Button {
                        if let record = currentRecord {
                            if record.status == .completed {
                                resetProcessing(record)
                            } else {
                                continueProcessing(record)
                            }
                        } else {
                            handleStartProcessing()
                        }
                    } label: {
                        if isProcessing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .controlSize(.small)
                                Text(buttonTitle)
                                    .lineLimit(1)
                            }
                            .frame(width: 150)
                        } else {
                            Text(buttonTitle)
                                .frame(width: 100)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing || !canStartProcessing)
                    .frame(height: 44)
                }
                
                // 只显示进度条，移除百分比和状态描述
                if shouldShowProgress {
                    ProgressView(value: downloadProgress, total: 100)
                        .tint(currentRecord?.statusColor ?? .blue)
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, 16)
            
            // 内容区域
            if let record = currentRecord {
                // 有记录时，三个文本块等分高度
                VStack(spacing: 16) {
                    TranscriptionSection(record: record)
                        .frame(maxHeight: .infinity)
                    
                    TranslationSection(record: record)
                        .frame(maxHeight: .infinity)
                    
                    RefinementSection(record: record)
                        .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 没有记录时，占满剩余空间
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if currentRecord == nil {
                if let lastRecord = unfinishedRecords.first {
                    // 打开 App 时不自动开始处理
                    setCurrentRecord(lastRecord, autoStart: false)
                } else {
                    // 如果没有未完成的记录，重置主页状态
                    resetHomeState()
                }
            }
        }
        // 添加 videoURL 变化监听
        .onChange(of: videoURL) { newURL in
            // 如果当前记录的 URL 与新输入的不同，清空当前记录
            if let record = currentRecord, record.url != newURL {
                clearCurrentRecord()
            }
        }
        // 添加 currentRecord 变化监听
        .onChange(of: currentRecord) { record in
            if let record = record {
                videoURL = record.url
            }
        }
        // 添加对 unfinishedRecords 的监听
        .onChange(of: unfinishedRecords.count) { count in
            if count == 0 {
                // 如果历史记录被清空，重置主页状态
                resetHomeState()
            }
        }
        .alert("处理错误", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { 
                errorMessage = nil
                // 清除记录的错误状态
                currentRecord?.clearError()
            }}
        )) {
            Button("确定", role: .cancel) {
                errorMessage = nil
                // 清除记录的错误状态
                currentRecord?.clearError()
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    private func canProcess(_ record: VideoRecord) -> Bool {
        guard !isProcessing else { return false }
        
        // 检查记录是否存在
        let request = NSFetchRequest<VideoRecord>(entityName: "VideoRecord")
        request.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let records = try viewContext.fetch(request)
            return !records.isEmpty && record.canStartProcessing
        } catch {
            handleError(error)
            return false
        }
    }
    
    private func continueProcessing(_ record: VideoRecord) {
        Task {
            do {
                // 循环处理直到完成或出错
                while record.status != .completed {
                    // 根据当前状态决定下一步操作
                    switch record.status {
                    case .pending:
                        await MainActor.run { record.startProcessing() }
                        try await startDownload()
                        
                    case .downloaded:
                        await MainActor.run { record.startProcessing() }
                        try await TranscriptionSection(record: record).process()
                        
                    case .transcribed:
                        // 只有需要翻译时才继续
                        if record.needsTranslation {
                            await MainActor.run { record.startProcessing() }
                            try await TranslationSection(record: record).process()
                        } else {
                            // 不需要翻译，直接进入润色
                            await MainActor.run { record.startProcessing() }
                            try await RefinementSection(record: record).process()
                        }
                        
                    case .translated:
                        await MainActor.run { record.startProcessing() }
                        try await RefinementSection(record: record).process()
                        
                    case .completed:
                        break
                    }
                }
            } catch {
                await MainActor.run {
                    handleError(error, for: record)
                    record.endProcessing()
                }
            }
        }
    }
    
    private func handleStartProcessing() {
        guard !videoURL.isEmpty else { return }
        
        Task { @MainActor in
            do {
                // 创建新记录
                let record = VideoRecord.createPending(
                    in: viewContext,
                    url: videoURL
                )
                
                // 先保存记录
                try viewContext.save()
                
                // 设置当前记录
                currentRecord = record
                
                // 开始下载
                try await startDownload()
            } catch {
                // 如果出错，确保在同一个 context 中清理记录
                if let record = currentRecord,
                   let context = record.managedObjectContext,
                   context.registeredObjects.contains(record) {
                    context.delete(record)
                    try? context.save()
                }
                currentRecord = nil
                handleError(error)
            }
        }
    }
    
    private func startDownload() async throws {
        guard let record = currentRecord,
              let context = record.managedObjectContext,
              context.registeredObjects.contains(record) else { 
            throw APIError.invalidResponse("记录已失效")
        }
        
        print("开始下载: \(record.url)")
        
        // 确保在主线程更新 UI 状态
        await MainActor.run {
            downloadProgress = 0
            record.startProcessing()
            try? context.save()
        }
        
        do {
            let url = try await APIService.shared.downloadYouTubeAudio(
                from: videoURL,
                progressHandler: { progress in
                    Task { @MainActor in
                        self.downloadProgress = progress
                    }
                }
            )
            
            // 下载完成，更新状态
            await MainActor.run {
                if context.registeredObjects.contains(record) {
                    record.tempAudioURL = url
                    record.updateStatus(.downloaded)
                    record.completeProcessing()
                    try? context.save()
                }
            }
        } catch {
            await MainActor.run {
                if context.registeredObjects.contains(record) {
                    handleError(error, for: record)
                }
            }
            throw error
        }
    }
    
    private func extractTags(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        guard let lastLine = lines.last else { return [] }
        
        let pattern = #"#([\p{L}0-9_]+)"#
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: lastLine, range: NSRange(location: 0, length: lastLine.utf16.count))
            return matches.compactMap { result in
                guard let range = Range(result.range(at: 1), in: lastLine) else { return nil }
                return String(lastLine[range])
            }
        } catch {
            return []
        }
    }
    
    private func resetProcessing(_ record: VideoRecord) {
        Task { @MainActor in
            // 清理临时文件
            if let url = record.tempAudioURL {
                try? FileManager.default.removeItem(at: url)
            }
            
            // 重置所有状态
            record.transcription = ""
            record.translation = ""
            record.refinedText = ""
            record.tags = []
            record.errorMessage = nil
            record.status = .pending
            record.tempAudioURL = nil
            try? viewContext.save()
            
            // 重新开始处理
            continueProcessing(record)
        }
    }
    
    private func handleError(_ error: Error, for record: VideoRecord? = nil) {
        Task { @MainActor in
            // 先保存错误信息
            let errorMsg = error.localizedDescription
            errorMessage = errorMsg
            
            if let record = record,
               let context = record.managedObjectContext,
               context.registeredObjects.contains(record) {
                record.failProcessing(error)
                try? context.save()
                
                // 如果是下载阶段的错误，需要清理当前记录
                if record.status == .pending {
                    context.delete(record)
                    try? context.save()
                    currentRecord = nil
                }
            }
            
            downloadProgress = 0
        }
    }
    
    // 实现 ProcessingProtocol 要求的属性
    var record: VideoRecord {
        currentRecord ?? VideoRecord(context: viewContext)
    }
    
    func handleProcessingError(_ error: Error, for record: VideoRecord?) {
        Task { @MainActor in
            errorMessage = error.localizedDescription
            if let record = record {
                record.failProcessing(error)
            }
            print("处理错误: \(error.localizedDescription)")
        }
    }
} 
