// Views/LookupView.swift  —  Tab 2: 查卦
import SwiftUI

struct LookupView: View {
    @State private var searchText = ""

    private var db: GuaDatabase { GuaDatabase.shared }
    private var results: [Hexagram] { db.search(searchText) }

    var body: some View {
        NavigationStack {
            List {
                    
              
                        Section {
                            NavigationLink {
                                ManualInputView()
                            } label: {
                                Label("点选六爻查卦", systemImage: "hand.tap")
                                    .foregroundStyle(.blue)
                            }
                        }
                    
                    
//                    Section("全部六十四卦") {
                        ForEach(results) { gua in
                            NavigationLink {
                                HexagramDetailView(hexagram: gua, showShareActions: true)
                            } label: {
                                guaRow(gua)
                            }
                        }
//                    }

                }
                .navigationTitle("易经")
                .searchable(text: $searchText, prompt: "搜索卦名、卦辞、爻辞")
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
