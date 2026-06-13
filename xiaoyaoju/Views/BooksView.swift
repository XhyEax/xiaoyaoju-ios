// Views/BooksView.swift — 通用书目 / 通用章节（booklist 驱动，双格式自适应）
import SwiftUI

// 通用书目（搜索 + 章节列表）
struct BookListView: View {
    let bookId: String
    @State private var searchText = ""
    private var db: ClassicsDatabase { .shared }
    private var results: [ClassicChapter] { db.search(bookId, searchText) }
    private var name: String { db.meta(bookId)?.name ?? "典籍" }

    var body: some View {
        List(results) { c in
            NavigationLink {
                BookChapterView(bookId: bookId, index: c.index, highlight: searchText)
            } label: {
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
    @Environment(\.dismiss) private var dismiss
    @State private var cur: Int
    @State private var hideAnno: Bool
    @State private var hideTrans: Bool
    @State private var fav = FavoritesStore.shared
    @State private var showTOC = false

    init(bookId: String, index: Int, highlight: String = "") {
        self.bookId = bookId
        self.highlight = highlight
        _cur = State(initialValue: index)
        _hideAnno = State(initialValue: UserDefaults.standard.bool(forKey: bookId + "_hideAnno"))
        _hideTrans = State(initialValue: UserDefaults.standard.bool(forKey: bookId + "_hideTrans"))
    }

    private var db: ClassicsDatabase { .shared }
    private var list: [ClassicChapter] { db.chapters(bookId) }
    private var chapter: ClassicChapter? { db.chapter(bookId, cur) }
    private func o(_ s: String) -> String { hideAnno ? stripMarks(s) : s }

    var body: some View {
        ScrollViewReader { proxy in
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
                                paragraphCard(p).id("c\(i)")
                            }
                        } else {
                            ClassicCard(o(c.original ?? ""), copy: o(c.original ?? ""),
                                        uiFont: .preferredFont(forTextStyle: .body), lineSpacing: 6, highlight: highlight).id("c0")
                            if let a = c.annotation, !a.isEmpty, !hideAnno {
                                ClassicCard(a, title: "注释", copy: a,
                                            uiFont: .preferredFont(forTextStyle: .footnote), color: .secondary)
                            }
                            if !hideTrans, let tr = c.translation, !tr.isEmpty {
                                ClassicCard(tr, title: "译文", copy: tr,
                                            uiFont: .preferredFont(forTextStyle: .body), highlight: highlight).id("ctr")
                            }
                        }
                        Color.clear.frame(height: 8)
                    }
                    .padding()
                }
            }
            .onAppear { scrollToMatch(proxy) }
            .onChange(of: cur) { _, _ in proxy.scrollTo("top", anchor: .top) } // 翻页后回到顶部
        }
        .navigationTitle(chapter?.chapter ?? (db.meta(bookId)?.name ?? "典籍"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTOC) {
            ChapterTOCSheet(bookId: bookId, current: cur) { idx in cur = idx; showTOC = false }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showTOC = true } label: { Image(systemName: "list.bullet") } // 目录：章节列表
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

    private func paragraphCard(_ p: ClassicPara) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ReadOnlyTextEditor(text: o(p.original), font: .preferredFont(forTextStyle: .body), lineSpacing: 6, highlight: highlight)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !p.annotation.isEmpty && !hideAnno {
                ReadOnlyTextEditor(text: "注：" + p.annotation, font: .preferredFont(forTextStyle: .footnote), color: .secondaryLabel, lineSpacing: 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !hideTrans {
                Divider()
                ReadOnlyTextEditor(text: p.translation, font: .preferredFont(forTextStyle: .body), color: .secondaryLabel, lineSpacing: 3, highlight: highlight)
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    // 搜索跳转：滚动到第一个含关键词的卡片
    private func scrollToMatch(_ proxy: ScrollViewProxy) {
        guard !highlight.isEmpty, let c = chapter else { return }
        func has(_ s: String?) -> Bool { (s ?? "").range(of: highlight, options: .caseInsensitive) != nil }
        var target: String?
        if let ps = c.paragraphs, !ps.isEmpty {
            for (i, p) in ps.enumerated() where has(p.original) || has(p.translation) { target = "c\(i)"; break }
        } else if has(c.original) { target = "c0" } else if has(c.translation) { target = "ctr" }
        if let t = target {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { withAnimation { proxy.scrollTo(t, anchor: .top) } }
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
                            Text(c.chapter).foregroundStyle(c.index == current ? .blue : .primary)
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
