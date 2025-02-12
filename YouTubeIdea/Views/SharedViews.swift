import SwiftUI

enum SharedViews {
    struct ContentBox: View {
        let title: String
        let content: String
        let isLoading: Bool
        let loadingText: String?
        let error: String?
        let onRetry: (() -> Void)?
        
        init(
            title: String,
            content: String,
            isLoading: Bool = false,
            loadingText: String? = nil,
            error: String? = nil,
            onRetry: (() -> Void)? = nil
        ) {
            self.title = title
            self.content = content
            self.isLoading = isLoading
            self.loadingText = loadingText
            self.error = error
            self.onRetry = onRetry
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.headline)
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.7)
                            .controlSize(.small)
                        if let text = loadingText {
                            Text(text)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                ScrollView {
                    Text(content)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
                
                if let error = error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                        if let onRetry = onRetry {
                            Button("重试", action: onRetry)
                        }
                    }
                    .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    struct DetailView: View {
        let title: String
        let content: String
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            VStack(spacing: 16) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Button("关闭") {
                        dismiss()
                    }
                }
                .padding()
                
                ScrollView {
                    Text(content)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .frame(minWidth: 600, minHeight: 400)
        }
    }
} 