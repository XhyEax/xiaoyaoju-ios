// Models/Classics.swift
// 道德经 / 庄子 数据模型与加载（自随包 JSON 文档）
import Foundation

// MARK: - 道德经

struct DaodejingChapter: Codable, Identifiable {
    var id: Int { index }
    let index: Int
    let chapter: String      // 第一章
    let title: String        // 道经·第一章
    let original: String     // 原文
    let annotation: String   // 注释
    let translation: String  // 译文
}

// MARK: - 庄子

struct ZhuangziPara: Codable, Identifiable {
    let original: String
    let annotation: String
    let translation: String
    var id: String { original }
}

struct ZhuangziChapter: Codable, Identifiable {
    var id: Int { index }
    let index: Int
    let chapter: String          // 逍遥游第一
    let title: String            // 内篇·逍遥游第一
    let paragraphs: [ZhuangziPara]
}

// MARK: - 加载

@MainActor
final class ClassicsDatabase {
    static let shared = ClassicsDatabase()
    private init() {}

    private(set) var daodejing: [DaodejingChapter] = []
    private(set) var zhuangzi: [ZhuangziChapter] = []

    func preload() async {
        guard daodejing.isEmpty && zhuangzi.isEmpty else { return }
        let (ddj, zz) = await Task.detached(priority: .userInitiated) {
            (Self.load("daodejing", as: [DaodejingChapter].self) ?? [],
             Self.load("zhuangzi", as: [ZhuangziChapter].self) ?? [])
        }.value
        self.daodejing = ddj
        self.zhuangzi = zz
    }

    func ddjChapter(_ index: Int) -> DaodejingChapter? { daodejing.first { $0.index == index } }
    func zzChapter(_ index: Int) -> ZhuangziChapter? { zhuangzi.first { $0.index == index } }

    func searchDaodejing(_ q: String) -> [DaodejingChapter] {
        let q = q.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return daodejing }
        return daodejing.filter {
            $0.chapter.contains(q) || $0.title.contains(q)
            || $0.original.contains(q) || $0.translation.contains(q) || String($0.index) == q
        }
    }

    func searchZhuangzi(_ q: String) -> [ZhuangziChapter] {
        let q = q.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return zhuangzi }
        return zhuangzi.filter { c in
            c.chapter.contains(q) || c.title.contains(q)
            || c.paragraphs.contains { $0.original.contains(q) || $0.translation.contains(q) }
        }
    }

    private nonisolated static func load<T: Decodable>(_ name: String, as: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
