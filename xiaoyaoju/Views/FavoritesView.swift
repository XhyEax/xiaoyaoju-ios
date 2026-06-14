// Views/FavoritesView.swift — 收藏（汇总易经/各典籍，可跳转、左滑取消）
import SwiftUI

struct FavoritesView: View {
    @State private var fav = FavoritesStore.shared
    private var gua: GuaDatabase { .shared }
    private var db: ClassicsDatabase { .shared }

    private var items: [FavItem] {
        var out: [FavItem] = []
        for b in db.bookMetas {
            if b.isYijing {
                for n in fav.ids(b.id) {
                    if let g = gua.hexagram(number: n) {
                        out.append(FavItem(id: b.id + "\(n)", kind: b.id, refId: n, tag: b.icon,
                                           title: "《\(b.name)》" + g.name, sub: snip(g.desc)))
                    }
                }
            } else {
                for n in fav.ids(b.id) {
                    if let c = db.chapter(b.id, n) {
                        out.append(FavItem(id: b.id + "\(n)", kind: b.id, refId: n, tag: b.icon,
                                           title: "《\(b.name)》" + c.chapter, sub: snip(stripMarks(c.snippetRaw))))
                    }
                }
            }
        }
        return out
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView("暂无收藏", systemImage: "star",
                    description: Text("在典籍 / 易经详情点 ★ 收藏"))
            } else {
                List {
                    ForEach(items) { it in
                        favLink(it)
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

    // value-based 跳转：易经 → 卦象详情；典籍 → 章节页。由外层 RecordsView 的 path 统一追踪以控制 tabBar
    @ViewBuilder
    private func favLink(_ it: FavItem) -> some View {
        if it.kind == "yj" {
            NavigationLink(value: GuaRoute(number: it.refId)) { rowLabel(it) }
        } else {
            NavigationLink(value: ChapterRoute(bookId: it.kind, index: it.refId, highlight: "")) { rowLabel(it) }
        }
    }

    private func rowLabel(_ it: FavItem) -> some View {
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
}
