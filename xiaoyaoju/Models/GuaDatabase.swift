// Models/GuaDatabase.swift
import Foundation

private struct RawHexagram: Codable {
    let name: String
    let symbol: String
    let desc: String
    let xiangyue: String
    let yaos: [Yao]
}

@MainActor
final class GuaDatabase {
    static let shared = GuaDatabase()

    // Mutable: empty until preload() completes
    private var data: [Int: Hexagram] = [:]

    // Empty init — no file I/O on main thread at init time
    private init() {}

    /// Call once at app launch. Reads JSON on a background thread, then
    /// stores the result back on the main actor. Idempotent.
    func preload() async {
        guard data.isEmpty else { return }
        let loaded = await Task.detached(priority: .userInitiated) {
            Self.loadBundle()
        }.value
        self.data = loaded
    }

    // MARK: - Queries (all safe on MainActor after preload)

    var all: [Hexagram] {
        data.values.sorted { $0.id < $1.id }
    }

    func hexagram(number: Int) -> Hexagram? { data[number] }

    func search(_ query: String) -> [Hexagram] {
        guard !query.isEmpty else { return all }
        return all.filter { g in
            g.name.contains(query)
            || g.desc.contains(query)
            || g.xiangyue.contains(query)
            || g.yaos.contains { $0.title.contains(query) || $0.content.contains(query) || $0.xiang.contains(query) }
        }
    }

    // MARK: - Private bundle loader (runs on background thread)

    // nonisolated so Task.detached can call it without actor hop
    private nonisolated static func loadBundle() -> [Int: Hexagram] {
        guard let url = Bundle.main.url(forResource: "guadata", withExtension: "json"),
              let jsonData = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: RawHexagram].self, from: jsonData)
        else { return [:] }

        var dict = [Int: Hexagram]()
        for (key, r) in raw {
            if let num = Int(key) {
                dict[num] = Hexagram(id: num, name: r.name, symbol: r.symbol,
                                     desc: r.desc, xiangyue: r.xiangyue, yaos: r.yaos)
            }
        }
        return dict
    }
}
