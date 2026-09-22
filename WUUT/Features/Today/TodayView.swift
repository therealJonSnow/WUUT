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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
            LazyVStack(spacing: 0) {
                Masthead(date: now)
                DayHeaderView(day: day, now: now)

                if let block = dayController.currentBlockOut(now: now) {
                    BlockOutBanner(block: block, now: now) {
                        dayController.cancelBlockOut(block, now: .now)
                    }
                    .padding(.top, 14)
                }

                if !fillable.isEmpty {
                    CatchUpBanner(
                        count: fillable.count,
                        earliestLock: fillable.first?.lockDate(backfillWindowMinutes: backfillWindowMinutes),
                        now: now
                    ) {
                        showCatchUp = true
                    }
                    .padding(.top, 14)
                }

                if !uncategorised.isEmpty {
                    UncategorisedBanner(count: uncategorised.count) {
                        loggingSlot = uncategorised.first
                    }
                    .padding(.top, 14)
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
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .background(Theme.paper)
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

// MARK: - Masthead

/// The head of the page. A ledger says what it is and what day it covers.
private struct Masthead: View {

    let date: Date

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Marginalia(Formatters.longDate(date), color: Theme.ink2)
                Spacer()
                Marginalia("W U U T", color: Theme.ink3, weight: .bold)
            }
            Rule(color: Theme.ink)
        }
        .padding(.top, 6)
    }
}

// MARK: - Not logging

private struct NotLoggingView: View {

    let now: Date
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Masthead(date: now)

            Spacer()

            Text("Nothing recorded")
                .font(Theme.serif(30, .semibold))
                .foregroundStyle(Theme.ink)

            Text("Start the day and WUUT will ask what you're up to every quarter hour.")
                .font(Theme.serif(15))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            // The stub rule, stated where it matters: the first slot runs to the next
            // quarter hour, not for a full fifteen minutes.
            HStack(spacing: 8) {
                Marginalia("First interval", color: Theme.ink3, size: 8)
                Text(Formatters.window(from: now, to: QuarterHour.next(after: now, calendar: .current)))
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.ink2)
            }
            .padding(.top, 22)

            Rule()
                .padding(.top, 8)

            Button(action: onStart) {
                HStack {
                    Text("Start the day")
                        .font(Theme.serif(17, .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(Theme.card)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(Theme.ink)
            }
            .buttonStyle(.plain)
            .padding(.top, 26)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper)
    }
}

// MARK: - Header

private struct DayHeaderView: View {

    let day: Day
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                // What went right, stated plainly.
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int((day.accountedFraction * 100).rounded()))")
                        .font(Theme.serif(52, .bold))
                        .foregroundStyle(Theme.ink)
                    Text("%")
                        .font(Theme.serif(24))
                        .foregroundStyle(Theme.ink2)
                    Text("accounted for")
                        .font(Theme.serif(13))
                        .foregroundStyle(Theme.ink2)
                        .padding(.leading, 6)
                }

                Spacer()

                // And what went missing, in the colour it is drawn in everywhere else.
                if day.unaccountedMinutes > 0 {
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(Formatters.duration(minutes: day.unaccountedMinutes))
                            .font(Theme.mono(15, .bold))
                            .foregroundStyle(Theme.violet)
                        Marginalia("Unaccounted", color: Theme.card, size: 8)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.violet)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.top, 18)

            AccountedBar(day: day)
                .padding(.top, 16)

            HStack(spacing: 10) {
                Text("\(Formatters.duration(minutes: day.loggedMinutes)) logged")
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.ink2)
                if let started = day.startedAt {
                    Text("· started \(Formatters.time(started))")
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.ink3)
                }
                Spacer()
            }
            .padding(.top, 8)

            Rule(color: Theme.ink)
                .padding(.top, 16)
        }
    }
}

/// Logged, lost and still open, in proportion. Duration-weighted, so the short stub slots
/// at either end of a day don't overstate themselves.
private struct AccountedBar: View {

    let day: Day

    var body: some View {
        GeometryReader { geometry in
            let total = max(1, day.elapsedMinutes)
            let width = geometry.size.width

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.ink)
                    .frame(width: width * CGFloat(day.loggedMinutes) / CGFloat(total))

                ZStack {
                    Rectangle().fill(Theme.violet)
                    Hatching(color: Theme.card.opacity(0.45), spacing: 5)
                }
                .frame(width: width * CGFloat(day.unaccountedMinutes) / CGFloat(total))

                Rectangle()
                    .strokeBorder(Theme.rule, lineWidth: 1)
                    .frame(width: width * CGFloat(day.pendingMinutes) / CGFloat(total))
            }
        }
        .frame(height: 18)
    }
}

// MARK: - Banners
//
// Flat and ruled rather than floating cards — this is a page, not a stack of surfaces.

private struct BannerShell<Content: View>: View {

    var accent: Color
    var onTap: (() -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shell = HStack(spacing: 0) {
            Rectangle().fill(accent).frame(width: 4)
            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            Spacer(minLength: 0)
        }
        .background(Theme.card)
        .overlay(Rectangle().strokeBorder(Theme.rule, lineWidth: 1))

        if let onTap {
            Button(action: onTap) { shell }.buttonStyle(.plain)
        } else {
            shell
        }
    }
}

private struct CatchUpBanner: View {

    let count: Int
    let earliestLock: Date?
    let now: Date
    let onTap: () -> Void

    var body: some View {
        BannerShell(accent: Theme.violet, onTap: onTap) {
            VStack(alignment: .leading, spacing: 3) {
                Text(count == 1 ? "1 slot needs filling" : "\(count) slots need filling")
                    .font(Theme.serif(15, .semibold))
                    .foregroundStyle(Theme.ink)
                if let earliestLock {
                    Text("Oldest is struck out at \(Formatters.time(earliestLock))")
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.ink2)
                }
            }
        }
    }
}

private struct UncategorisedBanner: View {

    let count: Int
    let onTap: () -> Void

    var body: some View {
        BannerShell(accent: Theme.ink3, onTap: onTap) {
            Text(count == 1 ? "1 entry has no category" : "\(count) entries have no category")
                .font(Theme.serif(14))
                .foregroundStyle(Theme.ink2)
        }
    }
}

private struct BlockOutBanner: View {

    let block: BlockOut
    let now: Date
    let onCancel: () -> Void

    var body: some View {
        BannerShell(accent: Theme.ink) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(block.text)
                        .font(Theme.serif(15, .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text("Blocked until \(Formatters.time(block.endAt))")
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.ink2)
                }
                Spacer()
                Button(action: onCancel) {
                    Marginalia("End", color: Theme.ink, weight: .bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
