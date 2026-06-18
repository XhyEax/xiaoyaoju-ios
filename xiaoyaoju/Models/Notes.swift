// Models/Notes.swift
// 章节 / 段落 / 易经笔记（按 kind 分类持久化：note_<kind> -> { 笔记标识: 文本 }）
// 标识格式：单章「<章序号>」；分段「<章序号>-<段序号>」；
//          易经「<卦号>-judgment / <卦号>-image / <卦号>-yao<行号>」
import SwiftUI

@Observable
final class NotesStore {
    static let shared = NotesStore()

    private var store: [String: [String: String]] = [:]

    private init() {
        // 扫描所有 note_* 键，载入已有笔记
        for (k, v) in UserDefaults.standard.dictionaryRepresentation() where k.hasPrefix("note_") {
            if let d = v as? [String: String] { store[String(k.dropFirst(5))] = d }
        }
    }

    func map(_ kind: String) -> [String: String] { store[kind] ?? [:] }
    func get(_ kind: String, _ id: String) -> String { store[kind]?[id] ?? "" }
    var isEmpty: Bool { store.values.allSatisfy { $0.isEmpty } }

    /// 保存（空文本即删除该条）
    func set(_ kind: String, _ id: String, _ text: String) {
        var m = store[kind] ?? [:]
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { m.removeValue(forKey: id) } else { m[id] = t }
        store[kind] = m
        UserDefaults.standard.set(m, forKey: "note_" + kind)
    }
}

// MARK: - 笔记列表项（跨典籍汇总，可跳转）
struct NoteItem: Identifiable {
    let id: String        // 唯一键 kind|anchor
    let kind: String      // yj / ddj / zz …
    let refId: Int        // 章序号 或 卦号（用于跳转）
    let anchor: String    // 笔记标识（note key）
    let tag: String       // 图标字
    let title: String     // 《庄子》齐物论第二 · 第1段：…
    let sub: String       // 笔记内容预览
    let text: String      // 笔记全文
}

// MARK: - 导入导出 DTO（与 book.html 对齐：{ book, key, text, title }）
struct NoteDTO: Codable {
    let book: String
    let key: String
    let text: String
    let title: String?
}

// MARK: - 汇总各典籍笔记，生成可跳转列表
@MainActor
func buildNoteList() -> [NoteItem] {
    let notes = NotesStore.shared
    let cdb = ClassicsDatabase.shared
    let gdb = GuaDatabase.shared
    var out: [NoteItem] = []

    for b in cdb.bookMetas {
        let tag = b.icon
        let m = notes.map(b.id)
        if b.isYijing {
            for (k, text) in m where !text.isEmpty {
                guard let dash = k.lastIndex(of: "-"),
                      let gid = Int(k[..<dash]),
                      let g = gdb.hexagram(number: gid) else { continue }
                let section = String(k[k.index(after: dash)...])
                var secName = section, orig = ""
                if section == "judgment" { secName = "卦辞"; orig = g.desc }
                else if section == "image" { secName = "大象传"; orig = g.xiangyue }
                else if section.hasPrefix("yao"), let yi = Int(section.dropFirst(3)), yi < g.yaos.count {
                    secName = g.yaos[yi].title; orig = g.yaos[yi].content
                }
                let preview = orig.isEmpty ? "" : "：" + snip(stripMarks(orig), 12)
                out.append(NoteItem(id: b.id + "|" + k, kind: b.id, refId: gid, anchor: k, tag: tag,
                                    title: "《\(b.name)》\(g.name) · \(secName)\(preview)",
                                    sub: snip(text, 40), text: text))
            }
        } else {
            for (k, text) in m where !text.isEmpty {
                let chapIdxStr: String, pi: Int?
                if let dash = k.lastIndex(of: "-") {
                    chapIdxStr = String(k[..<dash]); pi = Int(k[k.index(after: dash)...])
                } else { chapIdxStr = k; pi = nil }
                guard let chapIdx = Int(chapIdxStr), let c = cdb.chapter(b.id, chapIdx) else { continue }
                var title = "《\(b.name)》\(c.chapter)"
                if let pi, let ps = c.paragraphs, pi < ps.count {
                    title += " · 第\(pi + 1)段：" + snip(stripMarks(ps[pi].original), 12)
                } else {
                    let orig = (c.paragraphs?.first?.original ?? c.original) ?? ""
                    if !orig.isEmpty { title += "：" + snip(stripMarks(orig), 12) }
                }
                out.append(NoteItem(id: b.id + "|" + k, kind: b.id, refId: chapIdx, anchor: k, tag: tag,
                                    title: title, sub: snip(text, 40), text: text))
            }
        }
    }
    return out
}

// MARK: - 笔记编辑标的（用于 .sheet(item:)）
struct NoteTarget: Identifiable {
    let kind: String
    let key: String
    var id: String { kind + "|" + key }
}
