// xiaoyaojuApp.swift
import SwiftUI
import SwiftData

@main
struct xiaoyaojuApp: App {
    // 历史记录走 App Group 共享库（与 liuyao 互通）
    var sharedModelContainer: ModelContainer = SharedStore.makeContainer()
    @AppStorage("appColorScheme") private var colorSchemeIndex = 0

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemeIndex {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(preferredColorScheme)
                .task {
                    // 启动时后台预载经文数据，避免首次交互卡顿
                    await GuaDatabase.shared.preload()
                    await ClassicsDatabase.shared.preload()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
