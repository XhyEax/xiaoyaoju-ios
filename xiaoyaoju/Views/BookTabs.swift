// Views/BookTabs.swift — 底部 Tab 动态配置（可选 1-3 本典籍）+ 文字图标 + 设置页
import SwiftUI
import UIKit
import SwiftData
import UniformTypeIdentifiers

// 解析已选 tab 典籍（storage『tabBooks』逗号分隔），过滤非法、最多 3 本。
// 缺省由 AppStorage 默认值 "yj" 提供；显式保存空串 "" 表示不显示任何典籍 tab。
@MainActor
func parseTabBooks(_ raw: String) -> [String] {
    let valid = Set(ClassicsDatabase.shared.bookMetas.map { $0.id })
    let ids = raw.split(separator: ",").map(String.init).filter { valid.contains($0) }
    return Array(ids.prefix(3))
}

// 把文字（道/庄/易/列…）渲染成 tab 图标（模板色，随选中态变蓝/灰）
func glyphTabImage(_ s: String) -> UIImage {
    let size = CGSize(width: 28, height: 28)
    let img = UIGraphicsImageRenderer(size: size).image { _ in
        let p = NSMutableParagraphStyle(); p.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: UIColor.label,
            .paragraphStyle: p,
        ]
        let str = NSAttributedString(string: s, attributes: attrs)
        let h = str.size().height
        str.draw(in: CGRect(x: 0, y: (size.height - h) / 2, width: size.width, height: h))
    }
    return img.withRenderingMode(.alwaysTemplate)
}

// 把 SF Symbol 渲染成固定高度的 tab 图标（与「收藏」等自定义 tab 图标 27pt 高度一致）
func symbolTabImage(_ name: String, height: CGFloat = 27) -> UIImage {
    let cfg = UIImage.SymbolConfiguration(pointSize: height, weight: .regular)
    let base = UIImage(systemName: name, withConfiguration: cfg) ?? UIImage()
    guard base.size.height > 0 else { return base.withRenderingMode(.alwaysTemplate) }
    let target = CGSize(width: base.size.width * height / base.size.height, height: height)
    let img = UIGraphicsImageRenderer(size: target).image { _ in
        base.draw(in: CGRect(origin: .zero, size: target))
    }
    return img.withRenderingMode(.alwaysTemplate)
}

// 典籍 Tab 设置：选 1-3 本，按勾选顺序保存到『tabBooks』
struct BookSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("tabBooks") private var tabBooksRaw = ""
    @AppStorage("readerFontScale") private var fontScale: Double = 1.0
    @AppStorage("showCastingTab") private var showCastingTab = false
    @AppStorage("autoRefresh") private var autoRefresh = true
    @State private var sel: [String] = []
    @State private var toast: String?
    @State private var refreshing = false
    // 全部数据 导入导出
    @State private var showImporter = false
    @State private var exportState = ExportState()
    @State private var importResult: String?
    private var db: ClassicsDatabase { .shared }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("典籍设置（最多 3 本，可不选）")
                       ) {
                    ForEach(db.bookMetas) { b in
                        HStack(spacing: 14) {
                            NavigationLink {
                                bookPreview(b)
                            } label: {
                                Image("IconEye").renderingMode(.template).foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 26)

                            Button { toggle(b.id) } label: {
                                HStack(spacing: 14) {
                                    Text(b.icon).font(.title3).bold()
                                        .foregroundStyle(sel.contains(b.id) ? .blue : .secondary)
                                        .frame(width: 30)
                                    Text(b.name).foregroundStyle(.primary)
                                    Spacer()
                                    if let i = sel.firstIndex(of: b.id) {
                                        Text("\(i + 1)").font(.caption2).foregroundStyle(.white)
                                            .frame(width: 22, height: 22)
                                            .background(Circle().fill(.blue))
                                    }
                                    Image(systemName: sel.contains(b.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(sel.contains(b.id) ? .blue : .secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section() {
                    Toggle("显示「爻一爻」", isOn: $showCastingTab)
                }
                Section(header: Text("正文字体大小")) {
                    Picker("字体大小", selection: $fontScale) {
                        Text("小").tag(0.85)
                        Text("中").tag(0.92)
                        Text("标准").tag(1.0)
                        Text("大").tag(1.18)
                        Text("特大").tag(1.35)
                    }
                    .pickerStyle(.segmented)
                }
                Section(header: Text("数据"),
                        footer: Text("导出 / 导入全部收藏、笔记、历史。")) {
                    Button { exportAll() } label: { Label("导出全部数据", systemImage: "square.and.arrow.up") }
                    Button { showImporter = true } label: { Label("导入全部数据", systemImage: "square.and.arrow.down") }
                }
            }
            .exportFlow(exportState)
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { handleImport($0) }
            .alert("导入数据", isPresented: Binding(
                get: { importResult != nil }, set: { if !$0 { importResult = nil } }
            )) { Button("好的", role: .cancel) {} } message: { Text(importResult ?? "") }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { Task { await doRefresh() } } label: {
                        Image("IconReset").renderingMode(.template)
                    }.disabled(refreshing)
                    Button("保存") { save() }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast).font(.subheadline).foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(.black.opacity(0.8), in: Capsule())
                        .padding(.bottom, 60)
                }
            }
            .onAppear { sel = parseTabBooks(tabBooksRaw) }
        }
    }

    // 刷新：重新拉取 config.json，3 秒 toast 提示已更新/未更新
    private func doRefresh() async {
        if refreshing { return }
        autoRefresh = true   // 之后启动也会自动 fetch
        refreshing = true
        let changed = await db.fetchConfig()
        refreshing = false
        let ids = Set(db.bookMetas.map { $0.id })
        sel = sel.filter { ids.contains($0) }
        showToast(changed ? "典籍列表已更新" : "未更新")
    }

    private func showToast(_ m: String) {
        toast = m
        Task { try? await Task.sleep(nanoseconds: 3_000_000_000); if toast == m { toast = nil } }
    }

    // 预览（不改配置）：易经 → 64 卦工具，其它 → 书目
    @ViewBuilder
    private func bookPreview(_ b: BookMeta) -> some View {
        if b.isYijing { LookupView() } else { BookListView(bookId: b.id) }
    }

    private func toggle(_ id: String) {
        if let i = sel.firstIndex(of: id) {
            sel.remove(at: i)                 // 选择时允许暂时为空，保存时才校验至少 1 本
        } else if sel.count < 3 {
            sel.append(id)
        }
    }

    private func save() {
        tabBooksRaw = sel.joined(separator: ",")   // 允许为空（不显示任何典籍 tab）
        dismiss()
    }

    // MARK: - 全部数据 导入导出（收藏 + 笔记 + 历史）

    private func exportAll() {
        // 主线程取好所有值类型数据，再后台编码 + 写临时文件（转圈）→ 写完弹保存框
        let ctx = SharedStore.shared.mainContext
        let records = (try? ctx.fetch(FetchDescriptor<CastRecord>()))?.map(\.dto) ?? []
        let notes = buildNoteList().map { NoteDTO(book: $0.kind, key: $0.anchor, text: $0.text, title: $0.title) }
        let backup = BackupData(favorites: FavoritesStore.shared.allFavorites(), notes: notes, records: records)
        exportState.begin(filename: RecordTransfer.backupFileName()) { RecordTransfer.encode(backup) }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let err): importResult = "导入失败：\(err.localizedDescription)"
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { importResult = "导入失败：无法读取文件"; return }
            importAll(data)
        }
    }

    private func importAll(_ data: Data) {
        guard let b = try? RecordTransfer.decoder().decode(BackupData.self, from: data) else {
            importResult = "导入失败：文件格式不正确"; return
        }
        let favAdded = FavoritesStore.shared.importFavorites(b.favorites)
        let (validNotes, _) = RecordTransfer.validNotes(b.notes)
        for d in validNotes { NotesStore.shared.set(d.book, d.key, d.text) }
        let ctx = SharedStore.shared.mainContext
        let existing = Set((try? ctx.fetch(FetchDescriptor<CastRecord>()))?.map(\.date) ?? [])
        let (newRecs, conflicts) = RecordTransfer.planRecordImport(incoming: b.records, existingDates: existing)
        for dto in newRecs { ctx.insert(CastRecord(dto: dto)) }
        try? ctx.save()
        importResult = """
        导入完成：
        收藏新增 \(favAdded) 条
        笔记写入 \(validNotes.count) 条
        历史新增 \(newRecs.count) 条\(conflicts.isEmpty ? "" : "（重复跳过 \(conflicts.count) 条）")
        """
    }
}
