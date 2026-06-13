// ContentView.swift — root TabView（首页 + 可配置 1-3 本典籍 + 收藏）+ 启动更新提示
import SwiftUI
import SwiftData

// 更新提示内容（与小程序 config.json update 对齐；version 变更即提示一次）
private let APP_UPDATE = (version: 10500, title: "更新内容", content: "修复闪烁bug，可配置导航栏。")

struct MainTabView: View {
    @AppStorage("tabBooks") private var tabBooksRaw = "ddj,zz,yj"
    @AppStorage("seenUpdateVersion") private var seenVersion = 0
    @State private var showUpdate = false

    private var db: ClassicsDatabase { .shared }
    private var books: [String] { parseTabBooks(tabBooksRaw) }

    var body: some View {
        TabView {
            NotesView()
                .tabItem { Label("首页", image: "TabNotes") }

            ForEach(books, id: \.self) { id in
                bookTab(id)
            }

            RecordsView()
                .tabItem { Label("收藏", image: "TabRecords") }
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

    // 单个典籍 tab：阅读类 → 书目；易经 → 64 卦工具。图标用书名文字。
    @ViewBuilder
    private func bookTab(_ id: String) -> some View {
        if let meta = db.meta(id) {
            Group {
                if meta.isYijing {
                    LookupView()
                } else {
                    NavigationStack { BookListView(bookId: id) }
                }
            }
            .tabItem {
                Image(uiImage: glyphTabImage(meta.icon))
                Text(meta.name)
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: CastRecord.self, inMemory: true)
}
