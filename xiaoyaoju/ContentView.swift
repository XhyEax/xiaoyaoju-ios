// ContentView.swift — root TabView（首页 + 可配置 1-3 本典籍 + 收藏）+ 启动更新提示
// 预览/审核模式：abtest.ios_preview_mode 为 true 且本机无收藏/笔记/历史时，
// 仅显示「首页（隐藏眼睛/设置）+ 起卦（点选六爻）+ 历史（仅历史）」。
import SwiftUI
import SwiftData

struct MainTabView: View {
    @AppStorage("tabBooks") private var tabBooksRaw = "yj"
    @AppStorage("seenUpdateVersion") private var seenVersion = 0
    @State private var showUpdate = false
    @Query private var records: [CastRecord]
    @State private var previewMode = false

    private var db: ClassicsDatabase { .shared }
    private var books: [String] { parseTabBooks(tabBooksRaw) }

    var body: some View {
        Group {
            if previewMode { previewTabs } else { fullTabs }
        }
        .onAppear { resolvePreview() }   // 先用缓存值即时判定，减少闪烁
        .task {
            // 启动拉 config.json：更新 booklist + abtest + 取 update。版本变化则弹一次更新提示
            await db.fetchConfig()
            resolvePreview()             // 用远端最新 abtest 重新判定（关键：远端关掉时退出预览）
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

    // 启动时与 config 拉取后各判定一次（之后不再随会话内数据变动而改变 Tab 结构）
    private func resolvePreview() {
        // 云端关掉预览 → 直接退出，不再判断历史数
        guard db.iosPreviewMode else { previewMode = false; return }
        // 开着时：历史数 ≥ liuyao_history_count_limit 才退出预览；并保留无收藏/无笔记守卫，避免老用户被困
        previewMode = FavoritesStore.shared.isEmpty
            && NotesStore.shared.isEmpty
            && records.count < db.historyCountLimit
    }

    // 完整模式：首页 + 可配置典籍 + 收藏
    private var fullTabs: some View {
        TabView {
            NotesView()
                .tabItem { Label("首页", image: "TabNotes") }

            ForEach(books, id: \.self) { id in
                bookTab(id)
            }

            RecordsView()
                .tabItem { Label("收藏", image: "TabRecords") }
        }
    }

    // 预览/审核模式：首页 + 起卦 + 历史
    private var previewTabs: some View {
        TabView {
            NotesView(preview: true)
                .tabItem { Label("首页", image: "TabNotes") }

            NavigationStack { CastingContent(navigationTitle: "爻一爻") }
                .tabItem { Label("爻一爻", systemImage: "iphone.gen3.radiowaves.left.and.right") }

            RecordsView(preview: true)
                .tabItem { Label("历史", image: "TabRecords") }
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
