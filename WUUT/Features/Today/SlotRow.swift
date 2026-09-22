import SwiftUI

/// One line of the ledger.
///
/// Logged entries are quiet: the time in a mono gutter, the entry in serif, a small ink
/// mark for the category. Unaccounted slots are the loudest thing on the page — a violet
/// plate struck through with hatching. That inversion is the product's whole argument: time
/// you recorded is finished, time you lost is not.
struct SlotRow: View {

    let slot: Slot
    let now: Date
    let backfillWindowMinutes: Int
    let onTap: () -> Void
    let onSameAsLast: (() -> Void)?

    /// Width of the time column. Fixed so every row's times line up like a ledger.
    private let gutter: CGFloat = 92

    private var isInProgress: Bool { slot.isInProgress(at: now) }

    private var isFillable: Bool {
        slot.isFillable(at: now, backfillWindowMinutes: backfillWindowMinutes)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: Theme.slotRowMinHeight, alignment: .top)
            }
            .buttonStyle(.plain)
            .disabled(slot.state == .unaccounted)

            Rule(color: slot.state == .unaccounted ? Theme.violet : Theme.rule)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch slot.state {
        case .unaccounted:
            unaccountedRow
        case .pending:
            if isInProgress { inProgressRow } else { pendingRow }
        case .logged:
            loggedRow
        }
    }

    // MARK: - Struck out

    private var unaccountedRow: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Theme.violet)
                .frame(width: 4)

            HStack(alignment: .center, spacing: 0) {
                Text(slot.displayWindow)
                    .font(Theme.mono(12, .bold))
                    .foregroundStyle(Theme.violet)
                    .frame(width: gutter - 14, alignment: .leading)

                Marginalia("Unaccounted", color: Theme.violet, size: 11, weight: .bold)

                // The void, hatched. Reads as a hole in the page rather than a tinted row.
                Hatching(color: Theme.violet.opacity(0.38))
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
                    .padding(.leading, 12)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 48)
        .background(Theme.violetSoft)
    }

    // MARK: - Written

    private var loggedRow: some View {
        HStack(alignment: .top, spacing: 0) {
            timeColumn(color: Theme.ink2)

            VStack(alignment: .leading, spacing: 7) {
                Text(slot.text ?? "")
                    .font(Theme.serif(15))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    if let category = slot.category {
                        Rectangle()
                            .fill(category.color)
                            .frame(width: 8, height: 8)
                        Marginalia(category.name)
                    } else {
                        Rectangle()
                            .strokeBorder(Theme.violet, lineWidth: 1)
                            .frame(width: 8, height: 8)
                        Marginalia("No category", color: Theme.violet)
                    }

                    ForEach(slot.tagKeys, id: \.self) { key in
                        Text("#\(key)")
                            .font(Theme.mono(9))
                            .foregroundStyle(Theme.ink3)
                    }
                }
            }

            Spacer(minLength: 0)

            if slot.source == .blockOut {
                Image(systemName: "pause.rectangle")
                    .font(.caption2)
                    .foregroundStyle(Theme.ink3)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 11)
    }

    // MARK: - Open

    private var pendingRow: some View {
        HStack(alignment: .top, spacing: 0) {
            timeColumn(color: Theme.ink2)

            Text("Not logged yet")
                .font(Theme.serif(15))
                .foregroundStyle(Theme.ink3)

            Spacer(minLength: 0)

            if isFillable, let onSameAsLast {
                Button(action: onSameAsLast) {
                    Marginalia("Same as last", color: Theme.ink2, weight: .bold)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .overlay(Rectangle().strokeBorder(Theme.rule, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 11)
    }

    private var inProgressRow: some View {
        HStack(alignment: .top, spacing: 0) {
            timeColumn(color: Theme.ink)

            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(Theme.ink)
                    .frame(width: 3, height: 17)

                VStack(alignment: .leading, spacing: 5) {
                    Text("In progress")
                        .font(Theme.serif(15))
                        .foregroundStyle(Theme.ink2)
                    Marginalia("Prompt at \(Formatters.time(slot.endAt))", color: Theme.ink3, size: 8)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }

    // MARK: - Shared

    private func timeColumn(color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(slot.displayWindow)
                .font(Theme.mono(12))
                .foregroundStyle(color)

            // The short first or last slot of a day. Worth showing: an 8-minute slot
            // contributes 8 minutes to every figure in the app, not 15.
            if slot.isStub {
                Text(Formatters.duration(minutes: slot.durationMinutes))
                    .font(Theme.mono(9, .bold))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .frame(width: gutter, alignment: .leading)
    }
}

extension Marginalia {
    init(_ text: String, color: Color = Theme.ink2, size: CGFloat = 9, weight: Font.Weight = .regular) {
        self.init(text: text, color: color, size: size, weight: weight)
    }
}

/// The category mark used outside the ledger — in sheets and pickers, where there is room
/// for the name to sit beside the colour rather than under it.
struct CategoryChip: View {

    let category: LogCategory

    var body: some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(category.color)
                .frame(width: 8, height: 8)
            Marginalia(category.name, color: Theme.ink2)
        }
    }
}
