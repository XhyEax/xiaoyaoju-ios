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
                BookChapterView(bookId: bookId, index: c.index)
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
    @Environment(\.dismiss) private var dismiss
    @State private var cur: Int
    @State private var hideAnno: Bool
    @State private var hideTrans: Bool
    @State private var fav = FavoritesStore.shared

    init(bookId: String, index: Int) {
        self.bookId = bookId
        _cur = State(initialValue: index)
        _hideAnno = State(initialValue: UserDefaults.standard.bool(forKey: bookId + "_hideAnno"))
        _hideTrans = State(initialValue: UserDefaults.standard.bool(forKey: bookId + "_hideTrans"))
    }

    private var db: ClassicsDatabase { .shared }
    private var list: [ClassicChapter] { db.chapters(bookId) }
    private var chapter: ClassicChapter? { db.chapter(bookId, cur) }
    private func o(_ s: String) -> String { hideAnno ? stripMarks(s) : s }

    var body: some View {
        ScrollView {
            if let c = chapter {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(c.chapter).font(.title2).bold()
                        if let t = c.title, t != c.chapter {
                            Text(t).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    if let ps = c.paragraphs, !ps.isEmpty {
                        ForEach(Array(ps.enumerated()), id: \.offset) { _, p in
                            paragraphCard(p)
                        }
                    } else {
                        ClassicCard(o(c.original ?? ""), copy: o(c.original ?? ""), font: .body, lineSpacing: 6)
                        if let a = c.annotation, !a.isEmpty, !hideAnno {
                            ClassicCard(a, title: "注释", copy: a, font: .footnote, color: .secondary)
                        }
                        if !hideTrans, let tr = c.translation, !tr.isEmpty {
                            ClassicCard(tr, title: "译文", copy: tr, font: .body)
                        }
                    }
                    Color.clear.frame(height: 8)
                }
                .padding()
            }
        }
        .navigationTitle(chapter?.chapter ?? (db.meta(bookId)?.name ?? "典籍"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    UIPasteboard.general.string = shareText
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: { Image(systemName: "doc.on.doc") }
                Button { dismiss() } label: { Image(systemName: "list.bullet") } // 目录：返回书目
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
            Text(o(p.original)).font(.body).lineSpacing(6)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !p.annotation.isEmpty && !hideAnno {
                Text("注：" + p.annotation).font(.footnote).foregroundStyle(.secondary).lineSpacing(3)
                    .textSelection(.enabled)
            }
            if !hideTrans {
                Divider()
                Text(p.translation).foregroundStyle(.secondary).lineSpacing(3)
                    .textSelection(.enabled)
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
}
