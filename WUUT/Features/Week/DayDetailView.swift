import SwiftUI

/// A past day, read-only except where a slot is somehow still fillable.
struct DayDetailView: View {

    let day: Day

    @Environment(DayController.self) private var dayController: DayController

    @State private var now = Date.now
    @State private var editingSlot: Slot?

    private var backfillWindowMinutes: Int {
        AppSettings.shared.backfillWindowMinutes
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                header

                ForEach(day.orderedSlots.reversed(), id: \.id) { slot in
                    SlotRow(
                        slot: slot,
                        now: now,
                        backfillWindowMinutes: backfillWindowMinutes,
                        onTap: {
                            guard slot.state == .logged
                                || slot.isFillable(at: now, backfillWindowMinutes: backfillWindowMinutes)
                            else { return }
                            editingSlot = slot
                        },
                        onSameAsLast: nil
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Theme.paper)
        .logbookBars(Formatters.longDate(day.date))
        .sheet(unwrapping: $editingSlot) { slot in
            LogSheet(slot: slot, now: now)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Formatters.percent(day.accountedFraction))
                    .font(Theme.serif(34, .bold))
                    .foregroundStyle(Theme.ink)
                Marginalia("accounted for", color: Theme.ink2)
                Spacer()
            }

            HStack(spacing: 14) {
                HStack(spacing: 5) {
                    Rectangle().fill(Theme.ink).frame(width: 8, height: 8)
                    Text(Formatters.duration(minutes: day.loggedMinutes))
                        .font(Theme.mono(11, .bold))
                        .foregroundStyle(Theme.ink)
                    Marginalia("logged", color: Theme.ink2, size: 8)
                }
                if day.unaccountedMinutes > 0 {
                    HStack(spacing: 5) {
                        Rectangle().fill(Theme.violet).frame(width: 8, height: 8)
                        Text(Formatters.duration(minutes: day.unaccountedMinutes))
                            .font(Theme.mono(11, .bold))
                            .foregroundStyle(Theme.violet)
                        Marginalia("unaccounted", color: Theme.violet, size: 8)
                    }
                }
            }

            if let started = day.startedAt, let ended = day.endedAt {
                Text("\(Formatters.time(started)) – \(Formatters.time(ended))\(day.endedAutomatically ? " · ended automatically" : "")")
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .overlay(Rectangle().strokeBorder(Theme.rule, lineWidth: 1))
    }
}
