// Models/Notes.swift
// 章节 / 段落 / 易经笔记（按 kind 分类持久化：note_<kind> -> { 笔记标识: 文本 }）
// 标识格式：单章「<章序号>」；分段「<章序号>-<段序号>」；
//          易经「<卦号>-judgment / <卦号>-image / <卦号>-yao<行号>」
import SwiftUI
import SwiftData
import CoreData

// 笔记记录（CloudKit 同步）。CloudKit 不支持唯一约束，(kind,key) 唯一性由代码 upsert 保证。
@Model
final class NoteRecord {
    var kind: String = ""      // yj / ddj / zz …
    var key: String = ""       // 笔记标识（anchor）
    var text: String = ""
    var updatedAt: Date = Date.distantPast

    init(kind: String, key: String, text: String, updatedAt: Date = .now) {
        self.kind = kind; self.key = key; self.text = text; self.updatedAt = updatedAt
    }
}

@MainActor
@Observable
final class NotesStore {
    static let shared = NotesStore()

    // 同步读用的内存缓存：kind -> { key: text }；写时同步更新，CloudKit 远端变更后重载
    private var cache: [String: [String: String]] = [:]
    @ObservationIgnored private let ctx = SharedStore.shared.mainContext

    private init() {
        migrateFromUserDefaultsIfNeeded()
        reload()
        // CloudKit 远端合并进本地后刷新缓存（mainContext 会自动合并远端变更）
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.reload() } }
    }

    func map(_ kind: String) -> [String: String] { cache[kind] ?? [:] }
    func get(_ kind: String, _ id: String) -> String { cache[kind]?[id] ?? "" }

    /// 保存（空文本即删除该条）
    func set(_ kind: String, _ id: String, _ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = fetch(kind, id)
        if t.isEmpty {
            if let e = existing { ctx.delete(e) }
        } else if let e = existing {
            e.text = t; e.updatedAt = .now
        } else {
            ctx.insert(NoteRecord(kind: kind, key: id, text: t))
        }
        try? ctx.save()
        // 同步更新缓存
        var m = cache[kind] ?? [:]
        if t.isEmpty { m.removeValue(forKey: id) } else { m[id] = t }
        cache[kind] = m
    }

    private func fetch(_ kind: String, _ key: String) -> NoteRecord? {
        let pred = #Predicate<NoteRecord> { $0.kind == kind && $0.key == key }
        return try? ctx.fetch(FetchDescriptor(predicate: pred)).first
    }

    private func reload() {
        var c: [String: [String: String]] = [:]
        if let all = try? ctx.fetch(FetchDescriptor<NoteRecord>()) {
            for r in all where !r.text.isEmpty { c[r.kind, default: [:]][r.key] = r.text }
        }
        cache = c
    }

    // 一次性迁移：把旧的 UserDefaults「note_<kind>」笔记并入 SwiftData（保留旧数据不删，作兜底）
    private func migrateFromUserDefaultsIfNeeded() {
        let flag = "notesMigratedToSwiftData_v1"
        let ud = UserDefaults.standard
        if ud.bool(forKey: flag) { return }
        defer { ud.set(true, forKey: flag) }
        for (k, v) in ud.dictionaryRepresentation() where k.hasPrefix("note_") {
            guard let d = v as? [String: String] else { continue }
            let kind = String(k.dropFirst(5))
            for (key, text) in d where !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if fetch(kind, key) == nil { ctx.insert(NoteRecord(kind: kind, key: key, text: text)) }
            }
        }
        try? ctx.save()
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
