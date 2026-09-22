import Charts
import SwiftUI
import SwiftData

/// The week's numbers.
///
/// Two charts, each answering one question, rather than one chart trying to answer both:
///
/// - **Per day**: how much of each day did you account for? Two stacked series — logged and
///   not logged — so the bar's full height is the time the day actually covered and the grey
///   remainder is the honest gap. One question, two colours, no palette to get wrong.
/// - **By category**: where did the week go? A sorted bar list where every row carries its
///   own symbol, name and duration. Identity comes from the label, not the hue, which is what
///   makes fourteen categories legible — a fourteen-colour stacked bar would not be.
///
/// Everything is duration-weighted, so the short stub slots at either end of a day count for
/// what they actually were.
struct WeekView: View {

    @Environment(DayController.self) private var dayController: DayController

    @State private var weekOffset = 0
    @State private var selectedDay: Day?

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = .current
        return calendar
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    weekPicker

                    let stats = dayStats()
                    let totals = categoryTotals()
                    let unaccounted = stats.reduce(0) { $0 + $1.unaccountedMinutes }
                    let logged = stats.reduce(0) { $0 + $1.loggedMinutes }

                    if logged == 0 && unaccounted == 0 {
                        emptyWeek
                    } else {
                        summaryCard(logged: logged, unaccounted: unaccounted)
                        perDayCard(stats)
                        categoryCard(totals: totals, unaccountedMinutes: unaccounted)
                        tagCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Theme.paper)
            .navigationTitle("Week")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(unwrapping: $selectedDay) { day in
                DayDetailView(day: day)
            }
        }
    }

    // MARK: - Week selection

    private var weekInterval: DateInterval {
        let anchor = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: .now) ?? .now
        return calendar.dateInterval(of: .weekOfYear, for: anchor)
            ?? DateInterval(start: calendar.startOfDay(for: anchor), duration: 7 * 24 * 3600)
    }

    private var weekPicker: some View {
        HStack {
            Button {
                weekOffset += 1
            } label: {
                Image(systemName: "chevron.left").font(.body.weight(.semibold))
            }

            Spacer()

            VStack(spacing: 1) {
                Text(weekOffset == 0 ? "This week" : weekOffset == 1 ? "Last week" : "\(weekOffset) weeks ago")
                    .font(.subheadline.weight(.semibold))
                Text(weekRangeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                weekOffset -= 1
            } label: {
                Image(systemName: "chevron.right").font(.body.weight(.semibold))
            }
            .disabled(weekOffset == 0)
        }
    }

    private var weekRangeLabel: String {
        let interval = weekInterval
        let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        return "\(Formatters.longDate(interval.start)) – \(Formatters.longDate(end))"
    }

    // MARK: - Data

    private struct DayStat: Identifiable {
        let id: Date
        let date: Date
        let label: String
        let loggedMinutes: Int
        let unaccountedMinutes: Int
        let day: Day?

        /// What the day covered in total. The bar's full height.
        var elapsedMinutes: Int { loggedMinutes + unaccountedMinutes }
    }

    private func dayStats() -> [DayStat] {
        let interval = weekInterval
        let days = dayController.allDays()

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: interval.start) else {
                return nil
            }
            let startOfDay = calendar.startOfDay(for: date)
            let match = days.first { calendar.isDate($0.date, inSameDayAs: startOfDay) }
            return DayStat(
                id: startOfDay,
                date: startOfDay,
                label: Formatters.weekdayInitials(startOfDay),
                loggedMinutes: match?.loggedMinutes ?? 0,
                unaccountedMinutes: match?.unaccountedMinutes ?? 0,
                day: match
            )
        }
    }

    private struct CategoryTotal: Identifiable {
        let id: UUID
        let category: LogCategory
        let minutes: Int
    }

    private func categoryTotals() -> [CategoryTotal] {
        let interval = weekInterval
        let days = dayController.allDays().filter {
            $0.date >= calendar.startOfDay(for: interval.start) && $0.date < interval.end
        }

        var byCategory: [UUID: (LogCategory, Int)] = [:]
        for day in days {
            for slot in day.slots where slot.state == .logged {
                guard let category = slot.category else { continue }
                let existing = byCategory[category.id]?.1 ?? 0
                byCategory[category.id] = (category, existing + slot.durationMinutes)
            }
        }

        return byCategory.values
            .map { CategoryTotal(id: $0.0.id, category: $0.0, minutes: $0.1) }
            .sorted { $0.minutes > $1.minutes }
    }

    private func topTags() -> [(key: String, minutes: Int)] {
        let interval = weekInterval
        let days = dayController.allDays().filter {
            $0.date >= calendar.startOfDay(for: interval.start) && $0.date < interval.end
        }
        var totals: [String: Int] = [:]
        for day in days {
            for slot in day.slots where slot.state == .logged {
                for key in slot.tagKeys {
                    totals[key, default: 0] += slot.durationMinutes
                }
            }
        }
        return totals
            .map { (key: $0.key, minutes: $0.value) }
            .sorted { $0.minutes > $1.minutes }
            .prefix(8)
            .map { $0 }
    }

    // MARK: - Cards

    private var emptyWeek: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Nothing logged this week")
                .font(.subheadline.weight(.medium))
            Text("Start a day on the Today tab and this fills in.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private func summaryCard(logged: Int, unaccounted: Int) -> some View {
        let settled = logged + unaccounted
        let fraction = settled > 0 ? Double(logged) / Double(settled) : 1

        return HStack(alignment: .firstTextBaseline, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.percent(fraction))
                    .font(Theme.serif(40, .bold))
                    .foregroundStyle(Theme.ink)
                Text("accounted for")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.duration(minutes: logged))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text("logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if unaccounted > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Formatters.duration(minutes: unaccounted))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Text("unaccounted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Theme.card)
        .overlay(Rectangle().strokeBorder(Theme.rule, lineWidth: 1))
    }

    private func perDayCard(_ stats: [DayStat]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Marginalia("Per day", color: Theme.ink2, weight: .bold)

            Chart {
                ForEach(stats) { stat in
                    BarMark(
                        x: .value("Day", stat.label),
                        y: .value("Minutes", stat.loggedMinutes)
                    )
                    .foregroundStyle(by: .value("Time", "Logged"))

                    BarMark(
                        x: .value("Day", stat.label),
                        y: .value("Minutes", stat.unaccountedMinutes)
                    )
                    .foregroundStyle(by: .value("Time", "Not logged"))
                }
            }
            .chartForegroundStyleScale([
                "Logged": Theme.ink,
                "Not logged": Theme.violet
            ])
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let minutes = value.as(Int.self) {
                            Text(Formatters.duration(minutes: minutes))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(.caption2)
                }
            }
            .chartLegend(position: .bottom, spacing: 8)
            .frame(height: 180)

            // The chart is the overview; the rows are how you get into a day.
            VStack(spacing: 0) {
                ForEach(stats) { stat in
                    Button {
                        selectedDay = stat.day
                    } label: {
                        HStack {
                            Text(Formatters.longDate(stat.date))
                                .font(.footnote)
                            Spacer()
                            if stat.elapsedMinutes == 0 {
                                Text("—")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            } else {
                                Text(Formatters.duration(minutes: stat.loggedMinutes))
                                    .font(.footnote.weight(.medium))
                                    .monospacedDigit()
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(stat.day == nil)

                    if stat.id != stats.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.card)
        .overlay(Rectangle().strokeBorder(Theme.rule, lineWidth: 1))
    }

    private func categoryCard(totals: [CategoryTotal], unaccountedMinutes: Int) -> some View {
        let maximum = max(
            totals.first?.minutes ?? 0,
            unaccountedMinutes
        )
        let grandTotal = totals.reduce(0) { $0 + $1.minutes } + unaccountedMinutes

        return VStack(alignment: .leading, spacing: 12) {
            Marginalia("By category", color: Theme.ink2, weight: .bold)

            VStack(spacing: 10) {
                ForEach(totals) { total in
                    CategoryTotalRow(
                        symbolName: total.category.symbolName,
                        name: total.category.name,
                        color: total.category.color,
                        minutes: total.minutes,
                        maximum: maximum,
                        grandTotal: grandTotal
                    )
                }

                if unaccountedMinutes > 0 {
                    CategoryTotalRow(
                        symbolName: "lock.fill",
                        name: "Unaccounted",
                        color: Theme.violet,
                        minutes: unaccountedMinutes,
                        maximum: maximum,
                        grandTotal: grandTotal
                    )
                }
            }
        }
        .padding(16)
        .background(Theme.card)
        .overlay(Rectangle().strokeBorder(Theme.rule, lineWidth: 1))
    }

    @ViewBuilder
    private func tagCard() -> some View {
        let tags = topTags()
        if !tags.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Marginalia("Top tags", color: Theme.ink2, weight: .bold)

                ForEach(tags, id: \.key) { tag in
                    HStack {
                        Text("#\(tag.key)")
                            .font(.footnote)
                        Spacer()
                        Text(Formatters.duration(minutes: tag.minutes))
                            .font(.footnote.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Theme.card)
            .overlay(Rectangle().strokeBorder(Theme.rule, lineWidth: 1))
        }
    }
}

/// One row of the category bar list.
///
/// Directly labelled — symbol, name, duration and share all present — so the bar's colour is
/// reinforcement rather than the only way to tell one row from another.
private struct CategoryTotalRow: View {

    let symbolName: String
    let name: String
    let color: Color
    let minutes: Int
    let maximum: Int
    let grandTotal: Int

    private var fraction: Double {
        guard maximum > 0 else { return 0 }
        return Double(minutes) / Double(maximum)
    }

    private var share: Double {
        guard grandTotal > 0 else { return 0 }
        return Double(minutes) / Double(grandTotal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.caption)
                    .foregroundStyle(color)
                    .frame(width: 16)
                Text(name)
                    .font(.footnote.weight(.medium))
                Spacer()
                Text(Formatters.duration(minutes: minutes))
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                Text(Formatters.percent(share))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 34, alignment: .trailing)
            }

            GeometryReader { geometry in
                Capsule()
                    .fill(color)
                    .frame(width: max(2, geometry.size.width * fraction))
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Navigation helper

extension View {
    /// `navigationDestination` for an optional selection.
    func navigationDestination<Item, Content: View>(
        unwrapping item: Binding<Item?>,
        @ViewBuilder destination: @escaping (Item) -> Content
    ) -> some View {
        navigationDestination(isPresented: Binding(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )) {
            if let value = item.wrappedValue {
                destination(value)
            }
        }
    }
}
