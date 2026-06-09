// Views/DaodejingViews.swift — Tab 2: 道德经（列表 + 章节）
import SwiftUI

struct DaodejingListView: View {
    @State private var searchText = ""
    private var db: ClassicsDatabase { ClassicsDatabase.shared }
    private var results: [DaodejingChapter] { db.searchDaodejing(searchText) }

    var body: some View {
        NavigationStack {
            List(results) { c in
                NavigationLink {
                    DaodejingChapterView(index: c.index)
                } label: {
                    HStack(spacing: 12) {
                        Text("\(c.index)").font(.caption).foregroundStyle(.secondary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.chapter)
                            Text(snip(c.original))
                                .font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.tail)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("《道德经》")
            .searchable(text: $searchText, prompt: "搜索")
        }
    }
}

struct DaodejingChapterView: View {
    let index: Int
    @State private var cur: Int
    @AppStorage("ddj_hideAnno") private var hideAnno = false
    @AppStorage("ddj_hideTrans") private var hideTrans = false
    @State private var fav = FavoritesStore.shared

    init(index: Int) { self.index = index; _cur = State(initialValue: index) }

    private var db: ClassicsDatabase { ClassicsDatabase.shared }
    private var chapter: DaodejingChapter? { db.ddjChapter(cur) }

    var body: some View {
        ScrollView {
            if let c = chapter {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(c.chapter).font(.title2).bold()
                        Text(c.title).font(.subheadline).foregroundStyle(.secondary)
                    }
                    ClassicCard(c.original, copy: c.original, font: .body, lineSpacing: 6)
                    if !c.annotation.isEmpty && !hideAnno {
                        ClassicCard(c.annotation, title: "注释", copy: c.annotation,
                                    font: .footnote, color: .secondary)
                    }
                    if !hideTrans {
                        ClassicCard(c.translation, title: "译文", copy: c.translation, font: .body)
                    }
                    Color.clear.frame(height: 8)
                }
                .padding()
            }
        }
        .navigationTitle(chapter?.chapter ?? "道德经")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ChapterShareToolbar(text: shareText) }
        .safeAreaInset(edge: .bottom) { chapterBottomBar }
    }

    private var shareText: String {
        guard let c = chapter else { return "" }
        var parts = [c.title, "【原文】" + c.original]
        if !c.annotation.isEmpty && !hideAnno { parts.append("【注释】" + c.annotation) }
        if !hideTrans { parts.append("【译文】" + c.translation) }
        return parts.joined(separator: "\n\n")
    }

    private var chapterBottomBar: some View {
        ClassicBottomBar(
            prevEnabled: cur > 1,
            nextEnabled: cur < db.daodejing.count,
            hideAnno: hideAnno, hideTrans: hideTrans,
            isFav: fav.isFav("ddj", cur),
            onPrev: { if cur > 1 { cur -= 1 } },
            onNext: { if cur < db.daodejing.count { cur += 1 } },
            onAnno: { hideAnno.toggle() },
            onTrans: { hideTrans.toggle() },
            onFav: { fav.toggle("ddj", cur) }
        )
    }
}
