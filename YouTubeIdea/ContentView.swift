//
//  ContentView.swift
//  YouTubeIdea
//
//  Created by Chris‘s MacBook Pro on 2025/2/8.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab: Tab = .home
    @State private var currentRecord: VideoRecord?
    
    enum Tab {
        case home, history, profile
        
        var title: String {
            switch self {
            case .home: return "主页"
            case .history: return "历史记录"
            case .profile: return "我的"
            }
        }
        
        var icon: String {
            switch self {
            case .home: return "house"
            case .history: return "clock"
            case .profile: return "person"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                NavigationLink(value: Tab.home) {
                    Label("主页", systemImage: "house")
                }
                
                NavigationLink(value: Tab.history) {
                    Label("历史记录", systemImage: "clock")
                }
                
                NavigationLink(value: Tab.profile) {
                    Label("我的", systemImage: "person")
                }
            }
            .navigationTitle("YouTube Idea")
        } detail: {
            switch selectedTab {
            case .home:
                HomeView(currentRecord: $currentRecord)
                    .frame(minWidth: 600)
                    .environment(\.managedObjectContext, viewContext)
            case .history:
                HistoryView(
                    selectedTab: $selectedTab,
                    currentRecord: $currentRecord
                )
                    .frame(minWidth: 600)
                    .environment(\.managedObjectContext, viewContext)
            case .profile:
                ProfileView()
                    .frame(minWidth: 600)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
