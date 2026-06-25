// ContentView.swift — root TabView（首页 + 可配置 1-3 本典籍 + 收藏）+ 启动更新提示
import SwiftUI
import SwiftData

struct MainTabView: View {
    @AppStorage("tabBooks") private var tabBooksRaw = ""
    @AppStorage("seenUpdateVersion") private var seenVersion = 0
    @AppStorage("showCastingTab") private var showCastingTab = false   // 设置里开关，默认关
    @AppStorage("autoRefresh") private var autoRefresh = true  // 默认启动即 fetch（不上架）
    @State private var showUpdate = false
    @State private var deepLink: DeepLink?   // 小组件点击跳转

    private var db: ClassicsDatabase { .shared }
    private var books: [String] { parseTabBooks(tabBooksRaw) }

    // 小组件 deep link：xiaoyaoju://cast | gua/<n> | chapter/<book>/<index>
    enum DeepLink: Identifiable {
        case cast, gua(Int), chapter(String, Int)
        var id: String {
            switch self {
            case .cast: return "cast"
            case .gua(let n): return "gua\(n)"
            case .chapter(let b, let i): return "ch\(b)\(i)"
            }
        }
    }

    var body: some View {
        TabView {
            NotesView()
                .tabItem { Label("首页", image: "TabNotes") }

            ForEach(books, id: \.self) { id in
                bookTab(id)
            }

            // 设置里开启时，在「收藏」左侧补一个「爻一爻」起卦入口
            if showCastingTab {
                NavigationStack { CastingContent(navigationTitle: "爻一爻") }
                    .tabItem {
                        Image(uiImage: symbolTabImage("iphone.gen3.radiowaves.left.and.right"))
                        Text("爻一爻")
                    }
            }

            RecordsView()
                .tabItem { Label("收藏", image: "TabRecords") }
        }
        // 默认不在启动请求 CONFIG_URL；用户在设置手动刷新过一次后，以后启动也 fetch
        .task {
            if autoRefresh { await db.fetchConfig() }
        }
        .onChange(of: db.update) { _, u in
            guard let u else { return }
            if seenVersion == 0 { seenVersion = u.version }   // 首次拉到不提示已内置内容
            else if u.version != seenVersion { showUpdate = true }
        }
        .alert(db.update?.title ?? "更新内容", isPresented: $showUpdate) {
            Button("我知道了") { if let u = db.update { seenVersion = u.version } }
        } message: {
            Text(db.update?.content ?? "")
        }
        .onOpenURL { handleURL($0) }
        .sheet(item: $deepLink) { deepLinkSheet($0) }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "xiaoyaoju" else { return }
        switch url.host {
        case "cast": deepLink = .cast
        case "gua": if let n = Int(url.lastPathComponent) { deepLink = .gua(n) }
        case "chapter":
            let parts = url.pathComponents.filter { $0 != "/" }   // [book, index]
            if parts.count == 2, let i = Int(parts[1]) { deepLink = .chapter(parts[0], i) }
        default: break
        }
    }

    @ViewBuilder
    private func deepLinkSheet(_ link: DeepLink) -> some View {
        NavigationStack {
            Group {
                switch link {
                case .cast:
                    CastingContent(navigationTitle: "爻一爻")
                case .gua(let n):
                    if let g = GuaDatabase.shared.hexagram(number: n) {
                        HexagramDetailView(hexagram: g, showShareActions: true)
                    } else { ContentUnavailableView("未找到该卦", systemImage: "questionmark.circle") }
                case .chapter(let b, let i):
                    BookChapterView(bookId: b, index: i)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { deepLink = nil } } }
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
