import Foundation
import SwiftUI

enum ProcessStatus: Int16 {
    case pending = 1        // 等待下载
    case downloaded = 2     // 等待转录
    case transcribed = 3    // 等待翻译
    case translated = 4     // 等待润色
    case completed = 5      // 已完成
    
    // 静态状态描述
    var description: String {
        switch self {
        case .pending: return "等待下载"
        case .downloaded: return "等待转录"
        case .transcribed: return "等待翻译"
        case .translated: return "等待润色"
        case .completed: return "已完成"
        }
    }
    
    // 处理中的状态描述
    var processingDescription: String {
        switch self {
        case .pending: return "正在下载..."
        case .downloaded: return "正在转录..."
        case .transcribed: return "正在翻译..."
        case .translated: return "正在润色..."
        case .completed: return "已完成"
        }
    }
    
    // UI 相关属性
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .downloaded: return "arrow.down.circle"
        case .transcribed: return "text.bubble"
        case .translated: return "character.book.closed"
        case .completed: return "checkmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .downloaded, .transcribed: return .blue
        case .translated, .completed: return .green
        }
    }
    
    // 流程控制
    var nextStatus: ProcessStatus? {
        switch self {
        case .pending: 
            return .downloaded
        case .downloaded: 
            return .transcribed
        case .transcribed: 
            // 转录完成后，根据是否需要翻译决定下一个状态
            return nil  // 返回 nil，由业务逻辑决定是 translated 还是 completed
        case .translated: 
            return .completed
        case .completed: 
            return nil
        }
    }
    
    var canProcess: Bool {
        self != .completed
    }
    
    // 辅助方法
    func canTransitionTo(_ status: ProcessStatus) -> Bool {
        if status == .pending { return true }  // 允许重置
        return nextStatus == status
    }
    
    var isIntermediate: Bool {
        self != .pending && self != .completed
    }
    
    var canReset: Bool {
        self == .completed || self == .translated
    }
    
    var nextStep: String {
        switch self {
        case .pending: return "下载"
        case .downloaded: return "转录"
        case .transcribed: return "翻译"
        case .translated: return "润色"
        case .completed: return "完成"
        }
    }
    
    var shouldShowProgress: Bool {
        self == .pending
    }
    
    // 添加一个方法来判断是否应该显示内容
    func shouldShowContent(for targetStatus: ProcessStatus) -> Bool {
        self.rawValue > targetStatus.rawValue
    }
    
    // 添加一个方法来判断是否可以处理
    func canProcess(for targetStatus: ProcessStatus) -> Bool {
        self == targetStatus
    }
}

extension ProcessStatus: Comparable {
    static func < (lhs: ProcessStatus, rhs: ProcessStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
} 