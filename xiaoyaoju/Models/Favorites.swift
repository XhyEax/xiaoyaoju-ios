// Models/Favorites.swift
// 收藏（按 kind 分类持久化：yj 易经卦号 / 各典籍 id 章号）
import SwiftUI

@Observable
final class FavoritesStore {
    static let shared = FavoritesStore()

    // 已知收藏分类（易经 + 各阅读类典籍 id）
    private static let kinds = ["yj", "ddj", "zz", "lz", "tanjing", "jingangjing"]
    private var store: [String: [Int]] = [:]
    // iCloud：每个收藏一个 key「f/<kind>/<id>」= true，系统按 key 做 last-writer-wins
    @ObservationIgnored private let kvs = NSUbiquitousKeyValueStore.default
    private static let kvsPrefix = "f/"

    private init() {
        for k in Self.kinds {
            store[k] = (UserDefaults.standard.array(forKey: "fav_" + k) as? [Int]) ?? []
        }
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs, queue: .main
        ) { [weak self] note in self?.applyRemoteChange(note) }
        kvs.synchronize()
        reconcileWithCloud()
    }

    func ids(_ kind: String) -> [Int] { store[kind] ?? [] }
    func isFav(_ kind: String, _ id: Int) -> Bool { (store[kind] ?? []).contains(id) }

    /// 全量导出（用于「全部数据」备份）
    func allFavorites() -> [String: [Int]] { store }

    /// 并集导入（用于「全部数据」恢复），返回新增数
    @discardableResult
    func importFavorites(_ incoming: [String: [Int]]) -> Int {
        var added = 0
        for (kind, list) in incoming {
            var arr = store[kind] ?? []
            for id in list where !arr.contains(id) { arr.append(id); writeCloud(kind, id, true); added += 1 }
            save(kind, arr)
        }
        return added
    }

    func toggle(_ kind: String, _ id: Int) {
        var arr = store[kind] ?? []
        if let i = arr.firstIndex(of: id) { arr.remove(at: i); writeCloud(kind, id, false) }
        else { arr.append(id); writeCloud(kind, id, true) }
        save(kind, arr)
    }

    func remove(_ kind: String, _ id: Int) {
        var arr = store[kind] ?? []
        arr.removeAll { $0 == id }
        writeCloud(kind, id, false)
        save(kind, arr)
    }

    private func save(_ kind: String, _ arr: [Int]) {
        store[kind] = arr
        UserDefaults.standard.set(arr, forKey: "fav_" + kind)
    }

    private func writeCloud(_ kind: String, _ id: Int, _ on: Bool) {
        let key = Self.kvsPrefix + kind + "/\(id)"
        if on { kvs.set(true, forKey: key) } else { kvs.removeObject(forKey: key) }
        kvs.synchronize()
    }

    private func parse(_ kvsKey: String) -> (kind: String, id: Int)? {
        let body = kvsKey.dropFirst(Self.kvsPrefix.count)   // "<kind>/<id>"
        guard let slash = body.firstIndex(of: "/"),
              let id = Int(body[body.index(after: slash)...]) else { return nil }
        let kind = String(body[..<slash])
        guard !kind.isEmpty else { return nil }
        return (kind, id)
    }

    // 启动调和：双向并集，本地优先（不删本地，避免切换账号/离线丢收藏）
    private func reconcileWithCloud() {
        let cloud = kvs.dictionaryRepresentation
        for (k, _) in cloud where k.hasPrefix(Self.kvsPrefix) {
            guard let p = parse(k) else { continue }
            var arr = store[p.kind] ?? []
            if !arr.contains(p.id) { arr.append(p.id); save(p.kind, arr) }
        }
        for (kind, arr) in store {
            for id in arr where cloud[Self.kvsPrefix + kind + "/\(id)"] == nil {
                kvs.set(true, forKey: Self.kvsPrefix + kind + "/\(id)")
            }
        }
        kvs.synchronize()
    }

    // 远端实时变更：采用云端值（含取消收藏）
    private func applyRemoteChange(_ note: Notification) {
        guard let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
        for k in keys where k.hasPrefix(Self.kvsPrefix) {
            guard let p = parse(k) else { continue }
            var arr = store[p.kind] ?? []
            let present = kvs.object(forKey: k) != nil
            if present { if !arr.contains(p.id) { arr.append(p.id) } }
            else { arr.removeAll { $0 == p.id } }
            save(p.kind, arr)
        }
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
