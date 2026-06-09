// Views/ManualInputView.swift  —  查卦 → 手动点选六爻（复用起卦页）
import SwiftUI
import SwiftData

struct ManualInputView: View {
    var body: some View {
        CastingContent(navigationTitle: "手动点选六爻")
    }
}

#Preview {
    NavigationStack { ManualInputView() }
        .modelContainer(for: CastRecord.self, inMemory: true)
}
