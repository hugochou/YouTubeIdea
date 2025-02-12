import SwiftUI
import CoreData

struct HistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
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
    
    // 用于切换到主页的状态
    @Binding var selectedTab: ContentView.Tab
    @Binding var currentRecord: VideoRecord?  // 改用 currentRecord
    
    // 添加复制成功提示
    @State private var showingCopyAlert = false
    @State private var copiedURL = ""
    
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
                    HStack {
                        RecordRow(
                            record: record,
                            currentRecord: $currentRecord,
                            selectedTab: $selectedTab,
                            selectedRecord: $selectedRecord
                        )
                        
                        Spacer()
                        
                        // 添加删除按钮
                        Button(role: .destructive) {
                            deleteRecord(record)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
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
        // 创建一个后台上下文来处理批量删除
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        
        backgroundContext.perform {
            // 获取所有记录的 objectID
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = VideoRecord.fetchRequest()
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            // 配置批量删除请求以返回删除的对象的 ID
            batchDeleteRequest.resultType = .resultTypeObjectIDs
            
            do {
                // 执行批量删除
                let result = try backgroundContext.execute(batchDeleteRequest) as? NSBatchDeleteResult
                let objectIDs = result?.result as? [NSManagedObjectID] ?? []
                
                // 同步删除结果到主上下文
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [viewContext]
                )
            } catch {
                print("清空记录失败: \(error.localizedDescription)")
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
        // 获取需要的信息
        let objectID = record.objectID
        let tempURL = record.tempAudioURL
        
        // 创建后台上下文
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        
        // 在后台上下文中执行删除
        backgroundContext.perform {
            // 1. 获取后台上下文中的记录
            guard let backgroundRecord = try? backgroundContext.existingObject(with: objectID) as? VideoRecord else {
                return
            }
            
            // 2. 删除临时文件
            if let url = tempURL {
                try? FileManager.default.removeItem(at: url)
            }
            
            // 3. 删除记录
            backgroundContext.delete(backgroundRecord)
            
            do {
                // 4. 保存后台上下文
                try backgroundContext.save()
                
                // 5. 在主线程更新 UI
                Task { @MainActor in
                    // 同步删除结果到主上下文
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: [NSDeletedObjectsKey: [objectID]],
                        into: [viewContext]
                    )
                    
                    // 更新 UI 状态
                    if currentRecord?.objectID == objectID {
                        currentRecord = nil
                    }
                    if selectedRecord?.objectID == objectID {
                        selectedRecord = nil
                    }
                }
            } catch {
                print("删除失败: \(error.localizedDescription)")
            }
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
    @Binding var currentRecord: VideoRecord?
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
                    .onTapGesture(count: 2) { // 双击复制
                        copyURL(record.url)
                    }
                    .onLongPressGesture { // 长按复制
                        copyURL(record.url)
                    }
                
                Spacer()
                
                // 只有未完成的记录显示继续处理按钮
                if record.status != .completed {
                    Button {
                        continueProcessing(record)
                    } label: {
                        Text("继续处理")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderless)
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
    
    private func continueProcessing(_ record: VideoRecord) {
        currentRecord = record  // 设置当前记录
        selectedTab = .home     // 切换到主页
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
    HistoryView(selectedTab: .constant(.history), currentRecord: .constant(nil))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 