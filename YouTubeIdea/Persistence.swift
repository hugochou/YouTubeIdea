//
//  Persistence.swift
//  YouTubeIdea
//
//  Created by Chris‘s MacBook Pro on 2025/2/8.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // 创建一些示例数据
        let record = VideoRecord.create(
            in: context,
            url: "https://youtube.com/example",
            title: "示例视频",
            transcription: "This is a sample transcription",
            translation: "这是一个示例转录文本",
            refinedText: "这是一个经过优化的示例转录文本\n\n标签：示例、测试",
            tags: ["示例", "测试"]
        )
        
        try? context.save()
        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "YouTubeIdea")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
