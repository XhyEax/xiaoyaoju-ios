// Views/HexagramDetailView.swift
import SwiftUI

struct HexagramDetailView: View {
    let hexagram: Hexagram
    var movingIndexes: [Int] = []
    var bianGua: Hexagram? = nil
    var showBianGua: Bool = true
    var lineValues: [Int]? = nil
    /// 起卦结果详情显示右上角「复制 / 分享」（查卦、记录内嵌时不显示，避免与外层工具栏重复）
    var showShareActions: Bool = false

    /// 浏览态（查卦）下用「上一卦/下一卦」切换显示的卦；nil 时即传入的 hexagram
    @State private var browseNumber: Int? = nil
    /// 「变」开关：隐藏各爻变卦（仅查卦浏览态生效），全局持久化
    @AppStorage("yj_hideBian") private var hideBian: Bool = false
    @State private var fav = FavoritesStore.shared

    private var db: GuaDatabase { GuaDatabase.shared }
    /// 当前显示的卦：浏览切换优先，否则为传入卦
    private var gua: Hexagram { browseNumber.flatMap { db.hexagram(number: $0) } ?? hexagram }
    /// 仅在「查卦」浏览（无六爻值）时显示上一卦/下一卦
    private var browseMode: Bool { showShareActions && lineValues == nil }
    /// 当前是否隐藏各爻变卦
    private var hideBianNow: Bool { browseMode && hideBian }

    /// 变卦 line values derived by flipping all moving lines
    private var bianGuaLineValues: [Int]? {
        guard let lv = lineValues, !movingIndexes.isEmpty else { return nil }
        return lv.enumerated().map { i, v in
            movingIndexes.contains(i) ? (v == 9 ? 8 : 7) : v
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                hexagramLinesSection
                sectionBlock(title: "卦辞", content: gua.desc)
                sectionBlock(title: "大象传", content: gua.xiangyue)
                yaoAndBianSection
            }
            .padding()
        }
        .navigationTitle(gua.name)
        .navigationBarTitleDisplayMode(.inline)
        // 控件放在顶部导航栏；底部 TabBar 常驻显示、不隐藏（无切换动画）
        .toolbar {
            if browseMode {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button { if gua.id > 1 { browseNumber = gua.id - 1 } } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(gua.id <= 1)
                    Button { if gua.id < 64 { browseNumber = gua.id + 1 } } label: {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(gua.id >= 64)
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if browseMode {
                    Button { hideBian.toggle() } label: {
                        Text("变").foregroundStyle(hideBian ? Color.secondary : Color.blue)
                    }
                    Button { fav.toggle("yj", gua.id) } label: {
                        let on = fav.isFav("yj", gua.id)
                        Image(systemName: on ? "star.fill" : "star")
                            .foregroundStyle(on ? Color(red: 0.96, green: 0.65, blue: 0.14) : Color.secondary)
                    }
                }
                if showShareActions {
                    Button {
                        UIPasteboard.general.string = shareText()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    ShareLink(item: shareText()) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    /// 复制/分享文本：起卦结果含时间/动爻；查卦（无六爻值）为整卦经文
    private func shareText() -> String {
        var lines: [String] = []
        if let lv = lineValues, lv.count == 6 {
            lines.append("时间：\(Date().displayString)")
            var guaLine = "卦象：\(gua.name)"
            if let bian = bianGua, !movingIndexes.isEmpty { guaLine += " → \(bian.name)" }
            lines.append(guaLine)
            lines.append("卦辞：\(gua.desc)")
            lines.append("大象：\(gua.xiangyue)")
            if !movingIndexes.isEmpty {
                let posNames = ["初爻", "二爻", "三爻", "四爻", "五爻", "上爻"]
                lines.append("动爻：")
                for idx in movingIndexes {
                    guard idx < gua.yaos.count else { continue }
                    let by = gua.yaos[idx]
                    var l = "  \(posNames[idx]) \(by.title)：\(by.content)"
                    if let bian = bianGua, idx < bian.yaos.count {
                        let biy = bian.yaos[idx]
                        l += " → \(biy.title)：\(biy.content)"
                    }
                    lines.append(l)
                }
            }
        } else {
            lines.append("卦象：\(gua.name)")
            lines.append("卦辞：\(gua.desc)")
            lines.append("大象：\(gua.xiangyue)")
            lines.append("爻辞：")
            for y in gua.yaos {
                lines.append("  \(y.title)：\(y.content)")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(gua.symbol).font(.system(size: 56))
            VStack(alignment: .leading, spacing: 4) {
                Text(gua.name).font(.title2).bold()
                Text("第 \(gua.id) 卦").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Hexagram lines (single or dual)

    @ViewBuilder
    private var hexagramLinesSection: some View {
        if let lv = lineValues {
            if showBianGua,
               !movingIndexes.isEmpty,
               let bianLv = bianGuaLineValues,
               let bian = bianGua {
                // ── 本卦 / 变卦 side by side (same format as per-yao cards) ──
                dualGuaCard(lv: lv, bianLv: bianLv, bian: bian)
            } else {
                // ── Single hexagram ──
                HexagramLinesView(lineValues: lv, movingIndexes: movingIndexes)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            }
        }
    }

    private func dualGuaCard(lv: [Int], bianLv: [Int], bian: Hexagram) -> some View {
        VStack(spacing: 12) {
            // Column headers
            DualGuaView.alignedRow(lineWidth: 80) {
                Text("本卦").font(.caption).foregroundStyle(.secondary)
            } right: {
                Text("变卦").font(.caption).foregroundStyle(.blue)
            }

            // Lines + per-row arrows (shared DualGuaView)
            DualGuaView(
                benValues: lv,
                bianValues: bianLv,
                movingIndexes: movingIndexes,
                lineWidth: 80)

            // Names row — 变卦 side is tappable
            DualGuaView.alignedRow(lineWidth: 80) {
                VStack(spacing: 3) {
                    Text(gua.symbol).font(.system(size: 28))
                    Text(gua.name).font(.caption).bold()
                    // 与变卦「详情 >」等高的隐形占位，保证两侧卦象对齐
                    HStack(spacing: 2) {
                        Text("详情").font(.caption2)
                        Image(systemName: "chevron.right").font(.caption2)
                    }
                    .hidden()
                }
                .padding(8)
            } right: {
                NavigationLink {
                    HexagramDetailView(hexagram: bian, showShareActions: true)
                } label: {
                    VStack(spacing: 3) {
                        Text(bian.symbol).font(.system(size: 28))
                        Text(bian.name).font(.caption).foregroundStyle(.blue)
                        HStack(spacing: 2) {
                            Text("详情").font(.caption2).foregroundStyle(.blue.opacity(0.8))
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.blue.opacity(0.7))
                        }
                    }
                    .padding(8)
                    .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Text sections

    private func sectionBlock(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundStyle(.secondary)
            Text(content).font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .contextMenu {
            Button { copyToClipboard(content) } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - 爻辞 + 各爻变卦

    private var yaoAndBianSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("爻辞 · 各爻变卦").font(.headline).foregroundStyle(.secondary)
                .padding(.bottom, 10)
            ForEach(Array(gua.yaos.indices.reversed()), id: \.self) { idx in
                yaoCard(index: idx)
                if idx != 0 { Divider().padding(.leading, 8) }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func yaoCard(index idx: Int) -> some View {
        let yao = gua.yaos[idx]
        let isMoving = movingIndexes.contains(idx)
        let changedNum = singleChangedGuaNumber(flipping: idx)
        let changedGua = changedNum.flatMap { db.hexagram(number: $0) }

        VStack(alignment: .leading, spacing: 8) {
            // Mini comparison + yao title
            HStack(alignment: .top, spacing: 12) {
                if changedGua != nil {
                    if hideBianNow {
                        MiniGuaView(yangLines: baseYangLines, changedIndex: idx)
                    } else {
                        HStack(spacing: 6) {
                            MiniGuaView(yangLines: baseYangLines, changedIndex: idx)
                            Image(systemName: "arrow.right").font(.caption).foregroundStyle(.blue)
                            MiniGuaView(yangLines: flippedLines(at: idx), changedIndex: idx, isAfter: true)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(yao.title).font(.subheadline).bold()
                            .foregroundStyle(isMoving ? .red : .primary)
                        if isMoving {
                            Text("动").font(.caption2)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(.red.opacity(0.15), in: Capsule())
                                .foregroundStyle(.red)
                        }
                    }
                    Text(yao.content).font(.body)
                    Text(yao.xiang).font(.footnote).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .contextMenu {
                    Button {
                        copyToClipboard("\(yao.title)：\(yao.content)\n象曰：\(yao.xiang)")
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                }
            }

            // 变卦 row — tappable NavigationLink
            if let changedGua, let changedNum, !hideBianNow {
                NavigationLink {
                    HexagramDetailView(hexagram: changedGua, showShareActions: true)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(changedGua.symbol).font(.system(size: 18))
                            Text("变卦：\(changedGua.name)")
                                .font(.subheadline).bold().foregroundStyle(.blue)
                            Spacer()
                            Text("第\(changedNum)卦").font(.caption).foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        let changedYao = changedGua.yaos[idx]
                        Text("\(changedYao.title)：\(changedYao.content)").font(.footnote)
                        Text(changedYao.xiang).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    let changedYao = changedGua.yaos[idx]
                    Button {
                        copyToClipboard("变卦：\(changedGua.name)\n\(changedYao.title)：\(changedYao.content)\n象曰：\(changedYao.xiang)")
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(isMoving ? .red.opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private var baseYangLines: [Bool] {
        if let lv = lineValues { return lv.map { $0 == 7 || $0 == 9 } }
        return gua.yaos.map { $0.title.contains("九") }
    }

    private func flippedLines(at i: Int) -> [Bool] {
        var lines = baseYangLines; lines[i].toggle(); return lines
    }

    private func singleChangedGuaNumber(flipping i: Int) -> Int? {
        let lines = flippedLines(at: i)
        guard let lower = Trigram.from(yangLines: Array(lines[0...2])),
              let upper = Trigram.from(yangLines: Array(lines[3...5]))
        else { return nil }
        return kingWenNumber(upper: upper, lower: lower)
    }
}

// MARK: - Mini Gua View (private, per-yao comparison)

private struct MiniGuaView: View {
    let yangLines: [Bool]
    var changedIndex: Int? = nil
    var isAfter: Bool = false

    private let totalWidth: CGFloat = 36
    private let gap: CGFloat = 4
    private let lineH: CGFloat = 5

    var body: some View {
        VStack(spacing: 3) {
            ForEach(Array(yangLines.indices.reversed()), id: \.self) { i in
                let isChanged = changedIndex == i
                let isYang = yangLines[i]
                let color: Color = isChanged ? .blue : .primary

                if isYang {
                    // 实线（阳），整条与阴线总宽一致
                    RoundedRectangle(cornerRadius: 1).fill(color)
                        .frame(width: totalWidth, height: lineH)
                } else {
                    // 断线（阴），两段 + 间隙 = totalWidth，与阳线对齐
                    HStack(spacing: gap) {
                        RoundedRectangle(cornerRadius: 1).fill(color)
                            .frame(width: (totalWidth - gap) / 2, height: lineH)
                        RoundedRectangle(cornerRadius: 1).fill(color)
                            .frame(width: (totalWidth - gap) / 2, height: lineH)
                    }
                    .frame(width: totalWidth)
                }
            }
        }
        .frame(width: totalWidth)
    }
}
