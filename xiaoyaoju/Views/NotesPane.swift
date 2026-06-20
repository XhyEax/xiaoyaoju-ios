// Views/NotesPane.swift — 「笔记」分段：列表/搜索/多选/导入导出（自含状态）
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct NotesPane: View {
    @State private var searchText = ""
    @State private var editMode: EditMode = .inactive
    @State private var noteSelection = Set<String>()
    @State private var transferAlert: String?
    @State private var showImporter = false
    @State private var exportState = ExportState()

    var body: some View {
        VStack(spacing: 0) {
            if !buildNoteList().isEmpty { InlineSearchBar(text: $searchText, prompt: "搜索笔记") }
            notesContent
        }
        .navigationTitle(editMode.isEditing ? "已选 \(noteSelection.count) 条" : "笔记")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .toolbar { if editMode.isEditing { bottomBar } }
        .exportFlow(exportState)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { handleImport($0) }
        .alert(transferAlert ?? "", isPresented: Binding(
            get: { transferAlert != nil }, set: { if !$0 { transferAlert = nil } }
        )) { Button("好的", role: .cancel) {} }
    }

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
                // 非编辑态绑常量空集：点行只导航、不残留选中高亮
                List(selection: editMode.isEditing ? $noteSelection : .constant(Set<String>())) {
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
    private var toolbarContent: some ToolbarContent {
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
                    Button { showImporter = true } label: { Label("导入", systemImage: "square.and.arrow.down") }
                    Button { importNotesFromClipboard() } label: { Label("从剪贴板导入", systemImage: "doc.on.clipboard") }
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
    private var bottomBar: some ToolbarContent {
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

    // MARK: - 导入导出

    private func exportSelectedNotes() { exportNotes(buildNoteList().filter { noteSelection.contains($0.id) }) }
    private func exportAllNotes() { exportNotes(buildNoteList()) }

    private func exportNotes(_ items: [NoteItem]) {
        let dtos = items.map { NoteDTO(book: $0.kind, key: $0.anchor, text: $0.text, title: $0.title) }
        guard !dtos.isEmpty else { return }
        exportState.begin(filename: RecordTransfer.notesFileName()) { RecordTransfer.encode(dtos) }
    }

    private func copyNotesToClipboard() {
        let dtos = buildNoteList().map { NoteDTO(book: $0.kind, key: $0.anchor, text: $0.text, title: $0.title) }
        guard let data = RecordTransfer.encode(dtos), let s = String(data: data, encoding: .utf8) else {
            transferAlert = "复制失败"; return
        }
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
            importNotes(data)
        }
    }

    private func importNotesFromClipboard() {
        guard let s = UIPasteboard.general.string, let data = s.data(using: .utf8) else {
            transferAlert = "剪贴板无内容"; return
        }
        importNotes(data)
    }

    private func importNotes(_ data: Data) {
        guard let dtos = RecordTransfer.decodeNotes(data) else { transferAlert = "导入失败：格式不正确"; return }
        let (valid, skipped) = RecordTransfer.validNotes(dtos)
        for d in valid { NotesStore.shared.set(d.book, d.key, d.text) }
        transferAlert = "导入完成：新增 \(valid.count) 条" + (skipped > 0 ? "，跳过无效 \(skipped) 条" : "")
    }
}
