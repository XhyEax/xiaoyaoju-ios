// Views/CastingContent.swift
// Shared casting UI used by RecognizeView (Tab 1) and ManualInputView (查卦→手动点选)
import SwiftUI
import SwiftData

struct CastingContent: View {
    @Environment(\.modelContext) private var modelContext

    var navigationTitle: String = "六爻起卦"

    @State private var collectedLines: [DivinationLine] = []
    @State private var question = ""
    @State private var savedAlert = false
    /// nil = append-next mode; some(i) = editing existing line i
    @State private var editingIndex: Int? = nil
    /// 摇一摇起卦开关，默认关闭
    @State private var shakeEnabled = false
    /// 刚保存的记录，供 alert「查看」跳转
    @State private var lastSaved: CastRecord?
    @State private var navigateToSaved = false
    /// 最近一次"新增爻"是否来自摇一摇（决定起卦方式）
    @State private var lastAddWasShake = false

    private var methodName: String { lastAddWasShake ? "手机起卦" : "铜钱起卦" }
    /// 是否在 Mac 上运行（无加速度计，摇一摇不可用 → 改为点击出爻）
    private var isMac: Bool { ProcessInfo.processInfo.isiOSAppOnMac || ProcessInfo.processInfo.isMacCatalystApp }

    private var db: GuaDatabase { GuaDatabase.shared }
    private var cast: Cast? { collectedLines.count == 6 ? Cast(lines: collectedLines) : nil }

    /// The index that the bottom grid targets: editing an existing line or appending next.
    private var activeIndex: Int { editingIndex ?? collectedLines.count }

    /// Bottom panel is visible while filling or when editing a specific line.
    private var showBottomPanel: Bool { collectedLines.count < 6 || editingIndex != nil }

    private var previewSlots: [Int?] {
        var s = [Int?](repeating: nil, count: 6)
        for (i, l) in collectedLines.enumerated() { s[i] = l.value }
        return s
    }

    private let castingOptions: [(Int, String, String, String)] = [
        (9, "老阳", "◯", "0字"),
        (8, "少阴", "", "1字"),
        (7, "少阳", "", "2字"),
        (6, "老阴", "✕", "3字"),
    ]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    liveGuaSection
                    if showBottomPanel { shakeToggle }
                    if let c = cast { resultSection(cast: c) }
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, showBottomPanel ? 10 : 16)
                // 编辑态下点击空白处关闭底部编辑框（爻线自身的点按优先生效）
                .contentShape(Rectangle())
                .onTapGesture { if editingIndex != nil { editingIndex = nil } }
            }

            if showBottomPanel {
                bottomInputPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: collectedLines.count)
        .animation(.easeInOut(duration: 0.2), value: editingIndex)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        // tabBar 隐藏由所属 NavigationStack 按 path 统一控制（易经 Tab 下此页为 push 态）
        .toolbar { toolbarContent }
        .alert("已保存到记录", isPresented: $savedAlert) {
            Button("好的") {}
            Button("查看") { navigateToSaved = true }.keyboardShortcut(.defaultAction)
        }
        .navigationDestination(isPresented: $navigateToSaved) {
            if let r = lastSaved { RecordDetailView(record: r) }
        }
        .onShake { if shakeEnabled { handleShake() } }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if editingIndex != nil {
                // Cancel edit mode
                Button {
                    editingIndex = nil
                } label: {
                    Text("完成").font(.subheadline)
                }
            } else {
                if !collectedLines.isEmpty {
                    Button {
                        undoLast()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    Button(role: .destructive) {
                        resetAll()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
        }
    }

    // MARK: - Live Hexagram Section

    private var liveGuaSection: some View {
        VStack(spacing: 10) {
            HexagramLinesView(
                slots: previewSlots,
                movingIndexes: cast?.movingLineIndexes ?? [],
                showLabels: true,
                lineWidth: 130,   // 宽线，对齐小程序 264rpx 比例
                lineSpacing: 4,   // 顶部六爻行距
                activeIndex: activeIndex < 6 ? activeIndex : nil,
                onTapLine: { i in
                    // Tap a filled line to enter edit mode for it
                    guard i < collectedLines.count else { return }
                    editingIndex = (editingIndex == i) ? nil : i
                }
            )
            .padding(.vertical, 6)

            if editingIndex == nil && collectedLines.count < 6 {
                Text("点击编辑")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Shake Toggle

    @ViewBuilder
    private var shakeToggle: some View {
        if isMac {
            // Mac 无加速度计：「爻一爻」改为点击一次随机出一爻（按下蓝→灰反馈）
            Button { handleShake() } label: { EmptyView() }
                .buttonStyle(MacCastButtonStyle())
        } else {
            Button {
                shakeEnabled.toggle()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                        .font(.system(size: 40))
                        .foregroundStyle(shakeEnabled ? Color.accentColor : .secondary)
                        .symbolEffect(.variableColor.iterative, isActive: shakeEnabled)
                    Text("爻一爻")
                        .font(.subheadline).bold()
                        .foregroundStyle(shakeEnabled ? Color.accentColor : .secondary)
                    Text("一念存疑，卦解天机")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    (shakeEnabled ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.06)),
                    in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(shakeEnabled ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bottom Input Panel

    private var bottomInputPanel: some View {
        VStack(spacing: 10) {
            HStack {
                if let ei = editingIndex {
                    Text("编辑\(yaoName(ei))").font(.subheadline).bold().foregroundStyle(Color.accentColor)
                } else {
                    Text("点选\(yaoName(collectedLines.count))").font(.subheadline).bold()
                }
                Spacer()
                if editingIndex == nil && shakeEnabled {
                    Label("摇晃自动出爻", systemImage: "iphone.gen3.radiowaves.left.and.right")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("字面朝上的枚数").font(.caption2).foregroundStyle(.secondary)
                }
            }
            yaoGrid
        }
        .padding(.horizontal).padding(.top, 10).padding(.bottom, 16)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }

    // MARK: - 4×1 Yao Grid

    private var yaoGrid: some View {
        VStack(spacing: 8) {
            ForEach(castingOptions, id: \.0) { value, name, symbol, coinLabel in
                Button { selectLine(value: value) } label: {
                    HStack(spacing: 0) {
                        Text(coinLabel)
                            .font(.caption).foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .center)
                        Divider().frame(height: 24).padding(.trailing, 10)
                        gridLineShape(value: value).padding(.trailing, 10)
                        Text("\(name)  \(symbol)")
                            .font(.subheadline).bold().foregroundStyle(.primary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .padding(.horizontal, 10)
                    .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func gridLineShape(value: Int) -> some View {
        let isYang = value == 7 || value == 9
        let w: CGFloat = 48; let h: CGFloat = 7; let gap: CGFloat = 7
        ZStack {
            if isYang {
                RoundedRectangle(cornerRadius: 2).fill(Color.primary).frame(width: w, height: h)
                if value == 9 { Circle().stroke(Color.primary, lineWidth: 1.5).frame(width: 7, height: 7) }
            } else {
                HStack(spacing: gap) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.primary).frame(width: (w-gap)/2, height: h)
                    RoundedRectangle(cornerRadius: 2).fill(Color.primary).frame(width: (w-gap)/2, height: h)
                }
                if value == 6 { Text("✕").font(.system(size: 8, weight: .bold)).foregroundStyle(Color.primary) }
            }
        }
        .frame(width: w)
    }

    // MARK: - Result Section

    @ViewBuilder
    private func resultSection(cast: Cast) -> some View {
        let lv     = cast.lines.map(\.value)
        let moving = cast.movingLineIndexes
        let bianLv = cast.bianGuaLineValues
        let benNum = cast.benGuaNumber
        let bianNum = cast.bianGuaNumber

        if let benNum, let benGua = db.hexagram(number: benNum) {
            VStack(spacing: 16) {
                Divider()

                NavigationLink {
                    HexagramDetailView(
                        hexagram: benGua,
                        movingIndexes: moving,
                        bianGua: bianNum.flatMap { db.hexagram(number: $0) },
                        lineValues: lv,
                        showShareActions: true)
                } label: {
                    if let bianLv, let bianNum, let bianGua = db.hexagram(number: bianNum) {
                        dualGuaDisplay(benGua: benGua, bianGua: bianGua,
                                       benLv: lv, bianLv: bianLv, moving: moving)
                    } else {
                        singleGuaDisplay(gua: benGua, lv: lv)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    Text("问题（可选）").font(.caption).foregroundStyle(.secondary)
                    TextField("例：近期运势", text: $question, axis: .vertical)
                        .lineLimit(1...4).textFieldStyle(.roundedBorder)
                }
                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = shareText(cast: cast, benGua: benGua)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button { saveRecord(cast: cast) } label: {
                        Label("保存到记录", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity).padding()
                            .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// 导出文本（同历史记录复制格式，但不含笔记）
    private func shareText(cast: Cast, benGua: Hexagram) -> String {
        var lines: [String] = []
        lines.append("时间：\(Date().displayString)")
        lines.append("方式：\(methodName)")
        if !question.isEmpty { lines.append("问题：\(question)") }

        let bianGua = cast.bianGuaNumber.flatMap { db.hexagram(number: $0) }
        var guaLine = "卦象：\(benGua.name)"
        if let bian = bianGua { guaLine += " → \(bian.name)" }
        lines.append(guaLine)

        if !cast.movingLineIndexes.isEmpty {
            let posNames = ["初爻", "二爻", "三爻", "四爻", "五爻", "上爻"]
            lines.append("动爻：")
            for idx in cast.movingLineIndexes {
                guard idx < benGua.yaos.count else { continue }
                let benYao = benGua.yaos[idx]
                var line = "  \(posNames[idx]) \(benYao.title)：\(benYao.content)"
                if let bian = bianGua, idx < bian.yaos.count {
                    let bianYao = bian.yaos[idx]
                    line += " → \(bianYao.title)：\(bianYao.content)"
                }
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }

    private func singleGuaDisplay(gua: Hexagram, lv: [Int]) -> some View {
        VStack(spacing: 10) {
            HexagramLinesView(lineValues: lv, lineWidth: 130, lineSpacing: 4).frame(maxWidth: .infinity)
            HStack(spacing: 8) {
                Text(gua.symbol).font(.system(size: 36))
                VStack(alignment: .leading) {
                    Text(gua.name).font(.title3).bold()
                    Text("无动爻").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func dualGuaDisplay(benGua: Hexagram, bianGua: Hexagram,
                                benLv: [Int], bianLv: [Int], moving: [Int]) -> some View {
        VStack(spacing: 12) {
            DualGuaView.alignedRow {
                Text("本卦").font(.caption).foregroundStyle(.secondary)
            } right: {
                Text("变卦").font(.caption).foregroundStyle(.blue)
            }
            DualGuaView(benValues: benLv, bianValues: bianLv, movingIndexes: moving)
            DualGuaView.alignedRow {
                VStack(spacing: 2) {
                    Text(benGua.symbol).font(.system(size: 28))
                    Text(benGua.name).font(.footnote).bold()
                }
            } right: {
                VStack(spacing: 2) {
                    Text(bianGua.symbol).font(.system(size: 28))
                    Text(bianGua.name).font(.footnote).foregroundStyle(.blue)
                }
            }
            HStack {
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.caption)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Logic

    private func selectLine(value: Int) {
        let idx = activeIndex
        guard idx < 6 else { return }
        let line = DivinationLine(value: value)
        if idx < collectedLines.count {
            collectedLines[idx] = line          // replace existing
        } else {
            collectedLines.append(line)          // append new
            lastAddWasShake = false             // 手动点选 → 铜钱起卦
        }
        editingIndex = nil                       // return to normal mode
    }

    /// Shake → simulate one toss of 3 coins → append the next 爻.
    /// Ignored while editing an existing line or after 6 爻 are filled.
    private func handleShake() {
        guard editingIndex == nil, collectedLines.count < 6 else { return }
        let value = randomYaoValue()
        collectedLines.append(DivinationLine(value: value))
        lastAddWasShake = true                  // 摇一摇 → 手机起卦

        if collectedLines.count == 6 {
            // 起卦完成：连续震动两次提醒
            Haptics.complete()
        } else {
            // Strong, obvious shake feedback (WeChat-style)
            Haptics.shake()
        }
    }

    /// Simulate 3 coin flips. backs (阳面) count → 爻值。
    /// 分布：老阴 1/8、少阳 3/8、少阴 3/8、老阳 1/8（与真实摇卦一致）。
    private func randomYaoValue() -> Int {
        let backs = (0..<3).reduce(0) { acc, _ in acc + (Bool.random() ? 1 : 0) }
        return lineValue(fromBacks: backs) ?? 7
    }

    private func undoLast() {
        guard !collectedLines.isEmpty else { return }
        editingIndex = nil
        collectedLines.removeLast()
    }

    private func resetAll() {
        editingIndex = nil
        collectedLines.removeAll()
        question = ""
        lastAddWasShake = false
    }

    private func saveRecord(cast: Cast) {
        guard let benNum = cast.benGuaNumber else { return }
        // 默认记录：六爻爻题，自下而上（初六/六二/.../上九）
        let titles = cast.lines.enumerated()
            .map { yaoTitle(index: $0.offset, value: $0.element.value) }
            .joined(separator: " / ")
        let record = CastRecord(
            date: .now,
            question: question,
            transcript: titles,
            method: methodName,
            lineValues: cast.lines.map(\.value),
            benGua: benNum,
            bianGua: cast.bianGuaNumber)
        modelContext.insert(record)
        lastSaved = record
        savedAlert = true
        resetAll()
    }

    private func yaoName(_ i: Int) -> String {
        guard i < 6 else { return "" }
        return ["初爻", "二爻", "三爻", "四爻", "五爻", "上爻"][i]
    }

    /// 爻题：阳爻称「九」、阴爻称「六」；初爻/上爻位名在前，其余在后。
    private func yaoTitle(index i: Int, value v: Int) -> String {
        let yy = (v == 7 || v == 9) ? "九" : "六"
        switch i {
        case 0: return "初\(yy)"
        case 5: return "上\(yy)"
        default: return "\(yy)\(["", "二", "三", "四", "五"][i])"
        }
    }
}

// Mac「爻一爻」按钮样式：常态蓝、按下变灰，作为点击出爻的反馈
private struct MacCastButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let c = configuration.isPressed ? Color.secondary : Color.accentColor
        return VStack(spacing: 8) {
            Image(systemName: "hand.tap")
                .font(.system(size: 40)).foregroundStyle(c)
            Text("爻一爻").font(.subheadline).bold().foregroundStyle(c)
            Text("点击随机出一爻").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            (configuration.isPressed ? Color.secondary.opacity(0.06) : Color.accentColor.opacity(0.1)),
            in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(configuration.isPressed ? Color.clear : Color.accentColor.opacity(0.5), lineWidth: 1.5)
        )
    }
}
