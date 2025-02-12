import SwiftUI

struct HistoryDetailView: View {
    let record: VideoRecord
    @Environment(\.dismiss) private var dismiss
    @State private var showingCopyAlert = false
    @State private var copiedText = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // 顶部标题栏
            HStack {
                Text(record.title ?? "未命名记录")
                    .font(.headline)
                Spacer()
                Button("关闭") {
                    dismiss()
                }
            }
            .padding()
            
            // 内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 网址
                    DetailSectionView("视频链接") {
                        HStack {
                            Text(record.url)
                                .textSelection(.enabled)
                            Spacer()
                            CopyButton(text: record.url) {
                                copyToClipboard(record.url, label: "链接")
                            }
                        }
                    }
                    
                    // 转录文本
                    if !record.transcription.isEmpty {
                        DetailSectionView("转录文本") {
                            VStack(alignment: .trailing, spacing: 8) {
                                Text(record.transcription)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                CopyButton(text: record.transcription) {
                                    copyToClipboard(record.transcription, label: "转录文本")
                                }
                            }
                        }
                    }
                    
                    // 翻译文本
                    if !record.translation.isEmpty {
                        DetailSectionView("翻译文本") {
                            VStack(alignment: .trailing, spacing: 8) {
                                Text(record.translation)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                CopyButton(text: record.translation) {
                                    copyToClipboard(record.translation, label: "翻译文本")
                                }
                            }
                        }
                    }
                    
                    // 润色文本
                    if !record.refinedText.isEmpty {
                        DetailSectionView("润色文本") {
                            VStack(alignment: .trailing, spacing: 8) {
                                Text(record.refinedText)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                CopyButton(text: record.refinedText) {
                                    copyToClipboard(record.refinedText, label: "润色文本")
                                }
                            }
                        }
                    }
                    
                    // 标签
                    if !record.tags.isEmpty {
                        DetailSectionView("标签") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(record.tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.accentColor.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                    }
                    
                    // 处理时间
                    DetailSectionView("处理时间") {
                        Text(record.createdAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .overlay(
            Group {
                if showingCopyAlert {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("已复制\(copiedText)")
                        }
                        .padding()
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(8)
                        .shadow(radius: 2)
                        .padding(.bottom, 20)
                    }
                }
            }
        )
    }
    
    private func copyToClipboard(_ text: String, label: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedText = label
        showingCopyAlert = true
        
        // 2秒后自动隐藏提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingCopyAlert = false
        }
    }
}

// 详情区块组件
private struct DetailSectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            content
                .padding()
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
        }
    }
}

// 复制按钮组件
private struct CopyButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "doc.on.doc")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .help("复制文本")
    }
} 