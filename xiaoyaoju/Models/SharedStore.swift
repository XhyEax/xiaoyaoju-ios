// Models/SharedStore.swift
// 六爻历史记录共享存储：liuyao 与 xiaoyaoju 通过 App Group 共用同一 SwiftData 库。
// 两个 App 用相同的 group 标识与 store 文件，写入即互通。
import Foundation
import SwiftData

enum SharedStore {
    /// App Group 标识——liuyao 与 xiaoyaoju 必须一致
    static let appGroupID = "group.com.xhy.shared"
    /// 共享库文件名
    static let storeName = "CastRecords.store"

    /// 构建指向 App Group 容器的 ModelContainer；容器不可用时退回本地默认库（兜底不崩）。
    static func makeContainer() -> ModelContainer {
        let schema = Schema([CastRecord.self])
        let config: ModelConfiguration
        if let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: storeName) {
            config = ModelConfiguration(schema: schema, url: groupURL)
        } else {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        migrateLegacyIfNeeded(into: container)
        return container
    }

    /// 一次性迁移：把旧的本地默认库（default.store）记录并入共享库，按 date 去重。
    /// 仅首次执行；失败均静默兜底，不影响启动。
    private static func migrateLegacyIfNeeded(into container: ModelContainer) {
        let flagKey = "migratedToAppGroup_v1"
        let ud = UserDefaults.standard
        if ud.bool(forKey: flagKey) { return }
        defer { ud.set(true, forKey: flagKey) }

        guard let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let legacyURL = appSupport.appending(path: "default.store")
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return }

        let schema = Schema([CastRecord.self])
        guard let legacy = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: legacyURL)]
        ) else { return }

        let legacyCtx = ModelContext(legacy)
        guard let old = try? legacyCtx.fetch(FetchDescriptor<CastRecord>()), !old.isEmpty else { return }

        let newCtx = ModelContext(container)
        let existing = Set((try? newCtx.fetch(FetchDescriptor<CastRecord>()))?.map(\.date) ?? [])
        for r in old where !existing.contains(r.date) {
            newCtx.insert(CastRecord(date: r.date, question: r.question, transcript: r.transcript,
                                     note: r.note, method: r.method, lineValues: r.lineValues,
                                     benGua: r.benGua, bianGua: r.bianGua))
        }
        try? newCtx.save()
    }
}
