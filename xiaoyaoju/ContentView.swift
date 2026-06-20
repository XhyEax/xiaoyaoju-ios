// ContentView.swift — root TabView（首页 + 可配置 1-3 本典籍 + 收藏）+ 启动更新提示
import SwiftUI
import SwiftData

struct MainTabView: View {
    @AppStorage("tabBooks") private var tabBooksRaw = "yj"
    @AppStorage("seenUpdateVersion") private var seenVersion = 0
    @AppStorage("showCastingTab") private var showCastingTab = false   // 设置里开关，默认关
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

            // 典籍少于 3 部且设置里开启时，在「收藏」左侧补一个「爻一爻」起卦入口
            if books.count < 3 && showCastingTab {
                NavigationStack { CastingContent(navigationTitle: "爻一爻") }
                    .tabItem {
                        Image(uiImage: symbolTabImage("iphone.gen3.radiowaves.left.and.right"))
                        Text("爻一爻")
                    }
            }

            RecordsView()
                .tabItem { Label("收藏", image: "TabRecords") }
        }
        .task {
            // 启动拉 config.json：更新 booklist + 取 update。版本变化则弹一次更新提示
            await db.fetchConfig()
            if let u = db.update {
                if seenVersion == 0 { seenVersion = u.version }   // 首次安装不提示已内置内容
                else if u.version != seenVersion { showUpdate = true }
            }
        }
        .alert(db.update?.title ?? "更新内容", isPresented: $showUpdate) {
            Button("我知道了") { if let u = db.update { seenVersion = u.version } }
        } message: {
            Text(db.update?.content ?? "")
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
                    BookTabView(bookId: id)
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
