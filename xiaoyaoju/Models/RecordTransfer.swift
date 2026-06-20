// Models/RecordTransfer.swift
// JSON 导入/导出支持
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// 可编码的卦记录传输对象
struct RecordDTO: Codable {
    var date: Date
    var question: String
    var transcript: String
    var note: String
    var method: String
    var lineValues: [Int]
    var benGua: Int
    var bianGua: Int?
}

extension CastRecord {
    var dto: RecordDTO {
        RecordDTO(date: date, question: question, transcript: transcript,
                  note: note, method: method, lineValues: lineValues,
                  benGua: benGua, bianGua: bianGua)
    }

    convenience init(dto: RecordDTO) {
        self.init(date: dto.date, question: dto.question, transcript: dto.transcript,
                  note: dto.note, method: dto.method, lineValues: dto.lineValues,
                  benGua: dto.benGua, bianGua: dto.bianGua)
    }
}

/// 全量备份：收藏 + 笔记 + 历史（单文件导入导出）
struct BackupData: Codable {
    var version: Int = 1
    var favorites: [String: [Int]] = [:]   // fav_<kind> -> [Int]
    var notes: [NoteDTO] = []
    var records: [RecordDTO] = []
}

/// 用于 fileExporter / fileImporter 的 JSON 文档
struct RecordsJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum RecordTransfer {
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return e
    }

    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

// MARK: - 纯导入/导出逻辑（无 UI/无副作用，便于单元测试）
extension RecordTransfer {
    static func encode<T: Encodable>(_ value: T) -> Data? { try? encoder().encode(value) }
    static func decodeRecords(_ data: Data) -> [RecordDTO]? { try? decoder().decode([RecordDTO].self, from: data) }
    static func decodeNotes(_ data: Data) -> [NoteDTO]? { try? decoder().decode([NoteDTO].self, from: data) }

    /// 记录导入分流：按时间(date)去重 → (可直接新增, 时间重复待决定)
    static func planRecordImport(incoming: [RecordDTO],
                                 existingDates: Set<Date>) -> (new: [RecordDTO], conflicts: [RecordDTO]) {
        var new: [RecordDTO] = []
        var conflicts: [RecordDTO] = []
        for dto in incoming {
            if existingDates.contains(dto.date) { conflicts.append(dto) } else { new.append(dto) }
        }
        return (new, conflicts)
    }

    /// 笔记导入过滤：空文本视为无效 → (有效, 跳过数)
    static func validNotes(_ dtos: [NoteDTO]) -> (valid: [NoteDTO], skipped: Int) {
        var valid: [NoteDTO] = []
        var skipped = 0
        for d in dtos {
            if d.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { skipped += 1 }
            else { valid.append(d) }
        }
        return (valid, skipped)
    }

    static func recordsFileName(date: Date = Date()) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd_HHmm"; f.locale = Locale(identifier: "zh_CN")
        return "六爻记录_" + f.string(from: date)
    }
    static func backupFileName(date: Date = Date()) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd_HHmm"; f.locale = Locale(identifier: "zh_CN")
        return "逍遥居数据备份_" + f.string(from: date) + ".json"
    }
    static func notesFileName(date: Date = Date()) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd_HHmm"; f.locale = Locale(identifier: "zh_CN")
        return "经典笔记_" + f.string(from: date) + ".json"
    }
}
