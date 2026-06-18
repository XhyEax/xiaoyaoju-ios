// Views/NoteEditorView.swift
// 笔记编辑浮层 + 复用小组件（铅笔入口、笔记展示块）
import SwiftUI

// 原文卡片右上角的笔记铅笔（iOS 笔记图标）
struct NotePencil: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

// 原文下方的笔记展示块（点击可再次编辑）
struct NoteDisplay: View {
    let text: String
    var fontScale: Double = 1.0
    let onTap: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            Label("笔记", systemImage: "square.and.pencil")
                .font(.caption).bold().foregroundStyle(.secondary)
            Text(text)
                .font(Font(scaledUIFont(.subheadline, fontScale)))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// 笔记编辑 sheet：写入 NotesStore（空文本即删除）
struct NoteEditorSheet: View {
    let kind: String
    let noteKey: String
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var loaded = false
    private var store: NotesStore { .shared }

    var body: some View {
        NavigationStack {
            AutoFocusTextView(text: $text)
                .padding(8)
            .navigationTitle("笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !store.get(kind, noteKey).isEmpty {
                        Button(role: .destructive) { store.set(kind, noteKey, ""); dismiss() } label: {
                            Image(systemName: "trash").foregroundStyle(.red)
                        }
                    }
                    Button("保存") { store.set(kind, noteKey, text); dismiss() }.bold()
                }
            }
            .onAppear { if !loaded { text = store.get(kind, noteKey); loaded = true } }
        }
        .presentationDetents([.medium, .large])
    }
}

// 自动聚焦的多行输入：挂到窗口那一刻 becomeFirstResponder 弹出键盘（无计时，最可靠）
struct AutoFocusTextView: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> FocusTextView {
        let tv = FocusTextView()
        tv.isEditable = true
        tv.font = .preferredFont(forTextStyle: .body)
        tv.backgroundColor = .clear
        tv.delegate = context.coordinator
        tv.text = text
        return tv
    }

    func updateUIView(_ tv: FocusTextView, context: Context) {
        if tv.text != text { tv.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: AutoFocusTextView
        init(_ p: AutoFocusTextView) { parent = p }
        func textViewDidChange(_ tv: UITextView) { parent.text = tv.text }
    }
}

// 进入窗口即自动聚焦一次
final class FocusTextView: UITextView {
    private var didAutoFocus = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil && !didAutoFocus {
            didAutoFocus = true
            becomeFirstResponder()
        }
    }
}
