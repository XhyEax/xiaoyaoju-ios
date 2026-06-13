// Views/ClassicsUI.swift — 道德经/庄子 共用 UI 组件
import SwiftUI

// 截取正文开头
func snip(_ s: String, _ n: Int = 24) -> String {
    s.count > n ? String(s.prefix(n)) + "…" : s
}

// 文本卡片（可长按复制）
struct ClassicCard: View {
    let text: String
    var title: String? = nil
    var copy: String
    var font: Font
    var color: Color = .primary
    var lineSpacing: CGFloat = 2
    var onSelect: ((String) -> Void)? = nil

    init(_ text: String, title: String? = nil, copy: String,
         font: Font, color: Color = .primary, lineSpacing: CGFloat = 2,
         onSelect: ((String) -> Void)? = nil) {
        self.text = text; self.title = title; self.copy = copy
        self.font = font; self.color = color; self.lineSpacing = lineSpacing
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title).font(.subheadline).bold().foregroundStyle(.secondary)
            }
            Text(text).font(font).foregroundStyle(color).lineSpacing(lineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            Button {
                UIPasteboard.general.string = copy
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: { Label("复制", systemImage: "doc.on.doc") }
            if let onSelect {
                Button { onSelect(copy) } label: { Label("选中文本", systemImage: "selection.pin.in.out") }
            }
        }
    }
}

// 全屏可选文本：供用户手动选中部分文字
struct SelText: Identifiable { let id = UUID(); let text: String }

struct SelectableTextSheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text).textSelection(.enabled)
                    .font(.body).lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("选中文本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

// 章节右上角：复制 / 分享
struct ChapterShareToolbar: ToolbarContent {
    let text: String
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                UIPasteboard.general.string = text
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: { Image(systemName: "doc.on.doc") }
            ShareLink(item: text) { Image(systemName: "square.and.arrow.up") }
        }
    }
}

// 底部栏：上一章 | 注 译 ★ | 下一章
struct ClassicBottomBar: View {
    let prevEnabled: Bool
    let nextEnabled: Bool
    let hideAnno: Bool
    let hideTrans: Bool
    let isFav: Bool
    let onPrev: () -> Void
    let onNext: () -> Void
    let onAnno: () -> Void
    let onTrans: () -> Void
    let onFav: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onPrev) {
                Text("上一章").frame(maxWidth: .infinity).padding(.vertical, 8)
            }.disabled(!prevEnabled)
            Divider().frame(height: 18)
            HStack(spacing: 12) {
                CircleToggle(label: "注", on: !hideAnno, action: onAnno)
                CircleToggle(label: "译", on: !hideTrans, action: onTrans)
                Button(action: onFav) {
                    Image(systemName: isFav ? "star.fill" : "star")
                        .font(.system(size: 15))
                        .foregroundStyle(isFav ? Color(red: 0.96, green: 0.65, blue: 0.14) : Color.secondary)
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(isFav ? Color(red: 0.96, green: 0.65, blue: 0.14) : Color.secondary.opacity(0.5), lineWidth: 1))
                }
            }
            .padding(.horizontal, 12)
            Divider().frame(height: 18)
            Button(action: onNext) {
                Text("下一章").frame(maxWidth: .infinity).padding(.vertical, 8)
            }.disabled(!nextEnabled)
        }
        .font(.subheadline)
        .padding(.horizontal, 6).padding(.vertical, 6)
        .background(.bar)
        .overlay(Divider(), alignment: .top)
    }
}

// 章节顶部工具栏：上一章/下一章（左）+ 注/译/收藏/复制分享（右）；底部 TabBar 常驻
struct ChapterTopToolbar: ToolbarContent {
    let shareText: String
    let prevEnabled: Bool
    let nextEnabled: Bool
    let hideAnno: Bool
    let hideTrans: Bool
    let isFav: Bool
    let onPrev: () -> Void
    let onNext: () -> Void
    let onAnno: () -> Void
    let onTrans: () -> Void
    let onFav: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) {
            Button(action: onPrev) { Image(systemName: "chevron.up") }.disabled(!prevEnabled)
            Button(action: onNext) { Image(systemName: "chevron.down") }.disabled(!nextEnabled)
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button(action: onAnno) { Text("注").foregroundStyle(hideAnno ? Color.secondary : Color.blue) }
            Button(action: onTrans) { Text("译").foregroundStyle(hideTrans ? Color.secondary : Color.blue) }
            Button(action: onFav) {
                Image(systemName: isFav ? "star.fill" : "star")
                    .foregroundStyle(isFav ? Color(red: 0.96, green: 0.65, blue: 0.14) : Color.secondary)
            }
            Menu {
                Button {
                    UIPasteboard.general.string = shareText
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: { Label("复制", systemImage: "doc.on.doc") }
                ShareLink(item: shareText) { Label("分享", systemImage: "square.and.arrow.up") }
            } label: { Image(systemName: "ellipsis.circle") }
        }
    }
}

// 章节底部栏：作为导航底部工具栏（覆盖 TabBar 位置，不隐藏 TabBar，返回无加载动画）
struct ChapterBottomToolbar: ToolbarContent {
    let prevEnabled: Bool
    let nextEnabled: Bool
    let hideAnno: Bool
    let hideTrans: Bool
    let isFav: Bool
    let onPrev: () -> Void
    let onNext: () -> Void
    let onAnno: () -> Void
    let onTrans: () -> Void
    let onFav: () -> Void

    private func circle(_ label: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 15))
                .foregroundStyle(on ? Color.blue : Color.secondary)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(on ? Color.blue : Color.secondary.opacity(0.5), lineWidth: 1))
        }
    }

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button("上一章", action: onPrev).disabled(!prevEnabled)
            Spacer()
            circle("注", on: !hideAnno, onAnno)
            circle("译", on: !hideTrans, onTrans)
            Button(action: onFav) {
                Image(systemName: isFav ? "star.fill" : "star")
                    .font(.system(size: 15))
                    .foregroundStyle(isFav ? Color(red: 0.96, green: 0.65, blue: 0.14) : Color.secondary)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(isFav ? Color(red: 0.96, green: 0.65, blue: 0.14) : Color.secondary.opacity(0.5), lineWidth: 1))
            }
            Spacer()
            Button("下一章", action: onNext).disabled(!nextEnabled)
        }
    }
}

// 圆形文字切换（注/译），显示态蓝、隐藏态灰
struct CircleToggle: View {
    let label: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(on ? Color.blue : Color.secondary)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(on ? Color.blue : Color.secondary.opacity(0.5), lineWidth: 1))
        }
    }
}
