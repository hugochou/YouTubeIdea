//
//  YouTubeIdeaApp.swift
//  YouTubeIdea
//
//  Created by Chris‘s MacBook Pro on 2025/2/8.
//

import SwiftUI

@main
struct YouTubeIdeaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // 检查是否有正在进行的处理
        if UserDefaults.standard.bool(forKey: "isProcessing") {
            let alert = NSAlert()
            alert.messageText = "正在处理中"
            alert.informativeText = "当前有正在进行的处理任务，确定要终止处理并退出吗？"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "终止并退出")
            alert.addButton(withTitle: "取消")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // 用户选择终止
                // 只清除处理状态标志，保留其他状态
                UserDefaults.standard.set(false, forKey: "isProcessing")
                UserDefaults.standard.set("", forKey: "currentStep")
                return .terminateNow
            } else {
                // 用户取消退出
                return .terminateCancel
            }
        }
        
        return .terminateNow
    }
}
