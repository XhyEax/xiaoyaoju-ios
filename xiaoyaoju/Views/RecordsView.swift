// Views/RecordsView.swift
// 收藏 / 笔记 / 历史 三分段的容器（各分段实现见 FavoritesView / NotesPane / RecordsListPane）

import SwiftUI
import SwiftData

extension Date {
    /// "2026年6月6日 15:30"
    var displayString: String {
        formatted(.dateTime
            .year(.defaultDigits)
            .month(.wide)
            .day()
            .hour(.defaultDigits(amPM: .omitted))
            .minute(.twoDigits)
            .locale(Locale(identifier: "zh_CN")))
    }
}

// 复用的内联搜索框（置于分段控件下方，外观/占位色与系统搜索框一致）
struct InlineSearchBar: View {
    @Binding var text: String
    var prompt: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.subheadline)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal).padding(.bottom, 6)
    }
}

struct RecordsView: View {
    @State private var seg = 0   // 0=收藏 1=笔记 2=历史
    @State private var path = NavigationPath()

    private var db: GuaDatabase { GuaDatabase.shared }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("", selection: $seg) {
                    Text("收藏").tag(0)
                    Text("笔记").tag(1)
                    Text("历史").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)

                // 各分段自含搜索/多选/导入导出（切换分段即卸载、状态自动复位）
                switch seg {
                case 0:  FavoritesView()
                case 1:  NotesPane()
                default: RecordsListPane()
                }
            }
            // 三分段可跳转：历史记录详情 / 易经卦象 / 典籍章节，全部 value-based 以便 path 追踪
            .navigationDestination(for: CastRecord.self) { RecordDetailView(record: $0) }
            .navigationDestination(for: GuaRoute.self) { route in
                if let g = db.hexagram(number: route.number) {
                    HexagramDetailView(hexagram: g, showShareActions: true, initialAnchor: route.anchor)
                }
            }
            .navigationDestination(for: ChapterRoute.self) { route in
                BookChapterView(bookId: route.bookId, index: route.index, highlight: route.highlight, anchor: route.anchor)
            }
        }
        // tabBar 可见性随导航深度同步切换，避免 pop 时 tabBar 延迟出现的闪烁
        .toolbar(path.isEmpty ? .visible : .hidden, for: .tabBar)
    }
}

#Preview {
    RecordsView()
        .modelContainer(for: CastRecord.self, inMemory: true)
}
