// Views/RecordsListPane.swift — 「历史」分段：列表/搜索/多选/导入导出（自含状态）
import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct RecordsListPane: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CastRecord.date, order: .reverse) private var records: [CastRecord]

    @State private var searchText = ""
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<PersistentIdentifier>()
    @State private var transferAlert: String?
    @State private var showImporter = false
    @State private var exportState = ExportState()
    @State private var importConflicts: [RecordDTO] = []   // date 重复、待用户决定覆盖/跳过
    @State private var importedAdded = 0
    @State private var showOverwriteAlert = false

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
        VStack(spacing: 0) {
            if !records.isEmpty { InlineSearchBar(text: $searchText, prompt: "搜索问题、记录或卦名") }
            recordsContent
        }
        .navigationTitle(editMode.isEditing ? "已选 \(selection.count) 条" : "历史记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .toolbar { if editMode.isEditing { bottomBarContent } }
        .exportFlow(exportState)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { handleImport($0) }
        .alert(transferAlert ?? "", isPresented: Binding(
            get: { transferAlert != nil }, set: { if !$0 { transferAlert = nil } }
        )) { Button("好的", role: .cancel) {} }
        .alert("有 \(importConflicts.count) 条记录已存在", isPresented: $showOverwriteAlert) {
            Button("覆盖") { resolveImportConflicts(overwrite: true) }
            Button("跳过") { resolveImportConflicts(overwrite: false) }
            Button("取消", role: .cancel) { importConflicts = [] }
        } message: {
            Text("已新增 \(importedAdded) 条；时间重复的记录要覆盖还是跳过？")
        }
    }

    // 历史记录内容（列表 / 空态）
    @ViewBuilder
    private var recordsContent: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView("暂无记录",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("在「六爻」保存，卦例将出现在这里"))
            } else if filteredRecords.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                // 非编辑态绑常量空集：点行只导航、不残留选中高亮（返回后无残留）
                List(selection: editMode.isEditing ? $selection : .constant(Set<PersistentIdentifier>())) {
                    ForEach(filteredRecords) { record in
                        NavigationLink(value: record) { recordRow(record) }
                    }
                    .onDelete(perform: editMode.isEditing ? nil : deleteRecords)
                }
                .environment(\.editMode, $editMode)
                .contentMargins(.top, 4, for: .scrollContent)
            }
        }
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
                    Button { importRecordsFromClipboard() } label: {
                        Label("从剪贴板导入", systemImage: "doc.on.clipboard")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                if !records.isEmpty {
                    Button("选择") { withAnimation { editMode = .active } }
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
        for record in records where selection.contains(record.id) { modelContext.delete(record) }
        exitSelection()
    }
    private func deleteRecords(at offsets: IndexSet) {
        for idx in offsets { modelContext.delete(filteredRecords[idx]) }
    }

    // MARK: - 导入导出

    private func exportRecords() {
        let dtos = records.map(\.dto)   // 主线程取好值类型，再后台编码
        exportState.begin(filename: RecordTransfer.recordsFileName() + ".json") { RecordTransfer.encode(dtos) }
    }
    private func exportSelected() {
        let dtos = records.filter { selection.contains($0.id) }.map(\.dto)
        guard !dtos.isEmpty else { return }
        exportState.begin(filename: RecordTransfer.recordsFileName() + ".json") { RecordTransfer.encode(dtos) }
    }
    private func copyRecordsToClipboard() {
        guard let data = RecordTransfer.encode(records.map(\.dto)),
              let s = String(data: data, encoding: .utf8) else { transferAlert = "复制失败"; return }
        UIPasteboard.general.string = s
        transferAlert = "已复制到剪贴板"
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let err):
            transferAlert = "导入失败：\(err.localizedDescription)"
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { transferAlert = "导入失败：无法读取文件"; return }
            importRecords(data)
        }
    }
    private func importRecordsFromClipboard() {
        guard let s = UIPasteboard.general.string, let data = s.data(using: .utf8) else {
            transferAlert = "剪贴板无内容"; return
        }
        importRecords(data)
    }
    private func importRecords(_ data: Data) {
        guard let dtos = RecordTransfer.decodeRecords(data) else { transferAlert = "导入失败：格式不正确"; return }
        // 以时间为 id：不重复的直接新增；重复的暂存，弹窗让用户选覆盖/跳过
        let (newOnes, conflicts) = RecordTransfer.planRecordImport(
            incoming: dtos, existingDates: Set(records.map(\.date)))
        for dto in newOnes { modelContext.insert(CastRecord(dto: dto)) }
        importedAdded = newOnes.count
        if conflicts.isEmpty {
            transferAlert = "导入完成：新增 \(newOnes.count) 条"
        } else {
            importConflicts = conflicts
            showOverwriteAlert = true
        }
    }
    private func resolveImportConflicts(overwrite: Bool) {
        let n = importConflicts.count
        if overwrite {
            for dto in importConflicts {
                if let old = records.first(where: { $0.date == dto.date }) { modelContext.delete(old) }
                modelContext.insert(CastRecord(dto: dto))
            }
            transferAlert = "导入完成：新增 \(importedAdded) 条，覆盖 \(n) 条"
        } else {
            transferAlert = "导入完成：新增 \(importedAdded) 条，跳过 \(n) 条"
        }
        importConflicts = []
    }
}
