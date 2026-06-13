// Views/LookupView.swift  —  Tab 2: 查卦
import SwiftUI

struct LookupView: View {
    @State private var searchText = ""

    private var db: GuaDatabase { GuaDatabase.shared }
    private var results: [Hexagram] { db.search(searchText) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    Section("全部六十四卦") {
                        ForEach(results) { gua in
                            NavigationLink {
                                HexagramDetailView(hexagram: gua, showShareActions: true)
                            } label: {
                                guaRow(gua)
                            }
                        }
                    }

                    Section {
                        NavigationLink {
                            ManualInputView()
                        } label: {
                            Label("手动点选六爻查询", systemImage: "hand.tap")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .navigationTitle("易经")
                .searchable(text: $searchText, prompt: "搜索卦名、卦辞、爻辞")
                .onReceive(NotificationCenter.default.publisher(for: .tabReselected)) { _ in
                    if let first = results.first { withAnimation { proxy.scrollTo(first.id, anchor: .top) } }
                }
            }
        }
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
