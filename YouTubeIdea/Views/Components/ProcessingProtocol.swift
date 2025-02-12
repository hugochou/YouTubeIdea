import Foundation

protocol ProcessingProtocol {
    var record: VideoRecord { get }
}

extension ProcessingProtocol {
    func updateProcessingStatus(for record: VideoRecord, status: ProcessStatus) async {
        await MainActor.run {
            guard record.isProcessing else { return }
            record.updateStatus(status)
            record.completeProcessing()
        }
    }
    
    // 默认的错误处理实现
    func handleProcessingError(_ error: Error, for record: VideoRecord?) {
        Task { @MainActor in
            if let record = record {
                record.failProcessing(error)
            }
            print("处理错误: \(error.localizedDescription)")
        }
    }
} 