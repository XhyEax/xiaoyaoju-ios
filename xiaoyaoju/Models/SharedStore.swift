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

    /// 全局唯一容器（CastRecord 历史 + NoteRecord 笔记，均经 CloudKit 同步）。
    /// App 与 NotesStore 共用这一个，避免多容器写同一文件。
    static let shared: ModelContainer = makeContainer()

    /// CloudKit 私有容器（需在 Xcode 的 iCloud 能力里建好同名容器）
    static let cloudContainerID = "iCloud.com.xhy.xiaoyaoju"

    /// 构建 ModelContainer。
    /// 关键不变量：**始终固定在 App Group 的同一个 store 文件**，开 CloudKit 失败时只退回
    /// 「同一文件的纯本地(.none)」，**绝不**打开「默认位置的空库」——否则会静默丢数据观感。
    static func makeContainer() -> ModelContainer {
        let schema = Schema([CastRecord.self, NoteRecord.self])
        let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: storeName)

        func config(cloud: Bool) -> ModelConfiguration {
            let db: ModelConfiguration.CloudKitDatabase = cloud ? .private(cloudContainerID) : .none
            if let url {
                return ModelConfiguration(schema: schema, url: url, cloudKitDatabase: db)
            }
            return ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: db)
        }

        // 1) 优先：同一文件 + CloudKit 镜像（本地始终留一份，多设备经 iCloud 同步）
        if let c = try? ModelContainer(for: schema, configurations: [config(cloud: true)]) {
            migrateLegacyIfNeeded(into: c); return c
        }
        // 2) 回退：同一文件 + 纯本地（容器没建好/未登录 iCloud 时，数据照样在、不丢）
        do {
            let c = try ModelContainer(for: schema, configurations: [config(cloud: false)])
            migrateLegacyIfNeeded(into: c); return c
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
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
