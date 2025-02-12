import SwiftUI

struct TranscriptionSection: View, ProcessingProtocol {
    @ObservedObject var record: VideoRecord
    
    private var canTranscribe: Bool {
        record.canProcess(for: .downloaded)
    }
    
    private var shouldShowContent: Bool {
        record.shouldShowContent(for: .downloaded)
    }
    
    var body: some View {
        ProcessingSection(
            record: record,
            title: "AI转录文本",
            content: shouldShowContent ? record.transcription : "",
            targetStatus: .downloaded,
            loadingText: "正在转录音频...",
            canProcess: canTranscribe,
            process: transcribeAudio
        )
    }
    
    private func transcribeAudio() {
        Task { @MainActor in
            record.startProcessing()
            do {
                // 检查音频文件是否存在
                guard let audioURL = record.tempAudioURL else {
                    throw APIError.invalidResponse("找不到音频文件")
                }
                
                let transcription = try await APIService.shared.transcribeAudio(from: audioURL)
                record.updateTranscription(transcription)
                await updateProcessingStatus(for: record, status: .transcribed)
            } catch {
                handleProcessingError(error, for: record)
            }
        }
    }
    
    func process() async throws {
        // 检查音频文件是否存在
        guard let audioURL = record.tempAudioURL else {
            throw APIError.invalidResponse("找不到音频文件")
        }
        
        do {
            let transcription = try await APIService.shared.transcribeAudio(from: audioURL)
            await MainActor.run {
                record.updateTranscription(transcription)
                if transcription.needsTranslation {
                    record.updateStatus(.transcribed)
                } else {
                    record.updateStatus(.translated)
                }
                record.completeProcessing()
            }
        } catch {
            await MainActor.run { 
                record.failProcessing(error)
            }
            throw error
        }
    }
} 