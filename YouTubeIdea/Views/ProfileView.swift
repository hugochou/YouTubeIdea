import SwiftUI

struct ProfileView: View {
    @AppStorage("SiliconFlowAPIKey") private var siliconFlowKey: String = ""
    @AppStorage("DeepSeekAPIKey") private var deepseekKey: String = ""
    @State private var isEditingSiliconFlow = false
    @State private var isEditingDeepSeek = false
    @State private var tempSiliconFlowKey: String = ""
    @State private var tempDeepSeekKey: String = ""
    
    var body: some View {
        Form {
            Section(header: Text("Silicon Flow API设置")) {
                APIKeyEditor(
                    title: "Silicon Flow API Key",
                    apiKey: siliconFlowKey,
                    isEditing: $isEditingSiliconFlow,
                    tempKey: $tempSiliconFlowKey,
                    onSave: { siliconFlowKey = tempSiliconFlowKey }
                )
            }
            
            Section(header: Text("DeepSeek API设置")) {
                APIKeyEditor(
                    title: "DeepSeek API Key",
                    apiKey: deepseekKey,
                    isEditing: $isEditingDeepSeek,
                    tempKey: $tempDeepSeekKey,
                    onSave: { deepseekKey = tempDeepSeekKey }
                )
            }
            
            Section {
                Link("获取 Silicon Flow API Key", destination: URL(string: "https://docs.siliconflow.cn")!)
                Link("获取 DeepSeek API Key", destination: URL(string: "https://api-docs.deepseek.com")!)
            }
        }
        .padding()
        .frame(maxWidth: 600)
    }
}

struct APIKeyEditor: View {
    let title: String
    let apiKey: String
    @Binding var isEditing: Bool
    @Binding var tempKey: String
    let onSave: () -> Void
    
    var body: some View {
        if isEditing {
            TextField(title, text: $tempKey)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("保存") {
                    onSave()
                    isEditing = false
                }
                .buttonStyle(.borderedProminent)
                
                Button("取消") {
                    tempKey = apiKey
                    isEditing = false
                }
                .buttonStyle(.bordered)
            }
        } else {
            HStack {
                if apiKey.isEmpty {
                    Text("未设置")
                        .foregroundColor(.secondary)
                } else {
                    Text(apiKey.prefix(8) + "..." + apiKey.suffix(8))
                        .monospaced()
                }
                
                Spacer()
                
                Button("编辑") {
                    tempKey = apiKey
                    isEditing = true
                }
            }
        }
    }
} 