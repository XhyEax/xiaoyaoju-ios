// Views/RecordsView.swift
// Tab 3: 历史卦记录

import SwiftUI
import SwiftData
import UIKit
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
    @State private var seg = 0   // 0=收藏 1=笔记 2=历史
    @State private var path = NavigationPath()
    // 笔记分段：复用历史的 editMode，单独的选择集与导入导出
    @State private var noteSelection = Set<String>()
    @State private var showNoteImporter = false
    @State private var showNoteExporter = false
    @State private var noteExportDocument: RecordsJSONDocument?

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
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("", selection: $seg) {
                    Text("收藏").tag(0)
                    Text("笔记").tag(1)
                    Text("历史").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)

                // 搜索框固定置于分段控件下方（三段复用同一布局）
                if seg == 0 {
                    if hasFavorites { InlineSearchBar(text: $searchText, prompt: "搜索收藏") }
                    FavoritesView(search: searchText)
                } else if seg == 1 {
                    if !buildNoteList().isEmpty { InlineSearchBar(text: $searchText, prompt: "搜索笔记") }
                    notesContent
                } else {
                    if !records.isEmpty { InlineSearchBar(text: $searchText, prompt: "搜索问题、记录或卦名") }
                    recordsContent
                }
            }
            // 切换分段：清空多选 / 搜索，避免相互影响
            .onChange(of: seg) { _, _ in
                withAnimation { editMode = .inactive }
                selection.removeAll(); noteSelection.removeAll(); searchText = ""
            }
            // 从详情返回根列表（非编辑态）：清空选择，避免行高亮残留
            .onChange(of: path.count) { _, n in
                if n == 0 && !editMode.isEditing { selection.removeAll(); noteSelection.removeAll() }
            }
            // 收藏页可跳转：历史记录详情 / 易经卦象 / 典籍章节，全部 value-based 以便 path 追踪
            .navigationDestination(for: CastRecord.self) { RecordDetailView(record: $0) }
            .navigationDestination(for: GuaRoute.self) { route in
                if let g = db.hexagram(number: route.number) {
                    HexagramDetailView(hexagram: g, showShareActions: true, initialAnchor: route.anchor)
                }
            }
            .navigationDestination(for: ChapterRoute.self) { route in
                BookChapterView(bookId: route.bookId, index: route.index, highlight: route.highlight, anchor: route.anchor)
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { if seg == 1 { noteToolbarContent } else if seg == 2 { toolbarContent } }
            .toolbar {
                if editMode.isEditing {
                    if seg == 1 { noteBottomBar } else if seg == 2 { bottomBarContent }
                }
            }
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
            .fileExporter(isPresented: $showNoteExporter,
                          document: noteExportDocument,
                          contentType: .json,
                          defaultFilename: noteExportFileName()) { result in
                if case .failure(let err) = result {
                    transferAlert = "导出失败：\(err.localizedDescription)"
                } else {
                    transferAlert = "导出成功"
                }
            }
            .fileImporter(isPresented: $showNoteImporter,
                          allowedContentTypes: [.json]) { result in
                handleNoteImport(result)
            }
            .alert(transferAlert ?? "", isPresented: Binding(
                get: { transferAlert != nil },
                set: { if !$0 { transferAlert = nil } }
            )) {
                Button("好的", role: .cancel) {}
            }
        }
        // tabBar 可见性随导航深度同步切换，避免 pop 时 tabBar 延迟出现的闪烁
        .toolbar(path.isEmpty ? .visible : .hidden, for: .tabBar)
    }

    // 当前收藏是否非空（决定收藏页是否显示搜索框）
    private var hasFavorites: Bool {
        let f = FavoritesStore.shared
        return ClassicsDatabase.shared.bookMetas.contains { !f.ids($0.id).isEmpty }
    }

    // 历史记录内容（列表 / 空态）
    @ViewBuilder
    private var recordsContent: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView("暂无记录",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("在「易经 → 点选六爻」完成并保存后，卦例将出现在这里"))
            } else if filteredRecords.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(selection: $selection) {
                    ForEach(filteredRecords) { record in
                        NavigationLink(value: record) {
                            recordRow(record)
                        }
                    }
                    .onDelete(perform: editMode.isEditing ? nil : deleteRecords)
                }
                .environment(\.editMode, $editMode)
                .contentMargins(.top, 4, for: .scrollContent)
            }
        }
    }

    private var navTitle: String {
        switch seg {
        case 0: return "收藏"
        case 1: return editMode.isEditing ? "已选 \(noteSelection.count) 条" : "笔记"
        default: return editMode.isEditing ? "已选 \(selection.count) 条" : "历史记录"
        }
    }

    // MARK: - 笔记分段

    @ViewBuilder
    private var notesContent: some View {
        let all = buildNoteList()
        let q = searchText.trimmingCharacters(in: .whitespaces)
        let items = q.isEmpty ? all : all.filter {
            $0.title.localizedCaseInsensitiveContains(q) || $0.text.localizedCaseInsensitiveContains(q)
        }
        Group {
            if all.isEmpty {
                ContentUnavailableView("暂无笔记",
                    systemImage: "square.and.pencil",
                    description: Text("在原文卡片右上角点铅笔添加笔记"))
            } else if items.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(selection: $noteSelection) {
                    ForEach(items) { it in noteLink(it) }
                        .onDelete(perform: editMode.isEditing ? nil : { offsets in deleteNotes(items, offsets) })
                }
                .environment(\.editMode, $editMode)
                .contentMargins(.top, 4, for: .scrollContent)
            }
        }
    }

    @ViewBuilder
    private func noteLink(_ it: NoteItem) -> some View {
        if it.kind == "yj" {
            NavigationLink(value: GuaRoute(number: it.refId, anchor: it.anchor)) { noteRow(it) }
        } else {
            NavigationLink(value: ChapterRoute(bookId: it.kind, index: it.refId, highlight: "", anchor: it.anchor)) { noteRow(it) }
        }
    }

    private func noteRow(_ it: NoteItem) -> some View {
        HStack(spacing: 12) {
            Text(it.tag).font(.system(size: 15)).foregroundStyle(.blue).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(it.title).lineLimit(1).truncationMode(.tail)
                Text(it.sub).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
            }
        }
        .padding(.vertical, 2)
    }

    @ToolbarContentBuilder
    private var noteToolbarContent: some ToolbarContent {
        if editMode.isEditing {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(allNotesSelected ? "全不选" : "全选") {
                    if allNotesSelected { noteSelection.removeAll() }
                    else { noteSelection = Set(buildNoteList().map(\.id)) }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") { exitNoteSelection() }
            }
        } else {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button { exportAllNotes() } label: { Label("导出全部", systemImage: "square.and.arrow.up") }
                    Button { copyNotesToClipboard() } label: { Label("复制到剪贴板", systemImage: "doc.on.doc") }
                    Button { showNoteImporter = true } label: { Label("导入", systemImage: "square.and.arrow.down") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                if !buildNoteList().isEmpty {
                    Button("选择") { withAnimation { editMode = .active } }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var noteBottomBar: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button(role: .destructive) { deleteSelectedNotes() } label: {
                Label("删除\(noteSelection.isEmpty ? "" : " \(noteSelection.count)")", systemImage: "trash")
            }
            .disabled(noteSelection.isEmpty)
            Spacer()
            Button { exportSelectedNotes() } label: {
                Label("导出\(noteSelection.isEmpty ? "" : " \(noteSelection.count)")", systemImage: "square.and.arrow.up")
            }
            .disabled(noteSelection.isEmpty)
        }
    }

    private var allNotesSelected: Bool {
        let items = buildNoteList()
        return !items.isEmpty && noteSelection.count == items.count
    }
    private func exitNoteSelection() {
        withAnimation { editMode = .inactive }
        noteSelection.removeAll()
    }
    private func deleteNotes(_ items: [NoteItem], _ offsets: IndexSet) {
        for i in offsets { let it = items[i]; NotesStore.shared.set(it.kind, it.anchor, "") }
    }
    private func deleteSelectedNotes() {
        for it in buildNoteList() where noteSelection.contains(it.id) {
            NotesStore.shared.set(it.kind, it.anchor, "")
        }
        exitNoteSelection()
    }
    private func exportSelectedNotes() { exportNotes(buildNoteList().filter { noteSelection.contains($0.id) }) }
    private func exportAllNotes() { exportNotes(buildNoteList()) }
    private func copyNotesToClipboard() {
        let dtos = buildNoteList().map { NoteDTO(book: $0.kind, key: $0.anchor, text: $0.text, title: $0.title) }
        guard let data = try? RecordTransfer.encoder().encode(dtos),
              let s = String(data: data, encoding: .utf8) else { transferAlert = "复制失败"; return }
        UIPasteboard.general.string = s
        transferAlert = "已复制到剪贴板"
    }
    private func copyRecordsToClipboard() {
        let dtos = records.map(\.dto)
        guard let data = try? RecordTransfer.encoder().encode(dtos),
              let s = String(data: data, encoding: .utf8) else { transferAlert = "复制失败"; return }
        UIPasteboard.general.string = s
        transferAlert = "已复制到剪贴板"
    }
    private func exportNotes(_ items: [NoteItem]) {
        let dtos = items.map { NoteDTO(book: $0.kind, key: $0.anchor, text: $0.text, title: $0.title) }
        guard !dtos.isEmpty, let data = try? RecordTransfer.encoder().encode(dtos) else {
            transferAlert = "导出失败"; return
        }
        noteExportDocument = RecordsJSONDocument(data: data)
        showNoteExporter = true
    }
    private func noteExportFileName() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd_HHmm"
        return "经典笔记_\(f.string(from: Date())).json"
    }
    private func handleNoteImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let err):
            transferAlert = "导入失败：\(err.localizedDescription)"
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let dtos = try RecordTransfer.decoder().decode([NoteDTO].self, from: data)
                var added = 0, skipped = 0
                for d in dtos {
                    if d.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { skipped += 1; continue }
                    NotesStore.shared.set(d.book, d.key, d.text); added += 1
                }
                transferAlert = "导入完成：新增 \(added) 条" + (skipped > 0 ? "，跳过无效 \(skipped) 条" : "")
            } catch {
                transferAlert = "导入失败：文件格式不正确"
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
                    Button { copyRecordsToClipboard() } label: {
                        Label("复制到剪贴板", systemImage: "doc.on.doc")
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

#Preview {
    RecordsView()
        .modelContainer(for: CastRecord.self, inMemory: true)
}

/// 系统分享面板（UIActivityViewController 封装）
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
