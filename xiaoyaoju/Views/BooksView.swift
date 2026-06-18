// Views/BooksView.swift — 通用书目 / 通用章节（booklist 驱动，双格式自适应）
import SwiftUI

struct ChapterRoute: Hashable {
    let bookId: String
    let index: Int
    let highlight: String
    var anchor: String? = nil   // 从笔记列表跳转时定位的段落（如 "2-0"）
}

// 易经卦象详情路由（查卦/收藏跳转用，showShareActions: true）
struct GuaRoute: Hashable {
    let number: Int
    var anchor: String? = nil   // 从笔记列表跳转时定位的小节（如 "12-yao3"）
}

// 「点选六爻」起卦页路由（易经 Tab 用）
struct CastInputRoute: Hashable {}

// 带路径追踪的书籍 Tab 容器，在 NavigationStack 层控制 tabBar 可见性，避免 pop 时闪烁
struct BookTabView: View {
    let bookId: String
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            BookListView(bookId: bookId)
                .navigationDestination(for: ChapterRoute.self) { route in
                    BookChapterView(bookId: route.bookId, index: route.index, highlight: route.highlight, anchor: route.anchor)
                }
        }
        .toolbar(path.isEmpty ? .visible : .hidden, for: .tabBar)
    }
}

// 通用书目（搜索 + 章节列表）
struct BookListView: View {
    let bookId: String
    @State private var searchText = ""
    private var db: ClassicsDatabase { .shared }
    private var results: [ClassicChapter] { db.search(bookId, searchText) }
    private var name: String { db.meta(bookId)?.name ?? "典籍" }

    var body: some View {
        List(results) { c in
            NavigationLink(value: ChapterRoute(bookId: bookId, index: c.index, highlight: searchText)) {
                HStack(spacing: 12) {
                    Text("\(c.index)").font(.caption).foregroundStyle(.secondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.chapter)
                        Text(snip(stripMarks(c.snippetRaw)))
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.tail)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle(name)
        .searchable(text: $searchText, prompt: "搜索")
        .onAppear { db.ensureLoaded(bookId) }
    }
}

// 通用章节页（双格式自适应；注释关闭时正文去注释标号；正文 \n 原生换行）
struct BookChapterView: View {
    let bookId: String
    var highlight: String = ""
    let initialAnchor: String?
    @Environment(\.dismiss) private var dismiss
    @State private var cur: Int
    @State private var hideAnno: Bool
    @State private var hideTrans: Bool
    @State private var fav = FavoritesStore.shared
    @State private var notes = NotesStore.shared
    @State private var noteTarget: NoteTarget?
    @State private var showTOC = false
    @State private var scrollID: String?   // 当前顶部卡片 id；切换注/译时保持段落位置
    @AppStorage("readerFontScale") private var fontScale: Double = 1.0

    init(bookId: String, index: Int, highlight: String = "", anchor: String? = nil) {
        self.bookId = bookId
        self.highlight = highlight
        self.initialAnchor = anchor
        _cur = State(initialValue: index)
        _hideAnno = State(initialValue: UserDefaults.standard.bool(forKey: bookId + "_hideAnno"))
        _hideTrans = State(initialValue: UserDefaults.standard.bool(forKey: bookId + "_hideTrans"))
    }

    private var db: ClassicsDatabase { .shared }
    private var list: [ClassicChapter] { db.chapters(bookId) }
    private var chapter: ClassicChapter? { db.chapter(bookId, cur) }
    private func o(_ s: String) -> String { hideAnno ? stripMarks(s) : s }

    var body: some View {
        // iPad 横屏（宽 ≥ 1000）：左目录栏 + 右正文双栏，参照 book.html 桌面布局
        GeometryReader { geo in
            let wide = geo.size.width >= 1000
            Group {
                if wide {
                    HStack(spacing: 0) {
                        chapterSidebar
                        Divider()
                        readingPane
                    }
                } else {
                    readingPane
                }
            }
            .navigationTitle(chapter?.chapter ?? (db.meta(bookId)?.name ?? "典籍"))
            .navigationBarTitleDisplayMode(.inline)
            // tabBar 可见性由外层 BookTabView 通过 NavigationPath 控制，此处不重复设置
            .sheet(isPresented: $showTOC) {
                ChapterTOCSheet(bookId: bookId, current: cur) { idx in cur = idx; showTOC = false }
            }
            .sheet(item: $noteTarget) { t in NoteEditorSheet(kind: t.kind, noteKey: t.key) }
            .toolbar {
                // 宽屏有常驻侧栏目录，隐藏顶部「目录」按钮
                if !wide {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { showTOC = true } label: { Image(systemName: "list.bullet") } // 目录：章节列表
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        UIPasteboard.general.string = shareText
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: { Image(systemName: "doc.on.doc") }
                    ShareLink(item: shareText) { Image(systemName: "square.and.arrow.up") }
                }
            }
            .safeAreaInset(edge: .bottom) {
                ClassicBottomBar(
                    prevEnabled: cur > 1,
                    nextEnabled: cur < list.count,
                    hideAnno: hideAnno, hideTrans: hideTrans,
                    isFav: fav.isFav(bookId, cur),
                    onPrev: { if cur > 1 { cur -= 1 } },
                    onNext: { if cur < list.count { cur += 1 } },
                    onAnno: { hideAnno.toggle(); UserDefaults.standard.set(hideAnno, forKey: bookId + "_hideAnno") },
                    onTrans: { hideTrans.toggle(); UserDefaults.standard.set(hideTrans, forKey: bookId + "_hideTrans") },
                    onFav: { fav.toggle(bookId, cur) }
                )
            }
            .onAppear { db.ensureLoaded(bookId) }
        }
    }

    // 正文区：随内容滚动，版心居中并限宽，避免 iPad 上行宽过长
    private var readingPane: some View {
        ScrollView {
            if let c = chapter {
                VStack(alignment: .leading, spacing: 16) {
                    // 顶部导航已显示章名，正文不再重复；仅保留副标题（篇章归属）
                    if let t = c.title, t != c.chapter {
                        Text(t).font(.subheadline).foregroundStyle(.secondary)
                            .id("top")
                    } else {
                        Color.clear.frame(height: 0).id("top")
                    }
                    if let ps = c.paragraphs, !ps.isEmpty {
                        ForEach(Array(ps.enumerated()), id: \.offset) { i, p in
                            paragraphCard(i, p).id("c\(i)")
                        }
                    } else {
                        singleOriginalCard(o(c.original ?? "")).id("c0")
                        if let a = c.annotation, !a.isEmpty, !hideAnno {
                            ClassicCard(a, title: "注释", copy: a,
                                        uiFont: scaledUIFont(.footnote, fontScale), color: .secondary)
                        }
                        if !hideTrans, let tr = c.translation, !tr.isEmpty {
                            ClassicCard(tr, title: "译文", copy: tr,
                                        uiFont: scaledUIFont(.body, fontScale), highlight: highlight).id("ctr")
                        }
                    }
                    Color.clear.frame(height: 8)
                }
                .scrollTargetLayout()
                .padding()
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
                .dismissTextSelectionOnTap()
            }
        }
        // 绑定顶部卡片 id：切换注/译内容变化时保持当前段落位置不跳动
        .scrollPosition(id: $scrollID, anchor: .top)
        .onAppear { restoreScroll() }
        .onChange(of: cur) { _, _ in scrollID = "top" } // 翻页后回到顶部
    }

    // 左侧目录栏（宽屏常驻）：点选章节即切换，当前章高亮并居中
    private var chapterSidebar: some View {
        ScrollViewReader { proxy in
            List(list) { c in
                Button { if c.index != cur { cur = c.index } } label: {
                    HStack {
                        Text("\(c.index). \(c.chapter)")
                            .foregroundStyle(c.index == cur ? Color.accentColor : .primary)
                            .lineLimit(1)
                        Spacer()
                        if c.index == cur {
                            Image(systemName: "checkmark").font(.caption).foregroundStyle(.tint)
                        }
                    }
                }
                .id(c.index)
            }
            .listStyle(.plain)
            .frame(width: 300)
            .onAppear { proxy.scrollTo(cur, anchor: .center) }
            .onChange(of: cur) { _, v in withAnimation { proxy.scrollTo(v, anchor: .center) } }
        }
    }

    // 段落卡：段号 + 铅笔；笔记显示在原文下方
    private func paragraphCard(_ i: Int, _ p: ClassicPara) -> some View {
        let key = "\(cur)-\(i)"
        let note = notes.get(bookId, key)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(i + 1)").font(.subheadline).bold().foregroundStyle(.secondary)
                Spacer()
                NotePencil { noteTarget = NoteTarget(kind: bookId, key: key) }
            }
            ReadOnlyTextEditor(text: o(p.original), font: scaledUIFont(.body, fontScale), lineSpacing: 6, highlight: highlight)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !note.isEmpty {
                NoteDisplay(text: note, fontScale: fontScale) { noteTarget = NoteTarget(kind: bookId, key: key) }
            }
            if !p.annotation.isEmpty && !hideAnno {
                ReadOnlyTextEditor(text: "注：" + p.annotation, font: scaledUIFont(.footnote, fontScale), color: .secondaryLabel, lineSpacing: 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !hideTrans {
                Divider()
                ReadOnlyTextEditor(text: p.translation, font: scaledUIFont(.body, fontScale), color: .secondaryLabel, lineSpacing: 3, highlight: highlight)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // 单章原文卡：原文标题 + 铅笔；笔记显示在原文下方
    private func singleOriginalCard(_ text: String) -> some View {
        let key = "\(cur)"
        let note = notes.get(bookId, key)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("原文").font(.subheadline).bold().foregroundStyle(.secondary)
                Spacer()
                NotePencil { noteTarget = NoteTarget(kind: bookId, key: key) }
            }
            ReadOnlyTextEditor(text: text, font: scaledUIFont(.body, fontScale), lineSpacing: 6, highlight: highlight)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !note.isEmpty {
                NoteDisplay(text: note, fontScale: fontScale) { noteTarget = NoteTarget(kind: bookId, key: key) }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func paraCopy(_ p: ClassicPara) -> String {
        var s = "【原文】" + o(p.original)
        if !p.annotation.isEmpty && !hideAnno { s += "\n【注释】" + p.annotation }
        if !hideTrans { s += "\n【译文】" + p.translation }
        return s
    }

    private var shareText: String {
        guard let c = chapter else { return "" }
        var parts = [c.title ?? c.chapter]
        if let ps = c.paragraphs, !ps.isEmpty {
            for p in ps { parts.append(paraCopy(p)) }
        } else {
            var s = "【原文】" + o(c.original ?? "")
            if let a = c.annotation, !a.isEmpty, !hideAnno { s += "\n【注释】" + a }
            if !hideTrans, let tr = c.translation { s += "\n【译文】" + tr }
            parts.append(s)
        }
        return parts.joined(separator: "\n\n")
    }

    // 初次进入：笔记跳转锚点优先，其次搜索命中段落（设置 scrollID 即定位）
    private func restoreScroll() {
        var target: String?
        if let a = initialAnchor {
            target = "c0"
            if let dash = a.lastIndex(of: "-"), let pi = Int(a[a.index(after: dash)...]) { target = "c\(pi)" }
        } else if !highlight.isEmpty, let c = chapter {
            func has(_ s: String?) -> Bool { (s ?? "").range(of: highlight, options: .caseInsensitive) != nil }
            if let ps = c.paragraphs, !ps.isEmpty {
                for (i, p) in ps.enumerated() where has(p.original) || has(p.translation) { target = "c\(i)"; break }
            } else if has(c.original) { target = "c0" } else if has(c.translation) { target = "ctr" }
        }
        if let t = target {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { withAnimation { scrollID = t } }
        }
    }
}

// 章节目录：弹出列表点选跳转
struct ChapterTOCSheet: View {
    let bookId: String
    let current: Int
    let onPick: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    private var db: ClassicsDatabase { .shared }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List(db.chapters(bookId)) { c in
                    Button { onPick(c.index) } label: {
                        HStack {
                            Text("\(c.index). \(c.chapter)").foregroundStyle(c.index == current ? .blue : .primary)
                            Spacer()
                            if c.index == current { Image(systemName: "checkmark").foregroundStyle(.blue) }
                        }
                    }
                    .id(c.index)
                }
                .navigationTitle("目录")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
                .onAppear { proxy.scrollTo(current, anchor: .center) }
            }
        }
    }
}
