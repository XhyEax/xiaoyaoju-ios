// Views/HexagramLinesView.swift
import SwiftUI

/// Draws six yao lines (初爻 bottom → 上爻 top).
/// `slots[i]` = nil renders a ghost/placeholder line (dim grey).
struct HexagramLinesView: View {
    let slots: [Int?]
    var movingIndexes: [Int] = []
    var showLabels: Bool = false
    var lineWidth: CGFloat = 80
    var lineSpacing: CGFloat = 8
    /// Index to highlight with an accent border (active / being edited)
    var activeIndex: Int? = nil
    /// When set, filled rows become tappable
    var onTapLine: ((Int) -> Void)? = nil

    // MARK: Convenience inits

    init(lineValues: [Int], movingIndexes: [Int] = [], showLabels: Bool = false,
         lineWidth: CGFloat = 80, activeIndex: Int? = nil, onTapLine: ((Int) -> Void)? = nil) {
        self.slots = lineValues.map { Optional($0) }
        self.movingIndexes = movingIndexes
        self.showLabels = showLabels
        self.lineWidth = lineWidth
        self.activeIndex = activeIndex
        self.onTapLine = onTapLine
    }

    init(slots: [Int?], movingIndexes: [Int] = [], showLabels: Bool = false,
         lineWidth: CGFloat = 80, activeIndex: Int? = nil, onTapLine: ((Int) -> Void)? = nil) {
        self.slots = slots
        self.movingIndexes = movingIndexes
        self.showLabels = showLabels
        self.lineWidth = lineWidth
        self.activeIndex = activeIndex
        self.onTapLine = onTapLine
    }

    var body: some View {
        VStack(spacing: lineSpacing) {
            ForEach(Array(slots.indices.reversed()), id: \.self) { i in
                yaoRow(index: i)
            }
        }
    }

    @ViewBuilder
    private func yaoRow(index i: Int) -> some View {
        let val      = slots[i]
        let filled   = val != nil
        let isYang   = val.map { $0 == 7 || $0 == 9 } ?? true
        let isMoving = movingIndexes.contains(i)
        let isActive = activeIndex == i
        let color: Color = !filled ? .secondary.opacity(0.18)
                         : isMoving ? .red : .primary

        HStack(spacing: showLabels ? 8 : 0) {
            if showLabels {
                Text(yaoName(i))
                    .font(.caption2).foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                    .frame(width: 28, alignment: .trailing)
            }

            yaoLine(isYang: isYang, isMoving: isMoving && filled, color: color)
                .frame(width: lineWidth, height: 14)

            if showLabels {
                if let v = val {
                    Text(yaoTitle(index: i, value: v))
                        .font(.caption2)
                        .foregroundStyle(isMoving ? .red : .secondary)
                        .frame(width: 42, alignment: .leading)
                } else {
                    Color.clear.frame(width: 42, height: 10)
                }
            }
        }
        // 激活高亮边框包裹「标签 + 爻」整体，但按内容宽度（不铺满整行）
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            isActive
            ? RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.5), lineWidth: 1.5)
            : nil
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if filled { onTapLine?(i) }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func yaoLine(isYang: Bool, isMoving: Bool, color: Color) -> some View {
        let gap = lineWidth * 0.14
        ZStack {
            if isYang {
                RoundedRectangle(cornerRadius: 2).fill(color)
                    .frame(width: lineWidth, height: 10)
                if isMoving {
                    Circle().stroke(Color.red, lineWidth: 1.5).frame(width: 8, height: 8)
                }
            } else {
                HStack(spacing: gap) {
                    RoundedRectangle(cornerRadius: 2).fill(color).frame(width: (lineWidth - gap) / 2, height: 10)
                    RoundedRectangle(cornerRadius: 2).fill(color).frame(width: (lineWidth - gap) / 2, height: 10)
                }
                if isMoving {
                    Text("✕").font(.system(size: 9, weight: .bold)).foregroundStyle(.red)
                }
            }
        }
    }

    private func yaoName(_ i: Int) -> String {
        ["初爻", "二爻", "三爻", "四爻", "五爻", "上爻"][i]
    }

    /// 爻题：位置 + 阴阳。阳爻称「九」，阴爻称「六」。
    /// 初爻/上爻位名在前（初九、上六），其余在后（九二、六五）。
    private func yaoTitle(index i: Int, value v: Int) -> String {
        let isYang = (v == 7 || v == 9)
        let yinYang = isYang ? "九" : "六"
        switch i {
        case 0: return "初\(yinYang)"
        case 5: return "上\(yinYang)"
        default:
            let pos = ["", "二", "三", "四", "五"][i]
            return "\(yinYang)\(pos)"
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        HexagramLinesView(lineValues: [9, 8, 7, 6, 9, 7], movingIndexes: [0, 4],
                          showLabels: true, activeIndex: 2)
        HexagramLinesView(slots: [9, 8, nil, nil, nil, nil], showLabels: true, activeIndex: 2)
    }
    .padding()
}
