// Models/Favorites.swift
// 收藏（按 kind 分类持久化：yj 易经卦号 / 各典籍 id 章号）
import SwiftUI

@Observable
final class FavoritesStore {
    static let shared = FavoritesStore()

    // 已知收藏分类（易经 + 各阅读类典籍 id）
    private static let kinds = ["yj", "ddj", "zz", "lz", "tanjing", "jingangjing"]
    private var store: [String: [Int]] = [:]

    private init() {
        for k in Self.kinds {
            store[k] = (UserDefaults.standard.array(forKey: "fav_" + k) as? [Int]) ?? []
        }
    }

    func ids(_ kind: String) -> [Int] { store[kind] ?? [] }
    func isFav(_ kind: String, _ id: Int) -> Bool { (store[kind] ?? []).contains(id) }
    var isEmpty: Bool { store.values.allSatisfy { $0.isEmpty } }

    func toggle(_ kind: String, _ id: Int) {
        var arr = store[kind] ?? []
        if let i = arr.firstIndex(of: id) { arr.remove(at: i) } else { arr.append(id) }
        save(kind, arr)
    }

    func remove(_ kind: String, _ id: Int) {
        var arr = store[kind] ?? []
        arr.removeAll { $0 == id }
        save(kind, arr)
    }

    private func save(_ kind: String, _ arr: [Int]) {
        store[kind] = arr
        UserDefaults.standard.set(arr, forKey: "fav_" + kind)
    }
}

// 收藏列表项（跨典籍汇总，可跳转）
struct FavItem: Identifiable {
    let id: String        // 唯一键 e.g. "yj1"
    let kind: String      // yj / ddj / zz / lz / tanjing / jingangjing
    let refId: Int
    let tag: String       // 图标字
    let title: String     // 《易经》乾为天
    let sub: String       // 正文开头
}
