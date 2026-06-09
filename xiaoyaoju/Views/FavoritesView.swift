// Views/FavoritesView.swift — 收藏（汇总易经/道德经/庄子，可跳转、左滑取消）
import SwiftUI

struct FavoritesView: View {
    @State private var fav = FavoritesStore.shared
    private var gua: GuaDatabase { .shared }
    private var cdb: ClassicsDatabase { .shared }

    private var items: [FavItem] {
        var out: [FavItem] = []
        for n in fav.yj {
            if let g = gua.hexagram(number: n) {
                out.append(FavItem(id: "yj\(n)", kind: "yj", refId: n, tag: "易",
                                   title: "《易经》" + g.name, sub: snip(g.desc)))
            }
        }
        for n in fav.ddj {
            if let c = cdb.ddjChapter(n) {
                out.append(FavItem(id: "ddj\(n)", kind: "ddj", refId: n, tag: "道",
                                   title: "《道德经》" + c.chapter, sub: snip(c.original)))
            }
        }
        for n in fav.zz {
            if let c = cdb.zzChapter(n) {
                out.append(FavItem(id: "zz\(n)", kind: "zz", refId: n, tag: "庄",
                                   title: "《庄子》" + c.chapter, sub: snip(c.paragraphs.first?.original ?? "")))
            }
        }
        return out
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView("暂无收藏", systemImage: "star",
                    description: Text("在道德经 / 庄子 / 易经详情点 ★ 收藏"))
            } else {
                List {
                    ForEach(items) { it in
                        NavigationLink {
                            destination(it)
                        } label: {
                            HStack(spacing: 12) {
                                Text(it.tag).font(.system(size: 15)).foregroundStyle(.blue)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(it.title)
                                    Text(it.sub).font(.caption).foregroundStyle(.secondary)
                                        .lineLimit(1).truncationMode(.tail)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                fav.remove(it.kind, it.refId)
                            } label: { Label("删除", systemImage: "trash") }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func destination(_ it: FavItem) -> some View {
        switch it.kind {
        case "yj":
            if let g = gua.hexagram(number: it.refId) {
                HexagramDetailView(hexagram: g, showShareActions: true)
            }
        case "ddj":
            DaodejingChapterView(index: it.refId)
        default:
            ZhuangziChapterView(index: it.refId)
        }
    }
}
