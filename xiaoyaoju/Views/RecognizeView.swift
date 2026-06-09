// Views/RecognizeView.swift  —  Tab 1: 起卦（手动点选）
import SwiftUI
import SwiftData

struct RecognizeView: View {
    var body: some View {
        NavigationStack {
            CastingContent(navigationTitle: "六爻起卦（背面为阳）")
        }
    }
}

#Preview {
    RecognizeView().modelContainer(for: CastRecord.self, inMemory: true)
}
