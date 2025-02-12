import SwiftUI

struct TranslationSection: View, ProcessingProtocol {
    @ObservedObject var record: VideoRecord
    
    private var canTranslate: Bool {
        record.canProcess(for: .transcribed) && record.needsTranslation
    }
    
    private var shouldShowContent: Bool {
        record.shouldShowContent(for: .transcribed)
    }
    
    var body: some View {
        ProcessingSection(
            record: record,
            title: "AI翻译文本",
            content: shouldShowContent ? record.translation : "",
            targetStatus: .transcribed,
            loadingText: "正在翻译文本...",
            canProcess: canTranslate,
            process: translateText
        )
    }
    
    private func translateText() {
        Task { @MainActor in
            record.startProcessing()
            do {
                let translation = try await APIService.shared.translateText(record.transcription)
                record.updateTranslation(translation)
                await updateProcessingStatus(for: record, status: .translated)
            } catch {
                handleProcessingError(error, for: record)
            }
        }
    }
    
    func process() async throws {
        await MainActor.run { record.startProcessing() }
        
        do {
            let translation = try await APIService.shared.translateText(record.transcription)
            await MainActor.run { record.updateTranslation(translation) }
            await updateProcessingStatus(for: record, status: .translated)
        } catch {
            await handleProcessingError(error, for: record)
            throw error
        }
    }
} 