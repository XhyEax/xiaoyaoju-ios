// Views/RecordDetailView.swift — 历史记录详情（卦象 + 问题/记录/动爻/笔记 编辑 + 分享）
import SwiftUI
import SwiftData
import UIKit

struct RecordDetailView: View {
    @Bindable var record: CastRecord

    enum EditField { case transcript, note }

    /// Local drafts — only written back on explicit Save
    @State private var draftTranscript = ""
    @State private var draftNote = ""
    /// Which field's edit bar is currently shown (nil = none)
    @State private var editingField: EditField?
    @FocusState private var transcriptFocused: Bool
    @FocusState private var noteFocused: Bool
    /// 分享：先问是否包含笔记，再弹系统分享面板
    @State private var askShareNote = false
    @State private var shareSheetText: String?

    private var db: GuaDatabase { GuaDatabase.shared }
    private var benGua: Hexagram? { db.hexagram(number: record.benGua) }
    private var bianGua: Hexagram? { record.bianGua.flatMap { db.hexagram(number: $0) } }
    private var cast: Cast? {
        guard record.lineValues.count == 6 else { return nil }
        return Cast(lines: record.lineValues.map { DivinationLine(value: $0) })
    }

    var body: some View {
        Group {
            if let gua = benGua {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerCard
                        HexagramDetailView(
                            hexagram: gua,
                            movingIndexes: cast?.movingLineIndexes ?? [],
                            bianGua: bianGua,
                            lineValues: record.lineValues.isEmpty ? nil : record.lineValues)
                    }
                    .padding()
                    .padding(.bottom, editingField != nil ? 80 : 0)
                }
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle(gua.name)
                .navigationBarTitleDisplayMode(.inline)
                // tabBar 隐藏由外层 RecordsView 的 NavigationStack 按 path 统一控制
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 4) {
                            Text(gua.name).font(.headline)
                            if let bian = bianGua {
                                Image(systemName: "arrow.right")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(bian.name).font(.headline)
                            }
                        }
                        .lineLimit(1)
                    }
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button {
                            UIPasteboard.general.string = shareText(gua: gua)   // 复制不含笔记
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        Button {
                            if record.note.isEmpty { shareSheetText = shareText(gua: gua, includeNote: false) }
                            else { askShareNote = true }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .confirmationDialog("分享", isPresented: $askShareNote, titleVisibility: .visible) {
                            Button("包含笔记") { shareSheetText = shareText(gua: gua, includeNote: true) }
                            Button("不包含笔记") { shareSheetText = shareText(gua: gua, includeNote: false) }
                            Button("取消", role: .cancel) {}
                        }
                    }
                }
                .sheet(isPresented: Binding(get: { shareSheetText != nil },
                                            set: { if !$0 { shareSheetText = nil } })) {
                    if let t = shareSheetText { ActivityView(items: [t]) }
                }
                // Bottom bar: cancel / save for the active editable field
                .safeAreaInset(edge: .bottom) {
                    if editingField != nil {
                        editBar
                    }
                }
                .onAppear {
                    draftTranscript = record.transcript
                    draftNote = record.note
                }
                // 返回列表前收起键盘 / 第一响应者，避免焦点残留到列表页
                .onDisappear {
                    endEditing()
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }

    // MARK: - Header card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(record.date.displayString)
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Picker("起卦方式", selection: $record.method) {
                        Label("铜钱起卦", image: "CoinIcon").tag("铜钱起卦")
                        Label("手机起卦", systemImage: "iphone.gen3.radiowaves.left.and.right").tag("手机起卦")
                    }
                } label: {
                    HStack(spacing: 3) {
                        if record.method == "手机起卦" {
                            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                        } else {
                            Image("CoinIcon").renderingMode(.template)
                                .resizable().frame(width: 11, height: 11)
                        }
                        Text(record.method)
                    }
                    .font(.caption2).foregroundStyle(.secondary)
                }
                .tint(.secondary)
            }

            // Question — editable, auto-saves via @Bindable
            VStack(alignment: .leading, spacing: 4) {
                Text("问题").font(.caption).foregroundStyle(.secondary)
                TextField("点击编辑问题", text: $record.question, axis: .vertical)
                    .font(.body)
            }

            // Transcript（记录）— editable, explicit save/cancel
            VStack(alignment: .leading, spacing: 4) {
                Label("记录", systemImage: "doc.text").font(.caption).foregroundStyle(.secondary)
                TextField("点击编辑记录", text: $draftTranscript, axis: .vertical)
                    .lineLimit(1...6)
                    .font(.body)
                    .focused($transcriptFocused)
                    .onChange(of: transcriptFocused) { _, focused in
                        if focused { editingField = .transcript }
                    }
            }

            // 动爻 — 标题含动爻数 + 断卦提示；爻辞只读但可长按选中/复制
            if record.lineValues.count == 6 {
                VStack(alignment: .leading, spacing: 4) {
                    Label("\(movingCount)动爻：\(movingHint)", systemImage: "arrow.left.arrow.right")
                        .font(.caption).foregroundStyle(.secondary)
                    // 从上往下显示（上爻→初爻），与卦象画法一致
                    ForEach(Array(movingYaoLines.enumerated().reversed()), id: \.offset) { _, line in
                        ReadOnlyTextEditor(text: line, font: .preferredFont(forTextStyle: .footnote), lineSpacing: 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Divider()

            // 笔记（note）— UITextView 编辑：点哪儿光标在哪儿，长文本不再被自动滚到底部
            VStack(alignment: .leading, spacing: 4) {
                Label("笔记", systemImage: "square.and.pencil").font(.caption).foregroundStyle(.secondary)
                ZStack(alignment: .topLeading) {
                    if draftNote.isEmpty {
                        Text("点击添加笔记").font(.body).foregroundStyle(.tertiary)
                    }
                    EditableTextView(text: $draftNote, editing: editingField == .note,
                                     onFocus: { editingField = .note })
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Edit bar (shared by 记录 and 笔记)

    private var editBar: some View {
        HStack(spacing: 12) {
            Button("取消") {
                switch editingField {
                case .transcript: draftTranscript = record.transcript
                case .note:       draftNote = record.note
                case .none:       break
                }
                endEditing()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

            Button("保存") {
                switch editingField {
                case .transcript: record.transcript = draftTranscript
                case .note:       record.note = draftNote
                case .none:       break
                }
                endEditing()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal).padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }

    private func endEditing() {
        editingField = nil
        transcriptFocused = false
        noteFocused = false
    }

    /// 动爻数量（0~6）
    private var movingCount: Int { cast?.movingLineIndexes.count ?? 0 }

    /// 动爻数量对应的断卦提示
    private var movingHint: String {
        switch movingCount {
        case 0: return "看本卦。"
        case 1: return "看本卦动爻。"
        case 2: return "看本卦动爻，上爻主，下爻辅。"
        case 3: return "结合本卦变卦。"
        case 4: return "看变卦不动爻，下爻主，上爻辅。"
        case 5: return "看变卦不动爻。"
        default: return "看变卦。"
        }
    }

    /// 动爻文本行（与导出文本一致，但不含「动爻：」标题）
    private var movingYaoLines: [String] {
        guard let gua = benGua, let c = cast, !c.movingLineIndexes.isEmpty else { return [] }
        let posNames = ["初爻", "二爻", "三爻", "四爻", "五爻", "上爻"]
        var result: [String] = []
        for idx in c.movingLineIndexes {
            guard idx < gua.yaos.count else { continue }
            let benYao = gua.yaos[idx]
            var line = "\(posNames[idx]) \(benYao.title)：\(benYao.content)"
            if let bian = bianGua, idx < bian.yaos.count {
                let bianYao = bian.yaos[idx]
                line += " → \(bianYao.title)：\(bianYao.content)"
            }
            result.append(line)
        }
        return result
    }

    // MARK: - Share text

    private func shareText(gua: Hexagram, includeNote: Bool = false) -> String {
        var lines: [String] = []
        lines.append("时间：\(record.date.displayString)")
        lines.append("方式：\(record.method)")
        if !record.question.isEmpty {
            lines.append("问题：\(record.question)")
        }
        if !record.transcript.isEmpty {
            lines.append("记录：\(record.transcript)")
        }

        // 卦象行
        var guaLine = "卦象：\(gua.name)"
        if let bian = bianGua { guaLine += " → \(bian.name)" }
        lines.append(guaLine)

        // 动爻爻辞（每条独立一行）
        if !movingYaoLines.isEmpty {
            lines.append("动爻：")
            for line in movingYaoLines { lines.append("  \(line)") }
        }

        // 笔记（复制不含；分享按需）
        if includeNote && !record.note.isEmpty {
            lines.append("笔记：\(record.note)")
        }

        return lines.joined(separator: "\n")
    }
}

/// 系统分享面板（UIActivityViewController 封装）
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
