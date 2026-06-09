// Models/Favorites.swift
// 收藏（按 kind 分类持久化：yj 易经卦号 / ddj 道德经章 / zz 庄子篇）
import SwiftUI

@Observable
final class FavoritesStore {
    static let shared = FavoritesStore()

    private(set) var yj: [Int] = []
    private(set) var ddj: [Int] = []
    private(set) var zz: [Int] = []

    private init() {
        yj = load("fav_yj")
        ddj = load("fav_ddj")
        zz = load("fav_zz")
    }

    func isFav(_ kind: String, _ id: Int) -> Bool { list(kind).contains(id) }

    func toggle(_ kind: String, _ id: Int) {
        var arr = list(kind)
        if let i = arr.firstIndex(of: id) { arr.remove(at: i) } else { arr.append(id) }
        save(kind, arr)
    }

    func remove(_ kind: String, _ id: Int) {
        var arr = list(kind)
        arr.removeAll { $0 == id }
        save(kind, arr)
    }

    private func list(_ kind: String) -> [Int] {
        switch kind { case "ddj": return ddj; case "zz": return zz; default: return yj }
    }
    private func save(_ kind: String, _ arr: [Int]) {
        switch kind { case "ddj": ddj = arr; case "zz": zz = arr; default: yj = arr }
        UserDefaults.standard.set(arr, forKey: "fav_" + kind)
    }
    private func load(_ key: String) -> [Int] {
        (UserDefaults.standard.array(forKey: key) as? [Int]) ?? []
    }
}

// 收藏列表项（跨经典汇总，可跳转）
struct FavItem: Identifiable {
    let id: String        // 唯一键 e.g. "yj1"
    let kind: String      // yj / ddj / zz
    let refId: Int
    let tag: String       // 易 / 道 / 庄
    let title: String     // 《易经》乾为天
    let sub: String       // 正文开头
}
