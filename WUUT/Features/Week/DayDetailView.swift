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
            LazyVStack(spacing: 12) {
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
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Formatters.longDate(day.date))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(unwrapping: $editingSlot) { slot in
            LogSheet(slot: slot, now: now)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Formatters.percent(day.accountedFraction))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("accounted for")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 14) {
                Label(Formatters.duration(minutes: day.loggedMinutes), systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                if day.unaccountedMinutes > 0 {
                    Label(Formatters.duration(minutes: day.unaccountedMinutes), systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let started = day.startedAt, let ended = day.endedAt {
                Text("\(Formatters.time(started)) – \(Formatters.time(ended))\(day.endedAutomatically ? " · ended automatically" : "")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
