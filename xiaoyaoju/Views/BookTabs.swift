// Views/BookTabs.swift — 底部 Tab 动态配置（可选 1-3 本典籍）+ 文字图标 + 设置页
import SwiftUI
import UIKit

// 解析已选 tab 典籍（storage『tabBooks』逗号分隔），过滤非法、限 1-3 本，缺省 道/庄/易
@MainActor
func parseTabBooks(_ raw: String) -> [String] {
    let valid = Set(ClassicsDatabase.shared.bookMetas.map { $0.id })
    var ids = raw.split(separator: ",").map(String.init).filter { valid.contains($0) }
    if ids.isEmpty { ids = ["ddj", "zz", "yj"] }
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

// 典籍 Tab 设置：选 1-3 本，按勾选顺序保存到『tabBooks』
struct BookSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("tabBooks") private var tabBooksRaw = "ddj,zz,yj"
    @State private var sel: [String] = []
    private var db: ClassicsDatabase { .shared }

    var body: some View {
        NavigationStack {
            List {
                Section(footer: Text("选择底部显示的典籍 Tab（最少 1 本，最多 3 本），按勾选先后顺序排列。")) {
                    ForEach(db.bookMetas) { b in
                        HStack(spacing: 14) {
                            Button { toggle(b.id) } label: {
                                HStack(spacing: 14) {
                                    Text(b.icon).font(.title3).bold()
                                        .foregroundStyle(sel.contains(b.id) ? .blue : .secondary)
                                        .frame(width: 30)
                                    Text(b.name).foregroundStyle(.primary)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                bookPreview(b)
                            } label: {
                                Image("IconEye").renderingMode(.template).foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 28)

                            if let i = sel.firstIndex(of: b.id) {
                                Text("\(i + 1)").font(.caption2).foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(.blue))
                            }
                            Image(systemName: sel.contains(b.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(sel.contains(b.id) ? .blue : .secondary)
                        }
                    }
                }
            }
            .navigationTitle("典籍设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(sel.isEmpty)
                }
            }
            .onAppear { sel = parseTabBooks(tabBooksRaw) }
        }
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
        guard !sel.isEmpty else { return }
        tabBooksRaw = sel.joined(separator: ",")
        dismiss()
    }
}
