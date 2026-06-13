// Components/ReadOnlyTextEditor.swift
// 只读但可选中的文本（UITextView 封装）——原地长按选中/复制，整项目复用
import SwiftUI
import UIKit

struct ReadOnlyTextEditor: UIViewRepresentable {
    let text: String
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var color: UIColor = .label
    var lineSpacing: CGFloat = 0

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = false              // 随内容撑高，嵌在 ScrollView 里
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.required, for: .vertical)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if lineSpacing > 0 {
            let p = NSMutableParagraphStyle()
            p.lineSpacing = lineSpacing
            tv.attributedText = NSAttributedString(
                string: text,
                attributes: [.font: font, .foregroundColor: color, .paragraphStyle: p]
            )
        } else {
            tv.font = font
            tv.textColor = color
            tv.text = text
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let w = proposal.width ?? UIScreen.main.bounds.width
        let h = uiView.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude)).height
        return CGSize(width: w, height: h)
    }
}
