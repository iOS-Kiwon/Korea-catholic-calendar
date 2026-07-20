import SwiftUI
import WidgetKit

private let appGroupId = "group.com.sidore.catholiccalendar"

struct WidgetSnapshot: Decodable {
    let today: TodaySnapshot
    let month: MonthSnapshot
}

struct TodaySnapshot: Decodable {
    let dateLabel: String
    let liturgicalTitle: String
    let liturgicalColor: String
    let eventTitle: String
    let extraEventCount: Int
}

struct MonthSnapshot: Decodable {
    let title: String
    let days: [DaySnapshot]
}

struct DaySnapshot: Decodable, Identifiable {
    var id: String { dateKey }

    let dateKey: String
    let day: Int
    let weekday: Int
    let inMonth: Bool
    let isToday: Bool
    let liturgicalTitle: String
    let liturgicalColor: String
    let eventTitle: String
    let extraEventCount: Int
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: Date(), snapshot: Self.loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 6, to: now) ?? now
        completion(Timeline(entries: [
            TodayEntry(date: now, snapshot: Self.loadSnapshot())
        ], policy: .after(nextUpdate)))
    }

    private static func loadSnapshot() -> WidgetSnapshot {
        let defaults = UserDefaults(suiteName: appGroupId)
        guard
            let raw = defaults?.string(forKey: "widget_snapshot"),
            let data = raw.data(using: .utf8),
            let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else {
            return .placeholder
        }
        return snapshot
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: TodayEntry

    var body: some View {
        Group {
            switch family {
            case .systemLarge:
                MonthWidgetView(month: entry.snapshot.month)
            default:
                SmallTodayWidgetView(today: entry.snapshot.today)
            }
        }
        .containerBackground(.white, for: .widget)
        .widgetURL(URL(string: "catholiccalendar://today"))
    }
}

struct SmallTodayWidgetView: View {
    let today: TodaySnapshot

    var eventText: String? {
        guard !today.eventTitle.isEmpty else { return nil }
        if today.extraEventCount > 0 {
            return "\(today.eventTitle) 외 \(today.extraEventCount)개"
        }
        return today.eventTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(today.dateLabel)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(today.liturgicalTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color(for: today.liturgicalColor))
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            if let eventText {
                Text(eventText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct MonthWidgetView: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    let month: MonthSnapshot

    var body: some View {
        VStack(spacing: 2) {
            Text(month.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(height: 21)
                .frame(maxWidth: .infinity)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, weekday in
                    Text(weekday)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.36, green: 0.36, blue: 0.36))
                        .frame(height: 15)
                }
            }

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(month.days.prefix(42)) { day in
                    MonthDayCell(day: day)
                }
            }
        }
    }
}

struct MonthDayCell: View {
    let day: DaySnapshot

    private var title: String {
        if !day.eventTitle.isEmpty {
            return day.extraEventCount > 0 ? "\(day.eventTitle) +\(day.extraEventCount)" : day.eventTitle
        }
        return day.liturgicalTitle
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(day.day)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(numberColor)
                .frame(maxWidth: .infinity)

            Text(title)
                .font(.system(size: 8, weight: day.eventTitle.isEmpty ? .regular : .semibold))
                .foregroundStyle(day.eventTitle.isEmpty ? color(for: day.liturgicalColor) : Color.black)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 19, alignment: .top)
        }
        .padding(.horizontal, 0.5)
        .padding(.top, 1)
        .frame(height: 43, alignment: .top)
        .background(day.isToday ? Color(red: 1.0, green: 0.88, blue: 0.66) : .clear)
    }

    private var numberColor: Color {
        // 오늘은 빨간색 대신 검정(배경 하이라이트로 오늘을 구분).
        if day.isToday { return .black }
        if !day.inMonth { return Color(red: 0.62, green: 0.62, blue: 0.62) }
        if day.weekday == 7 { return Color(red: 0.78, green: 0.16, blue: 0.16) }
        if day.weekday == 6 { return Color(red: 0.08, green: 0.39, blue: 0.75) }
        return Color.black
    }
}

@main
struct TodayWidget: Widget {
    let kind = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("가톨릭 달력")
        .description("오늘의 전례와 이번 달 달력을 보여줍니다.")
        .supportedFamilies([.systemSmall, .systemLarge])
    }
}

private func color(for name: String) -> Color {
    switch name {
    case "red":
        return Color(red: 0.78, green: 0.16, blue: 0.16)
    case "white":
        return Color(red: 0.36, green: 0.34, blue: 0.42)
    case "violet":
        return Color(red: 0.41, green: 0.23, blue: 0.72)
    case "rose":
        return Color(red: 0.76, green: 0.09, blue: 0.36)
    case "black":
        return .primary
    default:
        return Color(red: 0.18, green: 0.49, blue: 0.20)
    }
}

extension WidgetSnapshot {
    static var placeholder: WidgetSnapshot {
        let today = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: today)
        let year = components.year ?? 2026
        let month = components.month ?? 7
        let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? today
        let leading = (calendar.component(.weekday, from: first) + 6) % 7
        let start = calendar.date(byAdding: .day, value: -leading, to: first) ?? first

        return WidgetSnapshot(
            today: TodaySnapshot(
                dateLabel: "7/17 금요일",
                liturgicalTitle: "오늘의 전례",
                liturgicalColor: "green",
                eventTitle: "개인일정",
                extraEventCount: 1
            ),
            month: MonthSnapshot(
                title: "\(year).\(month)",
                days: (0..<42).map { index in
                    let date = calendar.date(byAdding: .day, value: index, to: start) ?? start
                    return DaySnapshot(
                        dateKey: "\(index)",
                        day: calendar.component(.day, from: date),
                        weekday: calendar.component(.weekday, from: date),
                        inMonth: calendar.component(.month, from: date) == month,
                        isToday: calendar.isDate(date, inSameDayAs: today),
                        liturgicalTitle: index % 5 == 0 ? "전례" : "",
                        liturgicalColor: "green",
                        eventTitle: index % 8 == 0 ? "일정" : "",
                        extraEventCount: index % 16 == 0 ? 1 : 0
                    )
                }
            )
        )
    }
}
