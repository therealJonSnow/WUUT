import SwiftUI

/// One interval in the timeline.
///
/// Unlogged slots are drawn as visibly empty on purpose: the day should *look* incomplete
/// when it is. A locked slot says so, and says when it locked, rather than just going quiet.
struct SlotRow: View {

    let slot: Slot
    let now: Date
    let backfillWindowMinutes: Int
    let onTap: () -> Void
    let onSameAsLast: (() -> Void)?

    private var isInProgress: Bool {
        slot.isInProgress(at: now)
    }

    private var isFillable: Bool {
        slot.isFillable(at: now, backfillWindowMinutes: backfillWindowMinutes)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                accent

                VStack(alignment: .leading, spacing: 5) {
                    header
                    content
                }

                Spacer(minLength: 0)

                if slot.state == .pending, !isInProgress, isFillable, let onSameAsLast {
                    Button(action: onSameAsLast) {
                        Image(systemName: "arrow.turn.up.left")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Same as last")
                }
            }
            .padding(14)
            .frame(minHeight: Theme.slotRowMinHeight, alignment: .top)
            .background(background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .leading) {
                if isInProgress {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(slot.state == .unaccounted)
    }

    private var accent: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(accentColor)
            .frame(width: 5)
            .frame(minHeight: 30)
    }

    private var accentColor: Color {
        switch slot.state {
        case .logged:
            return slot.category?.color ?? Color.secondary.opacity(0.5)
        case .unaccounted:
            return Theme.unaccountedSolid
        case .pending:
            return isInProgress ? Color.accentColor : Color.orange.opacity(0.6)
        }
    }

    private var background: Color {
        slot.state == .unaccounted
            ? Color(.tertiarySystemGroupedBackground)
            : Color(.secondarySystemGroupedBackground)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(slot.displayWindow)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(slot.state == .unaccounted ? .tertiary : .secondary)

            // Stubs are the short first and last slots of a day. Worth showing, because a
            // 8-minute slot contributes 8 minutes to every metric, not 15.
            if slot.isStub {
                Text(Formatters.duration(minutes: slot.durationMinutes))
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
                    .foregroundStyle(.secondary)
            }

            if isInProgress {
                Text("now")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }

            if slot.source == .blockOut {
                Image(systemName: "pause.rectangle")
                    .font(.caption2)
                    .foregroundStyle(.indigo)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch slot.state {
        case .logged:
            VStack(alignment: .leading, spacing: 6) {
                Text(slot.text ?? "")
                    .font(.body)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if let category = slot.category {
                        CategoryChip(category: category)
                    } else {
                        Text("No category")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }

                    ForEach(slot.tagKeys, id: \.self) { key in
                        Text("#\(key)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

        case .pending:
            Text(isInProgress ? "In progress" : "Not logged yet")
                .font(.subheadline)
                .foregroundStyle(isInProgress ? Color.secondary : Color.orange)

        case .unaccounted:
            HStack(spacing: 5) {
                Image(systemName: "lock.fill").font(.caption2)
                Text("Unaccounted")
                    .font(.subheadline)
            }
            .foregroundStyle(.tertiary)
        }
    }
}

struct CategoryChip: View {

    let category: LogCategory

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.symbolName).font(.caption2)
            Text(category.name).font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(category.color.opacity(0.18), in: Capsule())
        .foregroundStyle(category.color)
    }
}
