import SwiftUI
import AppKit

struct ProcessingSection: View {
    let record: VideoRecord
    let title: String
    let content: String
    let targetStatus: ProcessStatus
    let loadingText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if record.isProcessing && record.status == targetStatus {
                    ProgressView()
                        .scaleEffect(0.7)
                        .controlSize(.small)
                }
            }
            
            if let error = record.errorMessage, record.status == targetStatus {
                Text("错误: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            TextEditor(text: .constant(content))
                .font(.body)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if record.isProcessing && record.status == targetStatus {
                        VStack {
                            ProgressView()
                            Text(loadingText)
                                .foregroundColor(.secondary)
                        }
                    }
                }
        }
        .padding()
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
} 