import Combine
import SwiftUI
import SwiftData

struct TodayView: View {

    @Environment(DayController.self) private var dayController: DayController
    @Environment(AppRouter.self) private var router: AppRouter

    @State private var now = Date.now
    @State private var lastReconciledBoundary: Date?
    @State private var loggingSlot: Slot?
    @State private var showCatchUp = false
    @State private var showBlockOut = false
    @State private var showEndDayConfirmation = false

    /// Ticks purely to keep the clock and countdowns honest. Reconciliation is *not* done on
    /// every tick — it rebuilds the notification window, which would be wasteful every 30
    /// seconds — only when the quarter-hour boundary rolls over.
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var backfillWindowMinutes: Int {
        AppSettings.shared.backfillWindowMinutes
    }

    var body: some View {
        NavigationStack {
            Group {
                if let day = dayController.activeDay {
                    activeDay(day)
                } else {
                    NotLoggingView(now: now) {
                        dayController.startDay()
                    }
                }
            }
            .navigationTitle(dayController.activeDay == nil ? "WUUT" : Formatters.longDate(now))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .onReceive(ticker) { tick in
            now = tick
            let boundary = QuarterHour.floor(tick, calendar: .current)
            if lastReconciledBoundary != boundary {
                lastReconciledBoundary = boundary
                dayController.reconcile(now: tick)
            }
        }
        .onAppear {
            now = .now
            lastReconciledBoundary = QuarterHour.floor(now, calendar: .current)
        }
        .onChange(of: router.dataChangedAt) { _, _ in
            now = .now
        }
        .onChange(of: router.pendingSlotID) { _, newValue in
            // Arrived here by tapping a notification.
            guard let slotID = newValue, let slot = dayController.slot(withID: slotID) else { return }
            router.pendingSlotID = nil
            loggingSlot = slot
        }
        .sheet(unwrapping: $loggingSlot) { slot in
            LogSheet(slot: slot, now: now)
        }
        .sheet(isPresented: $showCatchUp) {
            CatchUpSheet(now: now)
        }
        .sheet(isPresented: $showBlockOut) {
            BlockOutSheet(now: now)
        }
        .confirmationDialog(
            "End the day?",
            isPresented: $showEndDayConfirmation,
            titleVisibility: .visible
        ) {
            Button("End the day", role: .destructive) {
                dayController.endDay(at: .now)
            }
            Button("Keep logging", role: .cancel) {}
        } message: {
            Text("Prompts stop. Anything still inside its backfill window stays fillable.")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if dayController.activeDay != nil {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showBlockOut = true
                } label: {
                    Label("Block out", systemImage: "rectangle.stack.badge.plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("End day") {
                    showEndDayConfirmation = true
                }
            }
        }
    }

    // MARK: - Active day

    private func activeDay(_ day: Day) -> some View {
        let slots = day.orderedSlots
        let fillable = dayController.fillableSlots(now: now)
        let uncategorised = slots.filter { $0.state == .logged && $0.category == nil }

        return ScrollView {
            LazyVStack(spacing: 12) {
                DayHeaderView(day: day, now: now)

                if let block = dayController.currentBlockOut(now: now) {
                    BlockOutBanner(block: block, now: now) {
                        dayController.cancelBlockOut(block, now: .now)
                    }
                }

                if !fillable.isEmpty {
                    CatchUpBanner(
                        count: fillable.count,
                        earliestLock: fillable.first?.lockDate(backfillWindowMinutes: backfillWindowMinutes),
                        now: now
                    ) {
                        showCatchUp = true
                    }
                }

                if !uncategorised.isEmpty {
                    UncategorisedBanner(count: uncategorised.count) {
                        loggingSlot = uncategorised.first
                    }
                }

                // Newest first: the slot you owe an answer for should be the first thing you see.
                ForEach(slots.reversed(), id: \.id) { slot in
                    SlotRow(
                        slot: slot,
                        now: now,
                        backfillWindowMinutes: backfillWindowMinutes,
                        onTap: {
                            guard slot.isFillable(at: now, backfillWindowMinutes: backfillWindowMinutes)
                                || slot.state == .logged else { return }
                            loggingSlot = slot
                        },
                        onSameAsLast: dayController.previousLoggedSlot(before: slot) == nil ? nil : {
                            dayController.copyPrevious(into: slot, source: .app, now: .now)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Sheet presentation helper

extension View {
    /// Presents a sheet for an optional value, without relying on how the payload happens
    /// to satisfy `Identifiable`. Named distinctly so it cannot collide with SwiftUI's own
    /// `sheet(item:)` during overload resolution.
    func sheet<Item, Content: View>(
        unwrapping item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(isPresented: Binding(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )) {
            if let value = item.wrappedValue {
                content(value)
            }
        }
    }
}

// MARK: - Not logging

private struct NotLoggingView: View {

    let now: Date
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "sunrise.fill")
                .font(.system(size: 52))
                .foregroundStyle(.orange)

            VStack(spacing: 6) {
                Text("Not logging")
                    .font(.title2.weight(.semibold))
                Text("Start the day and WUUT will ask what you're up to every quarter hour.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onStart) {
                Text("Start the day")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)

            // The stub rule, stated where it matters: the first slot runs to the next
            // quarter hour, not for a full fifteen minutes.
            Text("First interval: \(Formatters.window(from: now, to: QuarterHour.next(after: now, calendar: .current)))")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .monospacedDigit()

            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Header

private struct DayHeaderView: View {

    let day: Day
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(Formatters.percent(day.accountedFraction))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("accounted for")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            AccountedBar(day: day)

            HStack(spacing: 14) {
                statistic("Logged", Formatters.duration(minutes: day.loggedMinutes), .green)
                if day.unaccountedMinutes > 0 {
                    statistic("Unaccounted", Formatters.duration(minutes: day.unaccountedMinutes), Theme.unaccountedSolid)
                }
                Spacer()
            }

            if let started = day.startedAt {
                Text("Started \(Formatters.time(started))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func statistic(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Logged / unaccounted / still open, in proportion. Duration-weighted, so the short stub
/// slots at either end of the day don't overstate themselves.
private struct AccountedBar: View {

    let day: Day

    var body: some View {
        GeometryReader { geometry in
            let total = max(1, day.elapsedMinutes)
            let width = geometry.size.width

            HStack(spacing: 1) {
                segment(.green, day.loggedMinutes, total, width)
                segment(Theme.unaccountedSolid, day.unaccountedMinutes, total, width)
                segment(Color.secondary.opacity(0.18), day.pendingMinutes, total, width)
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }

    private func segment(_ color: Color, _ minutes: Int, _ total: Int, _ width: CGFloat) -> some View {
        color.frame(width: max(0, width * CGFloat(minutes) / CGFloat(total)))
    }
}

// MARK: - Banners

private struct CatchUpBanner: View {

    let count: Int
    let earliestLock: Date?
    let now: Date
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(count == 1 ? "1 slot needs filling" : "\(count) slots need filling")
                        .font(.subheadline.weight(.semibold))
                    if let earliestLock {
                        Text("Oldest locks at \(Formatters.time(earliestLock))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct UncategorisedBanner: View {

    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "tag.slash")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(count == 1 ? "1 entry has no category" : "\(count) entries have no category")
                    .font(.subheadline)
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct BlockOutBanner: View {

    let block: BlockOut
    let now: Date
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pause.rectangle.fill")
                .font(.title2)
                .foregroundStyle(.indigo)

            VStack(alignment: .leading, spacing: 2) {
                Text(block.text)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("Blocked until \(Formatters.time(block.endAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Button("End", action: onCancel)
                .font(.subheadline.weight(.medium))
                .buttonStyle(.bordered)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
