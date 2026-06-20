// Models/CastRecord.swift
import Foundation
import SwiftData

@Model
final class CastRecord {
    // 注：CloudKit 要求每个属性「可选」或「有默认值」，故下列均带默认值
    var date: Date = Date.distantPast
    var question: String = ""      // 问题/事由
    var transcript: String = ""    // 原文（6次摇卦拼接）
    var note: String = ""         // 笔记（事后在历史记录中添加）
    var method: String = "铜钱起卦"  // 起卦方式：铜钱起卦 / 手机起卦
    var lineValues: [Int] = []    // 6 个 6/7/8/9，依序从初爻到上爻
    var benGua: Int = 0           // 本卦 King Wen 编号
    var bianGua: Int?             // 变卦（无动爻则 nil）

    init(date: Date = .now,
         question: String = "",
         transcript: String = "",
         note: String = "",
         method: String = "铜钱起卦",
         lineValues: [Int],
         benGua: Int,
         bianGua: Int? = nil) {
        self.date = date
        self.question = question
        self.transcript = transcript
        self.note = note
        self.method = method
        self.lineValues = lineValues
        self.benGua = benGua
        self.bianGua = bianGua
    }
}
