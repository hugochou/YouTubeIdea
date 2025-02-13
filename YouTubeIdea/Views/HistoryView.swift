import SwiftUI
import CoreData

struct HistoryView: View {
    @StateObject private var coordinator: ProcessingCoordinator
    @FetchRequest(
        entity: VideoRecord.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \VideoRecord.createdAt, ascending: false)],
        animation: .default)
    private var records: FetchedResults<VideoRecord>
    
    @State private var searchText = ""
    @State private var selectedRecord: VideoRecord?
    @State private var showingDeleteAlert = false
    @State private var recordToDelete: VideoRecord?
    @State private var showingClearAllAlert = false
    
    // 只保留切换标签页的状态
    @Binding var selectedTab: ContentView.Tab
    
    // 添加复制成功提示
    @State private var showingCopyAlert = false
    @State private var copiedURL = ""
    
    init(selectedTab: Binding<ContentView.Tab>) {
        self._selectedTab = selectedTab
        self._coordinator = StateObject(wrappedValue: ProcessingCoordinator(viewContext: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        VStack {
            // 工具栏
            HStack {
                SearchField("搜索历史记录", text: $searchText)
                    .frame(maxWidth: 300)
                
                Spacer()
                
                Button(role: .destructive) {
                    showingClearAllAlert = true
                } label: {
                    Label("清空记录", systemImage: "trash")
                }
                .disabled(records.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // 记录列表
            List {
                ForEach(filteredRecords, id: \.id) { record in
                    RecordRow(
                        record: record,
                        onContinue: coordinator.continueProcessing,
                        onDelete: coordinator.deleteRecord,
                        selectedTab: $selectedTab,
                        selectedRecord: $selectedRecord
                    )
                }
            }
        }
        .navigationTitle("历史记录")
        // 添加复制成功提示
        .overlay(
            Group {
                if showingCopyAlert {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("已复制链接")
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
        .sheet(item: $selectedRecord) { record in
            HistoryDetailView(record: record)
                .frame(minWidth: 600, minHeight: 400)
        }
        .alert("确认删除", isPresented: $showingDeleteAlert, presenting: recordToDelete) { record in
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteRecord(record)
            }
        } message: { record in
            Text("确定要删除这条记录吗？此操作不可撤销。")
        }
        .alert("清空所有记录", isPresented: $showingClearAllAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                clearAllRecords()
            }
        } message: {
            Text("确定要清空所有历史记录吗？此操作不可撤销。")
        }
    }
    
    private func clearAllRecords() {
        for record in records {
            Task {
                await coordinator.deleteRecord(record)
            }
        }
    }
    
    private var filteredRecords: [VideoRecord] {
        if searchText.isEmpty {
            return Array(records)
        }
        return records.filter { record in
            record.title?.localizedCaseInsensitiveContains(searchText) ?? false ||
            record.transcription.localizedCaseInsensitiveContains(searchText) ||
            record.translation.localizedCaseInsensitiveContains(searchText) ||
            record.refinedText.localizedCaseInsensitiveContains(searchText) ||
            record.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private func deleteRecord(_ record: VideoRecord) {
        Task {
            await coordinator.deleteRecord(record)
        }
    }
    
    private func copyURL(_ url: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        copiedURL = url
        showingCopyAlert = true
        
        // 2秒后自动隐藏提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingCopyAlert = false
        }
    }
}

struct RecordRow: View {
    let record: VideoRecord
    let onContinue: (VideoRecord) async throws -> Void
    let onDelete: (VideoRecord) async -> Void
    @Binding var selectedTab: ContentView.Tab
    @Binding var selectedRecord: VideoRecord?
    
    // 添加复制相关的状态
    @State private var showingCopyAlert = false
    @State private var copiedURL = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.title ?? record.url)
                    .font(.headline)
                    .onTapGesture(count: 2) { copyURL(record.url) }
                    .onLongPressGesture { copyURL(record.url) }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if record.status != .completed {
                        Button {
                            Task {
                                try await onContinue(record)
                                selectedTab = .home
                            }
                        } label: {
                            Text("继续处理")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    // 删除按钮
                    Button(role: .destructive) {
                        Task {
                            await onDelete(record)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if !record.transcription.isEmpty {
                Text(record.transcription)
                    .lineLimit(2)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(record.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(record.status.description)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(record.status.color.opacity(0.1))
                    .foregroundColor(record.status.color)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())  // 使整个区域可点击
        .onTapGesture {
            selectedRecord = record
        }
        // 添加复制成功提示
        .overlay(
            Group {
                if showingCopyAlert {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("已复制链接")
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
    
    private func copyURL(_ url: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        copiedURL = url
        showingCopyAlert = true
        
        // 2秒后自动隐藏提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingCopyAlert = false
        }
    }
}

struct SearchField: View {
    let placeholder: String
    @Binding var text: String
    
    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    HistoryView(selectedTab: .constant(.history))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 
