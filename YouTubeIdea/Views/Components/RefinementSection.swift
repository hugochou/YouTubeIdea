import SwiftUI

struct RefinementSection: View, ProcessingProtocol {
    @ObservedObject var record: VideoRecord
    
    private var canRefine: Bool {
        record.canProcess(for: .translated)
    }
    
    private var shouldShowContent: Bool {
        record.shouldShowContent(for: .translated)
    }
    
    var body: some View {
        ProcessingSection(
            record: record,
            title: "AI润色文本",
            content: shouldShowContent ? record.refinedText : "",
            targetStatus: .translated,
            loadingText: "正在润色文本...",
            canProcess: canRefine,
            process: refineText
        )
    }
    
    private func refineText() {
        Task { @MainActor in
            record.startProcessing()
            do {
                let refined = try await APIService.shared.refineText(record.translation)
                let tags = extractTags(from: refined)
                record.updateRefinedText(refined, tags: tags)
                await updateProcessingStatus(for: record, status: .completed)
            } catch {
                handleProcessingError(error, for: record)
            }
        }
    }
    
    func process() async throws {
        await MainActor.run { record.startProcessing() }
        
        do {
            let refined = try await APIService.shared.refineText(record.translation)
            let tags = extractTags(from: refined)
            await MainActor.run { record.updateRefinedText(refined, tags: tags) }
            await updateProcessingStatus(for: record, status: .completed)
        } catch {
            await handleProcessingError(error, for: record)
            throw error
        }
    }
    
    private func extractTags(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        guard let lastLine = lines.last else { return [] }
        
        let tags = lastLine.components(separatedBy: " ")
            .filter { $0.hasPrefix("#") }
            .map { String($0.dropFirst()) }
        
        return tags.isEmpty ? [] : tags
    }
} 