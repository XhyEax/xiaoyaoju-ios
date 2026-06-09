// Models/Hexagram.swift
import Foundation

struct Yao: Codable, Identifiable {
    var id: String { title }
    let title: String    // 初九/六二 etc.
    let content: String  // 爻辞
    let xiang: String    // 小象
}

struct Hexagram: Codable, Identifiable {
    let id: Int          // King Wen number 1-64 (injected at decode time)
    let name: String     // e.g. 乾为天
    let symbol: String   // Unicode hexagram symbol e.g. ䷀
    let desc: String     // 卦辞 (keyed "desc" in JSON)
    let xiangyue: String // 大象
    let yaos: [Yao]      // 6 lines, index 0 = 初爻
}
