import SwiftUI
import CoreData

struct HomeView: View {
    @StateObject private var coordinator: ProcessingCoordinator
    @State private var videoURL = ""
    
    init() {
        self._coordinator = StateObject(wrappedValue: ProcessingCoordinator(viewContext: PersistenceController.shared.container.viewContext))
    }
    
    private var canStartProcessing: Bool {
        !videoURL.isEmpty && 
        coordinator.errorMessage == nil && 
        !(coordinator.currentRecord?.isProcessing ?? false)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // URL 输入区域
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    CommonControls.FixedHeightTextField(
                        "请输入YouTube视频链接",
                        text: $videoURL
                    )
                    
                    Button {
                        Task {
                            try await coordinator.startNewProcessing(url: videoURL)
                        }
                    } label: {
                        if coordinator.currentRecord?.isProcessing ?? false {
                            ProgressView()
                                .scaleEffect(0.7)
                                .controlSize(.small)
                        } 
                        Text(coordinator.currentRecord?.status == .pending ? "继续处理" : "开始处理").frame(width: 100)
                    }
                    .buttonStyle(CommonControls.FixedHeightButtonStyle())
                    .disabled(!canStartProcessing)
                }
                
                // 下载进度条
                if coordinator.currentRecord?.status == .pending && 
                   (coordinator.currentRecord?.isProcessing ?? false) {
                    ProgressView(value: coordinator.downloadProgress, total: 100)
                        .tint(coordinator.currentRecord?.statusColor ?? .blue)
                        .padding(.horizontal)
                }
                
                if let error = coordinator.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 16)
            
            // 内容区域
            if let record = coordinator.currentRecord {
                VStack(spacing: 16) {
                    ProcessingSection(
                        record: record,
                        title: "AI转录文本",
                        content: record.shouldShowContent(for: .downloaded) ? record.transcription : "",
                        targetStatus: .downloaded,
                        loadingText: "正在转录音频..."
                    )
                    .frame(maxHeight: .infinity)
                    
                    ProcessingSection(
                        record: record,
                        title: "AI翻译文本",
                        content: record.shouldShowContent(for: .transcribed) ? record.translation : "",
                        targetStatus: .transcribed,
                        loadingText: "正在翻译文本..."
                    )
                    .frame(maxHeight: .infinity)
                    
                    ProcessingSection(
                        record: record,
                        title: "AI润色文本",
                        content: record.shouldShowContent(for: .translated) ? record.refinedText : "",
                        targetStatus: .translated,
                        loadingText: "正在润色文本..."
                    )
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
        .onChange(of: coordinator.currentRecord) { newRecord in
            if let record = newRecord {
                Task {
                    try await coordinator.continueProcessing(record)
                }
            }
            if let url = newRecord?.url {
                videoURL = url
            }
        }
    }
} 
