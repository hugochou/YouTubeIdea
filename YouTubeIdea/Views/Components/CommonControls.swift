import SwiftUI

enum CommonControls {
    /// 固定高度的按钮样式
    struct FixedHeightButtonStyle: ButtonStyle {
        let height: CGFloat
        let font: Font
        
        init(height: CGFloat = 44, font: Font = .system(size: 14)) {
            self.height = height
            self.font = font
        }
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(font)  // 设置字体
                .frame(height: height)
                .background(configuration.isPressed ? Color.accentColor.opacity(0.8) : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(height * 0.136)
        }
    }
    
    /// 固定高度的文本输入框
    struct FixedHeightTextField: View {
        let placeholder: String
        @Binding var text: String
        let height: CGFloat
        
        init(_ placeholder: String, text: Binding<String>, height: CGFloat = 44) {
            self.placeholder = placeholder
            self._text = text
            self.height = height
        }
        
        var body: some View {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height * 0.136)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(height: height)
                    .overlay(
                        RoundedRectangle(cornerRadius: height * 0.136)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, height * 0.182)  // 水平内边距为高度的 18.2%
            }
        }
    }
    
    /// 固定高度的主要操作按钮
    struct PrimaryButton: View {
        let title: String
        let width: CGFloat?
        let height: CGFloat
        let font: Font
        let isLoading: Bool
        let action: () -> Void
        
        init(
            _ title: String,
            width: CGFloat? = nil,
            height: CGFloat = 44,
            font: Font = .system(size: 17),
            isLoading: Bool = false,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.width = width
            self.height = height
            self.font = font
            self.isLoading = isLoading
            self.action = action
        }
        
        var body: some View {
            Button(action: action) {
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                            .controlSize(.small)
                        Text(title)
                            .lineLimit(1)
                    }
                    .frame(width: width)
                } else {
                    Text(title)
                        .frame(width: width)
                }
            }
            .buttonStyle(FixedHeightButtonStyle(height: height, font: font))
        }
    }
} 
