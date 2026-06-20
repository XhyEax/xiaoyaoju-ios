// Widgets.swift — 每日一卦 / 每日一句 / 快速起卦
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - 每日内容（按日确定性轮换，跨天刷新）

struct DailyEntry: TimelineEntry { let date: Date }

struct DailyProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyEntry { DailyEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (DailyEntry) -> Void) {
        completion(DailyEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyEntry>) -> Void) {
        let start = Calendar.current.startOfDay(for: Date())
        let next = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        completion(Timeline(entries: [DailyEntry(date: start)], policy: .after(next)))
    }
}

// MARK: 每日一卦

struct DailyGuaWidget: Widget {
    let kind = "DailyGuaWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyProvider()) { entry in
            DailyGuaView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("每日一卦")
        .description("每天一个卦象与卦辞")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct DailyGuaView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyEntry
    private var gua: GuaLite? { WidgetData.gua(for: entry.date) }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)   // 撑满，刷新按钮锚在 widget 右上角、不随卦象移动
            .overlay(alignment: .topTrailing) {
                if family == .systemSmall || family == .systemMedium {
                    Button(intent: NextGuaIntent()) {
                        Image(systemName: "arrow.clockwise").font(.caption2).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .widgetURL(gua.map { WidgetLink.gua($0.number) })   // 点按 → 卦详情
    }

    @ViewBuilder private var content: some View {
        let g = gua
        switch family {
        case .accessoryInline:
            Text("\(g?.symbol ?? "☰") \(g?.name ?? "")")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(g?.symbol ?? "☰").font(.title2)
                    Text(g?.name.prefix(2) ?? "").font(.system(size: 9))
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("\(g?.symbol ?? "") \(g?.name ?? "")").font(.headline).widgetAccentable()
                Text(g?.judgment ?? "").font(.caption2).lineLimit(2)
            }
        case .systemMedium:
            HStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text(g?.symbol ?? "").font(.system(size: 44))
                    Text(g?.name ?? "").font(.subheadline.bold())
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("今日一卦").font(.caption2).foregroundStyle(.secondary)
                    Text(g?.judgment ?? "").font(.callout).lineLimit(3)
                    Text(g?.xiang ?? "").font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
        default: // systemSmall
            VStack(spacing: 6) {
                Text(g?.symbol ?? "").font(.system(size: 40))
                Text(g?.name ?? "").font(.subheadline.bold())
                Text(g?.judgment ?? "").font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(2).multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: 每日一句

struct DailyQuoteWidget: Widget {
    let kind = "DailyQuoteWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyProvider()) { entry in
            DailyQuoteView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("每日一句")
        .description("每天一句经典")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct DailyQuoteView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyEntry
    private var quote: QuoteLite? { WidgetData.quote(for: entry.date) }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)   // 撑满，刷新按钮锚右上角不移动
            .overlay(alignment: .topTrailing) {
                if family == .systemMedium || family == .systemLarge {
                    Button(intent: NextQuoteIntent()) {
                        Image(systemName: "arrow.clockwise").font(.caption2).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .widgetURL(quote.map { WidgetLink.chapter($0.book, $0.index) })   // 点按 → 对应章节
    }

    @ViewBuilder private var content: some View {
        let q = quote
        if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 2) {
                Text(q?.text ?? "").font(.caption).lineLimit(3)
                Text(q?.source ?? "").font(.caption2).foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("每日一句").font(.caption2).foregroundStyle(.secondary)
                Text(q?.text ?? "")
                    .font(family == .systemLarge ? .title3 : .callout)
                    .lineLimit(family == .systemLarge ? 8 : 4)
                Spacer(minLength: 0)
                Text(q?.source ?? "").font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

// MARK: 快速起卦

struct QuickCastWidget: Widget {
    let kind = "QuickCastWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyProvider()) { _ in
            QuickCastView()
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(WidgetLink.cast)
        }
        .configurationDisplayName("快速起卦")
        .description("一键进入起卦")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct QuickCastView: View {
    @Environment(\.widgetFamily) private var family
    var body: some View {
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "hexagon")
                    .font(.title2)
                    .overlay(Text("卦").font(.system(size: 11, weight: .bold)))
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "hexagon.fill").font(.system(size: 34)).foregroundStyle(.tint)
                Text("六爻起卦").font(.headline)
                Text("点击占问").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
