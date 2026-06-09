// xiaoyaojuApp.swift
import SwiftUI
import SwiftData

@main
struct xiaoyaojuApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([CastRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

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
