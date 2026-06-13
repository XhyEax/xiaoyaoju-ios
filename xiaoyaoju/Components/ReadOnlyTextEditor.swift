// Components/ReadOnlyTextEditor.swift
// 只读但可选中的文本（UITextView 封装）——原地长按选中/复制，整项目复用
import SwiftUI
import UIKit

struct ReadOnlyTextEditor: UIViewRepresentable {
    let text: String
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var color: UIColor = .label
    var lineSpacing: CGFloat = 0
    var highlight: String = ""   // 搜索关键词，命中处黄色高亮

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
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if lineSpacing > 0 {
            let p = NSMutableParagraphStyle(); p.lineSpacing = lineSpacing
            attrs[.paragraphStyle] = p
        }
        let attr = NSMutableAttributedString(string: text, attributes: attrs)
        if !highlight.isEmpty {
            let ns = text as NSString
            let hlColor = UIColor(red: 1, green: 0.88, blue: 0.54, alpha: 1)
            var loc = 0
            while loc < ns.length {
                let r = ns.range(of: highlight, options: .caseInsensitive,
                                 range: NSRange(location: loc, length: ns.length - loc))
                if r.location == NSNotFound { break }
                attr.addAttribute(.backgroundColor, value: hlColor, range: r)
                loc = r.location + max(1, r.length)
            }
        }
        tv.attributedText = attr
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let w = proposal.width ?? UIScreen.main.bounds.width
        let h = uiView.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude)).height
        return CGSize(width: w, height: h)
    }
}
