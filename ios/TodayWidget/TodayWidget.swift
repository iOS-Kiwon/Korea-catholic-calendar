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
    // 위젯이 이 날을 '오늘'로 판정했을 때 작은 위젯에 쓰는 전체 정보.
    // (구버전 스냅샷 호환을 위해 optional)
    let titleFull: String?
    let dateLabel: String?
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
        // 자정마다 위젯이 다시 그려지도록 향후 며칠의 '자정' 엔트리를 만든다.
        // 각 엔트리 날짜(entry.date)를 기준으로 뷰가 '오늘'을 직접 판정하므로,
        // 자정이 지나면 스냅샷의 42칸 격자에서 해당 날을 찾아 그린다.
        // 타임존/서머타임 변경까지 반영하도록 autoupdatingCurrent 사용.
        let snapshot = Self.loadSnapshot()
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        var entries: [TodayEntry] = [TodayEntry(date: now, snapshot: snapshot)]
        let startOfToday = calendar.startOfDay(for: now)
        for offset in 1...8 {
            if let midnight = calendar.date(byAdding: .day, value: offset, to: startOfToday) {
                entries.append(TodayEntry(date: midnight, snapshot: snapshot))
            }
        }
        // 마지막 엔트리 이후 WidgetKit이 새 타임라인을 요청한다.
        completion(Timeline(entries: entries, policy: .atEnd))
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
        // baked된 today/isToday 대신 엔트리(현재) 날짜로 '오늘'을 판정한다.
        let todayKey = widgetDateKey(for: entry.date)
        Group {
            switch family {
            case .systemLarge:
                MonthWidgetView(month: entry.snapshot.month, todayKey: todayKey)
            default:
                SmallTodayWidgetView(snapshot: entry.snapshot, todayKey: todayKey)
            }
        }
        .containerBackground(.white, for: .widget)
        .widgetURL(URL(string: "catholiccalendar://today"))
    }
}

struct SmallTodayWidgetView: View {
    let snapshot: WidgetSnapshot
    let todayKey: String

    // 격자에서 오늘 날짜 셀을 찾는다. 없으면(예외적) baked된 today로 폴백.
    private var day: DaySnapshot? {
        snapshot.month.days.first { $0.dateKey == todayKey }
    }

    private var dateLabel: String {
        day?.dateLabel ?? snapshot.today.dateLabel
    }

    private var liturgicalTitle: String {
        day?.titleFull ?? snapshot.today.liturgicalTitle
    }

    private var liturgicalColor: String {
        day?.liturgicalColor ?? snapshot.today.liturgicalColor
    }

    private var eventTitle: String {
        day?.eventTitle ?? snapshot.today.eventTitle
    }

    private var extraEventCount: Int {
        day?.extraEventCount ?? snapshot.today.extraEventCount
    }

    private var eventText: String? {
        guard !eventTitle.isEmpty else { return nil }
        if extraEventCount > 0 {
            return "\(eventTitle) 외 \(extraEventCount)개"
        }
        return eventTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(dateLabel)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(liturgicalTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color(for: liturgicalColor))
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
    let todayKey: String

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
                    MonthDayCell(day: day, isToday: day.dateKey == todayKey)
                }
            }
        }
    }
}

struct MonthDayCell: View {
    let day: DaySnapshot
    // baked된 day.isToday 대신 현재 날짜 기준으로 계산된 값을 받는다.
    let isToday: Bool

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
        .background(isToday ? Color(red: 1.0, green: 0.88, blue: 0.66) : .clear)
    }

    private var numberColor: Color {
        // 오늘은 빨간색 대신 검정(배경 하이라이트로 오늘을 구분).
        if isToday { return .black }
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

// 스냅샷의 dateKey(YYYY-MM-DD, Dart eventDateKey와 동일 포맷)를 로컬 날짜 기준으로 만든다.
private enum WidgetDateKey {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private func widgetDateKey(for date: Date) -> String {
    WidgetDateKey.formatter.string(from: date)
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
                    let weekday = calendar.component(.weekday, from: date)
                    let names = ["일", "월", "화", "수", "목", "금", "토"]
                    return DaySnapshot(
                        dateKey: widgetDateKey(for: date),
                        day: calendar.component(.day, from: date),
                        weekday: weekday,
                        inMonth: calendar.component(.month, from: date) == month,
                        isToday: calendar.isDate(date, inSameDayAs: today),
                        liturgicalTitle: index % 5 == 0 ? "전례" : "",
                        liturgicalColor: "green",
                        eventTitle: index % 8 == 0 ? "일정" : "",
                        extraEventCount: index % 16 == 0 ? 1 : 0,
                        titleFull: "오늘의 전례",
                        dateLabel: "\(calendar.component(.month, from: date))/\(calendar.component(.day, from: date)) \(names[(weekday - 1) % 7])요일"
                    )
                }
            )
        )
    }
}
