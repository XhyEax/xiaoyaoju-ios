// Models/Trigram.swift
// 八卦 + King Wen (upper, lower) -> hexagram number mapping

import Foundation

enum Trigram: Int, CaseIterable {
    case qian = 0  // 乾  阳阳阳  ☰
    case dui  = 1  // 兑  阳阳阴  ☱
    case li   = 2  // 离  阳阴阳  ☲
    case zhen = 3  // 震  阳阴阴  ☳
    case xun  = 4  // 巽  阴阳阳  ☴
    case kan  = 5  // 坎  阴阳阴  ☵
    case gen  = 6  // 艮  阴阴阳  ☶
    case kun  = 7  // 坤  阴阴阴  ☷

    var chineseName: String {
        switch self {
        case .qian: return "乾"
        case .dui:  return "兑"
        case .li:   return "离"
        case .zhen: return "震"
        case .xun:  return "巽"
        case .kan:  return "坎"
        case .gen:  return "艮"
        case .kun:  return "坤"
        }
    }

    /// The three yao values (bottom to top), true = yang, false = yin
    var yangLines: [Bool] {
        switch self {
        case .qian: return [true,  true,  true ]
        case .dui:  return [true,  true,  false]
        case .li:   return [true,  false, true ]
        case .zhen: return [true,  false, false]
        case .xun:  return [false, true,  true ]
        case .kan:  return [false, true,  false]
        case .gen:  return [false, false, true ]
        case .kun:  return [false, false, false]
        }
    }

    /// Match a trigram from 3 boolean yang values (bottom to top)
    static func from(yangLines bools: [Bool]) -> Trigram? {
        allCases.first { $0.yangLines == bools }
    }
}

// King Wen number table indexed by [upper.rawValue][lower.rawValue]
// Rows = upper trigram (乾兑离震巽坎艮坤 = index 0-7)
// Cols = lower trigram (same order)
// Verified against: 1乾乾 2坤坤 3坎震 4艮坎 5坎乾 6乾坎 7坤坎 8坎坤
// 9巽乾 10乾兑 11坤乾 12乾坤 13乾离 14离乾 15坤艮 16震坤 17兑震 18艮巽
// 19坤兑 20巽坤 21离震 22艮离 23艮坤 24坤震 25乾震 26艮乾 27艮震 28兑巽
// 29坎坎 30离离 31兑艮 32震巽 33乾艮 34震乾 35离坤 36坤离 37巽离 38离兑
// 39坎艮 40震坎 41艮兑 42巽震 43兑乾 44乾巽 45兑坤 46坤巽 47兑坎 48坎巽
// 49兑离 50离巽 51震震 52艮艮 53巽艮 54震兑 55震离 56离艮 57巽巽 58兑兑
// 59巽坎 60坎兑 61巽兑 62震艮 63坎离 64离坎
private let kingWenTable: [[Int]] = [
    // lower:  乾   兑   离   震   巽   坎   艮   坤
    /* 乾上 */ [ 1,  10,  13,  25,  44,   6,  33,  12],
    /* 兑上 */ [43,  58,  49,  17,  28,  47,  31,  45],
    /* 离上 */ [14,  38,  30,  21,  50,  64,  56,  35],
    /* 震上 */ [34,  54,  55,  51,  32,  40,  62,  16],
    /* 巽上 */ [ 9,  61,  37,  42,  57,  59,  53,  20],
    /* 坎上 */ [ 5,  60,  63,   3,  48,  29,  39,   8],
    /* 艮上 */ [26,  41,  22,  27,  18,   4,  52,  23],
    /* 坤上 */ [11,  19,  36,  24,  46,   7,  15,   2],
]

func kingWenNumber(upper: Trigram, lower: Trigram) -> Int {
    kingWenTable[upper.rawValue][lower.rawValue]
}

/// Derive the trigram from 3 consecutive line-values (6/7/8/9), bottom to top
func trigram(from lineValues: ArraySlice<Int>) -> Trigram? {
    let arr = Array(lineValues)
    guard arr.count == 3 else { return nil }
    let bools = arr.map { $0 == 7 || $0 == 9 }  // yang if odd
    return Trigram.from(yangLines: bools)
}

/// Overload accepting plain [Int]
func trigram(from lineValues: [Int]) -> Trigram? {
    trigram(from: lineValues[...])
}
