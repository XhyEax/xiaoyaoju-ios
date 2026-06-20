// Models/WidgetBridge.swift — 向「最近一卦」widget 发布共享摘要并刷新时间线
import Foundation
import SwiftData
import WidgetKit

enum WidgetBridge {
    private static let suite = UserDefaults(suiteName: SharedStore.appGroupID)

    /// 写入指定记录摘要；传 nil 表示按库中最新一条
    @MainActor
    static func publishLatest(_ record: CastRecord? = nil) {
        guard let s = suite else { return }
        let r = record ?? latestRecord()
        if let r {
            s.set(GuaDatabase.shared.hexagram(number: r.benGua)?.name ?? "", forKey: "w.latest.name")
            s.set(r.question, forKey: "w.latest.q")
            s.set(r.date, forKey: "w.latest.date")
            s.set(r.benGua, forKey: "w.latest.num")
        } else {
            ["w.latest.name", "w.latest.q", "w.latest.date", "w.latest.num"].forEach { s.removeObject(forKey: $0) }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    @MainActor
    private static func latestRecord() -> CastRecord? {
        var fd = FetchDescriptor<CastRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        fd.fetchLimit = 1
        return try? SharedStore.shared.mainContext.fetch(fd).first
    }
}
