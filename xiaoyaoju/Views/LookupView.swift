// Views/LookupView.swift  —  Tab 2: 查卦
import SwiftUI

struct LookupView: View {
    @State private var searchText = ""
    @State private var path = NavigationPath()

    private var db: GuaDatabase { GuaDatabase.shared }
    private var results: [Hexagram] { db.search(searchText) }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: CastInputRoute()) {
                        Label("点选六爻查卦", systemImage: "hand.tap")
                            .foregroundStyle(.blue)
                    }
                }

                ForEach(results) { gua in
                    NavigationLink(value: GuaRoute(number: gua.id)) {
                        guaRow(gua)
                    }
                }
            }
            .navigationTitle("易经")
            .searchable(text: $searchText, prompt: "搜索卦名、卦辞、爻辞")
            .navigationDestination(for: CastInputRoute.self) { _ in
                ManualInputView()
            }
            .navigationDestination(for: GuaRoute.self) { route in
                if let g = db.hexagram(number: route.number) {
                    HexagramDetailView(hexagram: g, showShareActions: true)
                }
            }
        }
        // tabBar 可见性随导航深度同步切换，避免 pop 时 tabBar 延迟出现的闪烁
        .toolbar(path.isEmpty ? .visible : .hidden, for: .tabBar)
    }

    private func guaRow(_ gua: Hexagram) -> some View {
        HStack(spacing: 12) {
            Text(gua.symbol).font(.system(size: 28)).frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(gua.name).font(.body)
                Text("第\(gua.id)卦 · \(gua.desc)")
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.tail)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview { LookupView() }
