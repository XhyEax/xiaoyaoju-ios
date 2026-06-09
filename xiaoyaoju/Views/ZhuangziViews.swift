// Views/ZhuangziViews.swift — Tab 3: 庄子（列表 + 章节）
import SwiftUI

struct ZhuangziListView: View {
    @State private var searchText = ""
    private var db: ClassicsDatabase { ClassicsDatabase.shared }
    private var results: [ZhuangziChapter] { db.searchZhuangzi(searchText) }

    var body: some View {
        NavigationStack {
            List(results) { c in
                NavigationLink {
                    ZhuangziChapterView(index: c.index)
                } label: {
                    HStack(spacing: 12) {
                        Text("\(c.index)").font(.caption).foregroundStyle(.secondary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.chapter)
                            Text(c.title)
                                .font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.tail)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("《庄子》")
            .searchable(text: $searchText, prompt: "搜索")
        }
    }
}

struct ZhuangziChapterView: View {
    let index: Int
    @State private var cur: Int
    @AppStorage("zz_hideAnno") private var hideAnno = false
    @AppStorage("zz_hideTrans") private var hideTrans = false
    @State private var fav = FavoritesStore.shared

    init(index: Int) { self.index = index; _cur = State(initialValue: index) }

    private var db: ClassicsDatabase { ClassicsDatabase.shared }
    private var chapter: ZhuangziChapter? { db.zzChapter(cur) }

    var body: some View {
        ScrollView {
            if let c = chapter {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(c.chapter).font(.title2).bold()
                        Text(c.title).font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(Array(c.paragraphs.enumerated()), id: \.offset) { _, p in
                        paragraphCard(p)
                    }
                    Color.clear.frame(height: 8)
                }
                .padding()
            }
        }
        .navigationTitle(chapter?.chapter ?? "庄子")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ChapterShareToolbar(text: shareText)
            ChapterBottomToolbar(
                prevEnabled: cur > 1,
                nextEnabled: cur < db.zhuangzi.count,
                hideAnno: hideAnno, hideTrans: hideTrans,
                isFav: fav.isFav("zz", cur),
                onPrev: { if cur > 1 { cur -= 1 } },
                onNext: { if cur < db.zhuangzi.count { cur += 1 } },
                onAnno: { hideAnno.toggle() },
                onTrans: { hideTrans.toggle() },
                onFav: { fav.toggle("zz", cur) }
            )
        }
    }

    private func paragraphCard(_ p: ZhuangziPara) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(p.original).font(.body).lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !p.annotation.isEmpty && !hideAnno {
                Text("注：" + p.annotation).font(.footnote).foregroundStyle(.secondary).lineSpacing(3)
            }
            if !hideTrans {
                Divider()
                Text(p.translation).foregroundStyle(.secondary).lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            Button {
                UIPasteboard.general.string = paraCopy(p)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: { Label("复制", systemImage: "doc.on.doc") }
        }
    }

    private func paraCopy(_ p: ZhuangziPara) -> String {
        var s = "【原文】" + p.original
        if !p.annotation.isEmpty && !hideAnno { s += "\n【注释】" + p.annotation }
        if !hideTrans { s += "\n【译文】" + p.translation }
        return s
    }

    private var shareText: String {
        guard let c = chapter else { return "" }
        var parts = [c.title]
        for p in c.paragraphs { parts.append(paraCopy(p)) }
        return parts.joined(separator: "\n\n")
    }
}
