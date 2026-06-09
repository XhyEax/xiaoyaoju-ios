// Views/DualGuaView.swift
// Shared component: draws 本卦 and 变卦 lines side by side with per-row arrows.
import SwiftUI

struct DualGuaView: View {
    let benValues: [Int]       // 6 line values for 本卦 (index 0 = 初爻)
    let bianValues: [Int]      // 6 line values for 变卦
    let movingIndexes: [Int]   // which rows have arrows
    var lineWidth: CGFloat = DualGuaView.defaultLineWidth

    /// Shared geometry so header/footer rows align with the lines.
    static let defaultLineWidth: CGFloat = 76
    static let arrowWidth: CGFloat = 22

    private let lineH: CGFloat = 10
    private let rowSpacing: CGFloat = 8
    private var arrowW: CGFloat { DualGuaView.arrowWidth }

    /// Builds a header/footer row whose two columns line up exactly with the lines:
    /// `[leftWidth] [arrowGap] [rightWidth]`, centered as a group.
    static func alignedRow<L: View, R: View>(
        lineWidth: CGFloat = defaultLineWidth,
        @ViewBuilder left: () -> L,
        @ViewBuilder right: () -> R
    ) -> some View {
        HStack(spacing: 0) {
            left().frame(width: lineWidth)
            Color.clear.frame(width: arrowWidth)
            right().frame(width: lineWidth)
        }
        .frame(maxWidth: .infinity)
    }

    var body: some View {
        VStack(spacing: rowSpacing) {
            ForEach(Array((0..<6).reversed()), id: \.self) { i in
                HStack(spacing: 0) {
                    lineShape(value: benValues[i], isMoving: movingIndexes.contains(i))
                        .frame(width: lineWidth, height: lineH)
                    arrowCell(moving: movingIndexes.contains(i))
                        .frame(width: arrowW)
                    lineShape(value: bianValues[i], isMoving: false)
                        .frame(width: lineWidth, height: lineH)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func arrowCell(moving: Bool) -> some View {
        if moving {
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.red)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func lineShape(value: Int, isMoving: Bool) -> some View {
        let isYang = value == 7 || value == 9
        let gap = lineWidth * 0.14
        let color: Color = isMoving ? .red : .primary

        ZStack {
            if isYang {
                RoundedRectangle(cornerRadius: 2).fill(color)
                    .frame(width: lineWidth, height: lineH)
                if isMoving {
                    Circle().stroke(Color.red, lineWidth: 1.5).frame(width: 8, height: 8)
                }
            } else {
                HStack(spacing: gap) {
                    RoundedRectangle(cornerRadius: 2).fill(color)
                        .frame(width: (lineWidth - gap) / 2, height: lineH)
                    RoundedRectangle(cornerRadius: 2).fill(color)
                        .frame(width: (lineWidth - gap) / 2, height: lineH)
                }
                if isMoving {
                    Text("✕").font(.system(size: 9, weight: .bold)).foregroundStyle(.red)
                }
            }
        }
    }
}
