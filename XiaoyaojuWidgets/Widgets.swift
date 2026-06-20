// Widgets.swift — 每日一卦 / 每日一句 / 最近一卦 / 快速起卦
import WidgetKit
import SwiftUI

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

// MARK: 最近一卦（读 App Group 共享摘要）

struct RecentEntry: TimelineEntry { let date: Date; let latest: WidgetShared.Latest? }

struct RecentProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentEntry { RecentEntry(date: Date(), latest: nil) }
    func getSnapshot(in context: Context, completion: @escaping (RecentEntry) -> Void) {
        completion(RecentEntry(date: Date(), latest: WidgetShared.latest()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentEntry>) -> Void) {
        // 主要靠 App 保存后 reloadAllTimelines() 刷新；这里再给个 6 小时兜底
        let next = Date().addingTimeInterval(6 * 3600)
        completion(Timeline(entries: [RecentEntry(date: Date(), latest: WidgetShared.latest())], policy: .after(next)))
    }
}

struct RecentCastWidget: Widget {
    let kind = "RecentCastWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentProvider()) { entry in
            RecentCastView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(WidgetLink.latestRecord)
        }
        .configurationDisplayName("最近一卦")
        .description("最近一次起卦记录")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct RecentCastView: View {
    let entry: RecentEntry
    var body: some View {
        if let l = entry.latest {
            VStack(alignment: .leading, spacing: 6) {
                Text("最近一卦").font(.caption2).foregroundStyle(.secondary)
                Text(l.name).font(.title3.bold())
                if !l.question.isEmpty {
                    Text(l.question).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
                if let d = l.date {
                    Text(d, format: .dateTime.month().day().hour().minute())
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "circle.grid.cross").font(.title2).foregroundStyle(.secondary)
                Text("还没有起卦记录").font(.caption).foregroundStyle(.secondary)
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
                Text("起卦").font(.headline)
                Text("点击占问").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
