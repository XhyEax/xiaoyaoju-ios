// WidgetData.swift — widget 端精简数据（随扩展打包，离线确定性按日选取）
import Foundation

struct GuaLite: Decodable {
    let number: Int
    let name: String
    let symbol: String
    let judgment: String
    let xiang: String
}

struct QuoteLite: Decodable {
    let text: String
    let book: String
    let index: Int
    let source: String
}

enum WidgetData {
    static let guas: [GuaLite] = load("widget_gua")
    static let quotes: [QuoteLite] = load("widget_quotes")

    private static func load<T: Decodable>(_ name: String) -> [T] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let arr = try? JSONDecoder().decode([T].self, from: data) else { return [] }
        return arr
    }

    /// 按「自然日序号」确定性取索引：同一天稳定，跨天轮换
    private static func dayIndex(_ date: Date, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let day = Calendar.current.startOfDay(for: date)
        let n = Int(day.timeIntervalSinceReferenceDate / 86400)
        return ((n % count) + count) % count
    }

    private static var suite: UserDefaults? { UserDefaults(suiteName: "group.com.xhy.shared") }
    private static func offset(_ key: String) -> Int { suite?.integer(forKey: key) ?? 0 }

    static func gua(for date: Date) -> GuaLite? {
        guard !guas.isEmpty else { return nil }
        let i = (dayIndex(date, count: guas.count) + offset("w.gua.offset")) % guas.count
        return guas[(i + guas.count) % guas.count]
    }
    static func quote(for date: Date) -> QuoteLite? {
        guard !quotes.isEmpty else { return nil }
        let i = (dayIndex(date, count: quotes.count) + offset("w.quote.offset")) % quotes.count
        return quotes[(i + quotes.count) % quotes.count]
    }
}

// Deep link（App 端需注册 URL scheme 后才能路由；未注册时点按仅打开 App）
enum WidgetLink {
    static func gua(_ n: Int) -> URL { URL(string: "xiaoyaoju://gua/\(n)")! }
    static func chapter(_ book: String, _ index: Int) -> URL { URL(string: "xiaoyaoju://chapter/\(book)/\(index)")! }
    static let cast = URL(string: "xiaoyaoju://cast")!
}
