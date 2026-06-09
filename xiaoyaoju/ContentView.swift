// ContentView.swift — root TabView（5 tab：首页/道德经/庄子/易经/收藏历史）
import SwiftUI
import SwiftData

struct MainTabView: View {
    var body: some View {
        TabView {
            NotesView()
                .tabItem { Label("首页", systemImage: "house.fill") }

            DaodejingListView()
                .tabItem { Label("道德经", systemImage: "text.book.closed.fill") }

            ZhuangziListView()
                .tabItem { Label("庄子", systemImage: "books.vertical.fill") }

            LookupView()
                .tabItem { Label("易经", systemImage: "book.closed.fill") }

            RecordsView()
                .tabItem { Label("收藏", systemImage: "clock.fill") }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: CastRecord.self, inMemory: true)
}
