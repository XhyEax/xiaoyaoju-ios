// xiaoyaojuApp.swift
import SwiftUI
import SwiftData

@main
struct xiaoyaojuApp: App {
    // 历史记录走 App Group 共享库（与 liuyao 互通）
    var sharedModelContainer: ModelContainer = SharedStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    // 启动时后台预载经文数据，避免首次交互卡顿
                    await GuaDatabase.shared.preload()
                    await ClassicsDatabase.shared.preload()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
