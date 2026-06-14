// Components/EditableTextView.swift
// 可编辑、随内容增高的多行输入框（UITextView 封装）。
// 解决 SwiftUI TextField(axis:.vertical) 在 ScrollView 中聚焦时把长文本自动滚到底部的问题：
// UITextView 点哪儿光标就在哪儿，不触发 SwiftUI 的聚焦自动滚动。
import SwiftUI
import UIKit

struct EditableTextView: UIViewRepresentable {
    @Binding var text: String
    /// 是否处于编辑态（由外部 editingField 驱动）；变为 false 时收起键盘
    var editing: Bool
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var onFocus: () -> Void = {}

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = true
        tv.isScrollEnabled = false               // 随内容增高，嵌在外层 ScrollView 中
        tv.backgroundColor = .clear
        tv.font = font
        tv.textColor = .label
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.delegate = context.coordinator
        tv.setContentCompressionResistancePriority(.required, for: .vertical)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if tv.text != text { tv.text = text }
        tv.font = font
        if !editing && tv.isFirstResponder {
            DispatchQueue.main.async { tv.resignFirstResponder() }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let w = proposal.width ?? UIScreen.main.bounds.width
        let h = uiView.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude)).height
        return CGSize(width: w, height: max(h, 24))
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: EditableTextView
        init(_ p: EditableTextView) { parent = p }
        func textViewDidChange(_ tv: UITextView) { parent.text = tv.text }
        func textViewDidBeginEditing(_ tv: UITextView) { parent.onFocus() }
    }
}
