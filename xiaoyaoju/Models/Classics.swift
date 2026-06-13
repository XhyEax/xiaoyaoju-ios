// Models/Classics.swift
// 典籍数据模型与加载（随包 JSON，booklist 驱动，双格式自适应）
import Foundation

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
    // 列表摘要原始文本（有段落取首段原文，否则整段原文）
    var snippetRaw: String { paragraphs?.first?.original ?? (original ?? "") }
}

// MARK: - 典籍清单项

struct BookMeta: Identifiable {
    let id: String
    let name: String
    let icon: String
    var isYijing: Bool = false
}

// MARK: - 加载

@MainActor
final class ClassicsDatabase {
    static let shared = ClassicsDatabase()
    private init() {}

    // 典籍清单（与小程序 config.json booklist 对齐；易经为 64 卦工具，单独 tab）
    let bookMetas: [BookMeta] = [
        BookMeta(id: "ddj", name: "道德经", icon: "道"),
        BookMeta(id: "zz", name: "庄子", icon: "庄"),
        BookMeta(id: "yj", name: "易经", icon: "易", isYijing: true),
        BookMeta(id: "lz", name: "列子", icon: "列"),
        BookMeta(id: "tanjing", name: "坛经", icon: "坛"),
        BookMeta(id: "jingangjing", name: "金刚经", icon: "金"),
    ]

    // 阅读类典籍 id -> 随包 Data/<file>.json
    private let files: [String: String] = [
        "ddj": "daodejing", "zz": "zhuangzi", "lz": "liezi",
        "tanjing": "tanjing", "jingangjing": "jingangjing",
    ]
    private(set) var books: [String: [ClassicChapter]] = [:]

    func preload() async {
        guard books.isEmpty else { return }
        let files = self.files
        let loaded = await Task.detached(priority: .userInitiated) { () -> [String: [ClassicChapter]] in
            var m: [String: [ClassicChapter]] = [:]
            for (id, name) in files {
                m[id] = Self.load(name, as: [ClassicChapter].self) ?? []
            }
            return m
        }.value
        self.books = loaded
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

    private nonisolated static func load<T: Decodable>(_ name: String, as: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
