// Views/RecordsView.swift
// Tab 3: 历史卦记录

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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

/// 导出文件名（不含扩展名，.json 由 contentType 追加）："六爻记录_20260606_0039"
func exportFileName() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyyMMdd_HHmm"
    f.locale = Locale(identifier: "zh_CN")
    return "六爻记录_" + f.string(from: Date())
}

// MARK: - List view

struct RecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CastRecord.date, order: .reverse) private var records: [CastRecord]
    @State private var searchText = ""
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<PersistentIdentifier>()
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var exportDocument: RecordsJSONDocument?
    @State private var transferAlert: String?
    @State private var seg = 0   // 0=收藏 1=历史

    private var db: GuaDatabase { GuaDatabase.shared }

    /// 按问题 / 记录 / 笔记 / 本卦名 / 变卦名过滤
    private var filteredRecords: [CastRecord] {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return records }
        return records.filter { r in
            let benName = db.hexagram(number: r.benGua)?.name ?? ""
            let bianName = r.bianGua.flatMap { db.hexagram(number: $0)?.name } ?? ""
            return r.question.localizedCaseInsensitiveContains(q) ||
                   r.transcript.localizedCaseInsensitiveContains(q) ||
                   r.note.localizedCaseInsensitiveContains(q) ||
                   benName.localizedCaseInsensitiveContains(q) ||
                   bianName.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $seg) {
                    Text("收藏").tag(0)
                    Text("历史").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)

                if seg == 0 {
                    FavoritesView()
                } else {
                    recordsContent
                        .searchable(text: $searchText, prompt: "搜索问题、记录或卦名")
                }
            }
            .navigationTitle(seg == 0 ? "收藏" : (editMode.isEditing ? "已选 \(selection.count) 条" : "历史记录"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { if seg == 1 { toolbarContent } }
            .toolbar { if seg == 1 && editMode.isEditing { bottomBarContent } }
            .fileExporter(isPresented: $showExporter,
                          document: exportDocument,
                          contentType: .json,
                          defaultFilename: exportFileName()) { result in
                if case .failure(let err) = result {
                    transferAlert = "导出失败：\(err.localizedDescription)"
                } else {
                    transferAlert = "导出成功"
                }
            }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .alert(transferAlert ?? "", isPresented: Binding(
                get: { transferAlert != nil },
                set: { if !$0 { transferAlert = nil } }
            )) {
                Button("好的", role: .cancel) {}
            }
        }
    }

    // 历史记录内容（列表 / 空态）
    @ViewBuilder
    private var recordsContent: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView("暂无记录",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("在「易经 → 手动点选六爻」完成并保存后，卦例将出现在这里"))
            } else if filteredRecords.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(selection: $selection) {
                    ForEach(filteredRecords) { record in
                        NavigationLink {
                            RecordDetailView(record: record)
                        } label: {
                            recordRow(record)
                        }
                    }
                    .onDelete(perform: editMode.isEditing ? nil : deleteRecords)
                }
                .environment(\.editMode, $editMode)
            }
        }
    }

    // MARK: - Toolbars

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if editMode.isEditing {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(allSelected ? "全不选" : "全选") {
                    if allSelected { selection.removeAll() }
                    else { selection = Set(filteredRecords.map(\.id)) }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") { exitSelection() }
            }
        } else {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button { exportRecords() } label: {
                        Label("导出全部", systemImage: "square.and.arrow.up")
                    }
                    .disabled(records.isEmpty)
                    Button { showImporter = true } label: {
                        Label("导入", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                if !records.isEmpty {
                    Button("选择") {
                        withAnimation { editMode = .active }
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var bottomBarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button(role: .destructive) { deleteSelected() } label: {
                Label("删除\(selection.isEmpty ? "" : " \(selection.count)")", systemImage: "trash")
            }
            .disabled(selection.isEmpty)
            Spacer()
            Button { exportSelected() } label: {
                Label("导出\(selection.isEmpty ? "" : " \(selection.count)")", systemImage: "square.and.arrow.up")
            }
            .disabled(selection.isEmpty)
        }
    }

    private var allSelected: Bool {
        !filteredRecords.isEmpty && selection.count == filteredRecords.count
    }

    private func exitSelection() {
        withAnimation { editMode = .inactive }
        selection.removeAll()
    }

    private func deleteSelected() {
        for record in records where selection.contains(record.id) {
            modelContext.delete(record)
        }
        exitSelection()
    }

    private func exportSelected() {
        let chosen = records.filter { selection.contains($0.id) }
        guard !chosen.isEmpty,
              let data = try? RecordTransfer.encoder().encode(chosen.map(\.dto)) else {
            transferAlert = "导出失败"
            return
        }
        exportDocument = RecordsJSONDocument(data: data)
        showExporter = true
    }

    private func recordRow(_ r: CastRecord) -> some View {
        HStack(spacing: 12) {
            if let gua = db.hexagram(number: r.benGua) {
                Text(gua.symbol).font(.system(size: 28)).frame(width: 36)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(gua.name).font(.body)
                        if let bNum = r.bianGua, let bian = db.hexagram(number: bNum) {
                            Text("→").foregroundStyle(.secondary).font(.caption)
                            Text(bian.name).font(.body).foregroundStyle(.blue)
                        }
                    }
                    if !r.question.isEmpty {
                        Text(r.question).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Text(r.date.displayString)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func deleteRecords(at offsets: IndexSet) {
        for idx in offsets { modelContext.delete(filteredRecords[idx]) }
    }

    // MARK: - Import / Export

    private func exportRecords() {
        let dtos = records.map(\.dto)
        guard let data = try? RecordTransfer.encoder().encode(dtos) else {
            transferAlert = "导出失败"
            return
        }
        exportDocument = RecordsJSONDocument(data: data)
        showExporter = true
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let err):
            transferAlert = "导入失败：\(err.localizedDescription)"
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let dtos = try RecordTransfer.decoder().decode([RecordDTO].self, from: data)
                // 以时间为 id，append（跳过已存在的相同时间记录）
                let existing = Set(records.map(\.date))
                var added = 0, skipped = 0
                for dto in dtos {
                    if existing.contains(dto.date) { skipped += 1; continue }
                    modelContext.insert(CastRecord(dto: dto))
                    added += 1
                }
                transferAlert = "导入完成：新增 \(added) 条" + (skipped > 0 ? "，跳过重复 \(skipped) 条" : "")
            } catch {
                transferAlert = "导入失败：文件格式不正确"
            }
        }
    }
}

// MARK: - Detail view

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
                .toolbar(.hidden, for: .tabBar)
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
                            UIPasteboard.general.string = shareText(gua: gua)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        ShareLink(item: shareText(gua: gua)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
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
                    .lineLimit(1...4)
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

            // 动爻 — read-only, same content as exported text
            if !movingYaoLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("动爻", systemImage: "arrow.left.arrow.right").font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(movingYaoLines.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.footnote)
                    }
                }
            }

            Divider()

            // 笔记（note）— editable, explicit save/cancel
            VStack(alignment: .leading, spacing: 4) {
                Label("笔记", systemImage: "square.and.pencil").font(.caption).foregroundStyle(.secondary)
                TextField("点击添加笔记", text: $draftNote, axis: .vertical)
                    .lineLimit(nil)
                    .font(.body)
                    .focused($noteFocused)
                    .onChange(of: noteFocused) { _, focused in
                        if focused { editingField = .note }
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

    private func shareText(gua: Hexagram) -> String {
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

        // 笔记
        if !record.note.isEmpty {
            lines.append("笔记：\(record.note)")
        }

        return lines.joined(separator: "\n")
    }
}

#Preview {
    RecordsView()
        .modelContainer(for: CastRecord.self, inMemory: true)
}
