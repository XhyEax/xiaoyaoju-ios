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
