// Models/Classics.swift
// 典籍数据模型与加载（随包 JSON + 远程 config.json/<id>.json，booklist 驱动，双格式自适应）
import Foundation
import Observation

// MARK: - 通用章节模型（兼容 paragraphs 段落格式 与 original/annotation/translation 整段格式）

struct ClassicPara: Codable, Identifiable {
    let original: String
    let annotation: String
    let translation: String
    var id: String { original }
}

struct ClassicChapter: Codable, Identifiable {
    var id: Int { index }
    let index: Int
    let chapter: String
    let title: String?
    let original: String?
    let annotation: String?
    let translation: String?
    let paragraphs: [ClassicPara]?

    var hasPara: Bool { (paragraphs?.isEmpty == false) }
    var snippetRaw: String { paragraphs?.first?.original ?? (original ?? "") }
}

struct BookMeta: Identifiable, Codable {
    let id: String
    let name: String
    let icon: String
    var isYijing: Bool = false
}

private struct RemoteBook: Codable { let id: String; let name: String; let icon: String?; let type: String?; let data: String? }
private struct RemoteUpdate: Codable { let title: String?; let content: String?; let version: Int? }
private struct RemoteConfig: Codable { let booklist: [RemoteBook]; let update: RemoteUpdate? }

// 更新提示内容（来自 config.json 的 update 字段）
struct UpdateInfo: Equatable { let title: String; let content: String; let version: Int }

@MainActor
@Observable
final class ClassicsDatabase {
    static let shared = ClassicsDatabase()

    private static let CONFIG_URL = "https://book.xhyeax.cn/config.json"
    private static let DATA_BASE = "https://book.xhyeax.cn/"

    // 默认 booklist（与小程序 config.json 对齐；首次/离线兜底）
    private static let DEFAULT_METAS: [BookMeta] = [
    ]
    // 随包资源名（仅这些 id 有随包 JSON；其它走远程 <id>.json）
    private let bundleNames: [String: String] = [
        "ddj": "daodejing", "zz": "zhuangzi", "lz": "liezi",
        "tanjing": "tanjing", "jingangjing": "jingangjing",
    ]

    private(set) var bookMetas: [BookMeta]
    private(set) var books: [String: [ClassicChapter]] = [:]
    private(set) var update: UpdateInfo?            // config.json 的 update（弹窗用）
    private var remoteFiles: [String: String] = [:] // id -> data 文件名（config 提供）
    private var loading: Set<String> = []
    private var refreshed: Set<String> = []         // 本次会话已做过 ETag 刷新的书

    private init() {
        if let d = UserDefaults.standard.data(forKey: "cfgBooklist"),
           let m = try? JSONDecoder().decode([BookMeta].self, from: d), !m.isEmpty {
            bookMetas = m
        } else {
            bookMetas = Self.DEFAULT_METAS
        }
    }

    func preload() async {
        for m in bookMetas where !m.isYijing { ensureLoaded(m.id) }
    }

    func readerBooks() -> [BookMeta] { bookMetas.filter { !$0.isYijing } }
    func meta(_ id: String) -> BookMeta? { bookMetas.first { $0.id == id } }
    func chapters(_ id: String) -> [ClassicChapter] { books[id] ?? [] }
    func chapter(_ id: String, _ index: Int) -> ClassicChapter? { chapters(id).first { $0.index == index } }

    func search(_ id: String, _ q: String) -> [ClassicChapter] {
        let q = q.trimmingCharacters(in: .whitespaces)
        let list = chapters(id)
        guard !q.isEmpty else { return list }
        return list.filter { c in
            if c.chapter.contains(q) || (c.title ?? "").contains(q) || String(c.index) == q { return true }
            if let ps = c.paragraphs {
                return ps.contains { $0.original.contains(q) || $0.translation.contains(q) }
            }
            return (c.original ?? "").contains(q) || (c.translation ?? "").contains(q)
        }
    }

    // 确保某 reader 书已加载：先随包/缓存立即显示，再后台 ETag 条件刷新（含随包书）
    func ensureLoaded(_ id: String) {
        if books[id]?.isEmpty ?? true {
            if let name = bundleNames[id], let arr = Self.loadBundle(name), !arr.isEmpty { books[id] = arr }
            else if let arr = Self.loadCache(id), !arr.isEmpty { books[id] = arr }
        }
        refreshBook(id)
    }

    // 后台条件 GET（If-None-Match）：变了(200)写缓存+更新内存+存 ETag；未变(304)沿用
    func refreshBook(_ id: String) {
        if refreshed.contains(id) || loading.contains(id) { return }
        refreshed.insert(id)
        loading.insert(id)
        let file = remoteFiles[id] ?? (bundleNames[id].map { $0 + ".json" } ?? (id + ".json"))
        let etag = UserDefaults.standard.string(forKey: "etag_" + id)
        Task {
            let res = await Self.fetchBookConditional(Self.DATA_BASE + file, etag: etag)
            loading.remove(id)
            if let (arr, newEtag) = res, !arr.isEmpty {
                books[id] = arr
                Self.saveCache(id, arr)
                if let e = newEtag { UserDefaults.standard.set(e, forKey: "etag_" + id) }
            }
        }
    }

    // 拉取 config.json：更新 booklist（持久化），返回 booklist 是否变化
    func fetchConfig() async -> Bool {
        guard let url = URL(string: Self.CONFIG_URL) else { return false }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 12
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let cfg = try? JSONDecoder().decode(RemoteConfig.self, from: data),
              !cfg.booklist.isEmpty else { return false }
        var rf: [String: String] = [:]
        let metas: [BookMeta] = cfg.booklist.map { b in
            if let d = b.data { rf[b.id] = d }
            let ic = (b.icon?.isEmpty == false) ? b.icon! : String(b.name.prefix(1))
            return BookMeta(id: b.id, name: b.name, icon: ic, isYijing: b.type == "yijing")
        }
        // remoteFiles 合并：保留旧条目（被删除的书仍可按原文件名/缓存刷新），用 config 覆盖/新增
        for (k, v) in rf { remoteFiles[k] = v }
        if let u = cfg.update {
            update = UpdateInfo(title: u.title ?? "更新内容", content: u.content ?? "", version: u.version ?? 0)
        }
        let sig: ([BookMeta]) -> String = { ms in
            ms.map { "\($0.id)|\($0.name)|\($0.icon)|\($0.isYijing)" }.joined(separator: ",")
        }
        // 合并 booklist：更新已有 + 追加新增；config 删除的本地保留（本地已有缓存）
        var merged = bookMetas
        for m in metas {
            if let i = merged.firstIndex(where: { $0.id == m.id }) { merged[i] = m }
            else { merged.append(m) }
        }
        let changed = sig(bookMetas) != sig(merged)
        bookMetas = merged
        if let d = try? JSONEncoder().encode(merged) { UserDefaults.standard.set(d, forKey: "cfgBooklist") }
        for m in merged where !m.isYijing { ensureLoaded(m.id) }
        return changed
    }

    // MARK: - 文件/网络

    private nonisolated static func loadBundle(_ name: String) -> [ClassicChapter]? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([ClassicChapter].self, from: data)
    }
    private nonisolated static func cacheURL(_ id: String) -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("book_\(id).json")
    }
    private nonisolated static func loadCache(_ id: String) -> [ClassicChapter]? {
        guard let u = cacheURL(id), let d = try? Data(contentsOf: u) else { return nil }
        return try? JSONDecoder().decode([ClassicChapter].self, from: d)
    }
    private nonisolated static func saveCache(_ id: String, _ arr: [ClassicChapter]) {
        guard let u = cacheURL(id), let d = try? JSONEncoder().encode(arr) else { return }
        try? d.write(to: u)
    }
    // 条件 GET：返回 (章节, 新ETag) 仅当 200；304/失败返回 nil（沿用本地）
    private nonisolated static func fetchBookConditional(_ s: String, etag: String?) async -> ([ClassicChapter], String?)? {
        guard let url = URL(string: s) else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 12
        req.cachePolicy = .reloadIgnoringLocalCacheData
        if let etag { req.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { return nil }
        if http.statusCode == 304 { return nil }
        guard http.statusCode == 200,
              let arr = try? JSONDecoder().decode([ClassicChapter].self, from: data) else { return nil }
        return (arr, http.value(forHTTPHeaderField: "Etag"))
    }
}
