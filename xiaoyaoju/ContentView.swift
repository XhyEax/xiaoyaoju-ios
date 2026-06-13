// ContentView.swift — root TabView（首页 / 典籍 / 易经 / 收藏）+ 启动更新提示
import SwiftUI
import SwiftData

// 更新提示内容（与小程序 config.json update 对齐；version 变更即提示一次）
private let APP_UPDATE = (version: 10500, title: "更新内容", content: "修复闪烁bug，可配置导航栏。")

struct MainTabView: View {
    @AppStorage("seenUpdateVersion") private var seenVersion = 0
    @State private var showUpdate = false

    var body: some View {
        TabView {
            NotesView()
                .tabItem { Label("首页", systemImage: "house.fill") }

            BooksHubView()
                .tabItem { Label("典籍", systemImage: "books.vertical.fill") }

            LookupView()
                .tabItem { Label("易经", image: "TabYi") }

            RecordsView()
                .tabItem { Label("收藏", systemImage: "clock.fill") }
        }
        .onAppear {
            // 首次安装不提示已内置内容；老用户升级到更高版本则提示一次
            if seenVersion == 0 { seenVersion = APP_UPDATE.version }
            else if seenVersion < APP_UPDATE.version { showUpdate = true }
        }
        .alert(APP_UPDATE.title, isPresented: $showUpdate) {
            Button("我知道了") { seenVersion = APP_UPDATE.version }
        } message: {
            Text(APP_UPDATE.content)
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: CastRecord.self, inMemory: true)
}
