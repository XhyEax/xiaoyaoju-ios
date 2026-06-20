// RefreshIntents.swift — 交互式 widget 的「换一条」按钮（iOS 17+）
import AppIntents
import Foundation

private let groupSuite = "group.com.xhy.shared"

// 随机换一条：把 offset 设成一个与当前不同的随机值（显示项 = (dayIndex+offset)%count）
private func randomizeOffset(_ key: String) {
    let s = UserDefaults(suiteName: groupSuite)
    let cur = s?.integer(forKey: key) ?? 0
    var n = cur
    while n == cur { n = Int.random(in: 0..<100_000) }
    s?.set(n, forKey: key)
}

struct NextGuaIntent: AppIntent {
    static var title: LocalizedStringResource = "换一卦"
    func perform() async throws -> some IntentResult {
        randomizeOffset("w.gua.offset")
        return .result()
    }
}

struct NextQuoteIntent: AppIntent {
    static var title: LocalizedStringResource = "换一句"
    func perform() async throws -> some IntentResult {
        randomizeOffset("w.quote.offset")
        return .result()
    }
}
