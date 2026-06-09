// Models/Divination.swift
import Foundation

/// A single line result from one coin toss
struct DivinationLine: Identifiable, Equatable {
    let id = UUID()
    /// Raw value: 6 = 老阴(动), 7 = 少阳(静), 8 = 少阴(静), 9 = 老阳(动)
    let value: Int

    var isYang: Bool { value == 7 || value == 9 }
    var isMoving: Bool { value == 6 || value == 9 }

    var label: String {
        switch value {
        case 9: return "老阳"
        case 7: return "少阳"
        case 8: return "少阴"
        case 6: return "老阴"
        default: return ""
        }
    }
}

/// A complete 6-line cast (本卦 + optional 变卦)
struct Cast: Equatable {
    /// Lines in order from 初爻(index 0) to 上爻(index 5)
    let lines: [DivinationLine]

    /// Indices of moving lines (0-based)
    var movingLineIndexes: [Int] {
        lines.indices.filter { lines[$0].isMoving }
    }

    /// King Wen number for 本卦
    var benGuaNumber: Int? {
        guard lines.count == 6 else { return nil }
        let lower = trigram(from: lines[0...2].map(\.value))
        let upper = trigram(from: lines[3...5].map(\.value))
        guard let l = lower, let u = upper else { return nil }
        return kingWenNumber(upper: u, lower: l)
    }

    /// Line values for 变卦 (all moving lines flipped); nil if no moving lines
    var bianGuaLineValues: [Int]? {
        guard !movingLineIndexes.isEmpty else { return nil }
        return lines.map { line in
            if line.isMoving { return line.value == 9 ? 8 : 7 }
            return line.value
        }
    }

    /// King Wen number for 变卦 (nil if no moving lines)
    var bianGuaNumber: Int? {
        guard !movingLineIndexes.isEmpty else { return nil }
        let changedValues = lines.map { line -> Int in
            if line.isMoving {
                return line.value == 9 ? 8 : 7   // 老阳→少阴, 老阴→少阳
            }
            return line.value
        }
        let lower = trigram(from: Array(changedValues[0...2]))
        let upper = trigram(from: Array(changedValues[3...5]))
        guard let l = lower, let u = upper else { return nil }
        return kingWenNumber(upper: u, lower: l)
    }
}

/// Convert the number of 背(yang) faces from one toss into a line value
/// backs: 0..3
func lineValue(fromBacks backs: Int) -> Int? {
    switch backs {
    case 3: return 9   // 老阳 (3 背)
    case 2: return 8   // 少阴 (2 背)
    case 1: return 7   // 少阳 (1 背)
    case 0: return 6   // 老阴 (0 背)
    default: return nil
    }
}
