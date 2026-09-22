import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The lock-screen presence: a paper slip laid on the lock screen.
///
/// It wears the same ivory, ruling and reserved violet as the app — the whole point of a
/// Live Activity here is ambient pressure, and it only works if a glance reads as *this*
/// app rather than a generic notification.
///
/// Note there is no home screen or lock screen *widget* here, only a Live Activity. Widgets
/// read app data through App Groups, which a free Apple ID cannot use — see SPEC §9.2. The
/// Live Activity works because ActivityKit hands it the payload directly.
struct WUUTLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WUUTActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Theme.paper)
                .activitySystemActionForegroundColor(Theme.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(Formatters.window(from: context.state.slotStart, to: context.state.slotEnd))
                        .font(Theme.mono(11, .bold))
                        .foregroundStyle(.primary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.accountedPercent)%")
                        .font(Theme.mono(13, .bold))
                        .foregroundStyle(context.state.unloggedCount > 0 ? Theme.rule : .secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let label = context.state.blockedLabel, context.state.blockedUntil != nil {
                        Text(label)
                            .font(Theme.serif(13))
                            .lineLimit(1)
                    } else if context.state.unloggedCount > 0,
                              let slotID = context.state.actionableSlotID,
                              let last = context.state.lastEntry {
                        Button(intent: LogSameAsLastIntent(slotID: slotID)) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.turn.up.left").font(.caption2)
                                Text(last).font(Theme.serif(13)).lineLimit(1)
                            }
                        }
                        .buttonStyle(.bordered)
                    } else if context.state.unloggedCount > 0 {
                        UnloggedLine(count: context.state.unloggedCount, onDark: true)
                    } else if let last = context.state.lastEntry {
                        Text(last)
                            .font(Theme.serif(13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                // A struck-out mark rather than a clock glyph: the app's own shorthand.
                Rectangle()
                    .fill(context.state.unloggedCount > 0 ? Theme.rule : Color.secondary)
                    .frame(width: 11, height: 3)
            } compactTrailing: {
                if context.state.unloggedCount > 0 {
                    Text("\(context.state.unloggedCount)")
                        .font(Theme.mono(13, .bold))
                        .foregroundStyle(Theme.rule)
                } else {
                    CountdownText(state: context.state)
                        .font(Theme.mono(12))
                }
            } minimal: {
                if context.state.unloggedCount > 0 {
                    Text("\(context.state.unloggedCount)")
                        .font(Theme.mono(12, .bold))
                        .foregroundStyle(Theme.rule)
                } else {
                    Rectangle()
                        .fill(Color.secondary)
                        .frame(width: 10, height: 3)
                }
            }
        }
    }
}

private struct LockScreenView: View {

    let state: WUUTActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(Formatters.window(from: state.slotStart, to: state.slotEnd))
                    .font(Theme.mono(15, .bold))
                    .foregroundStyle(Theme.ink)

                Spacer()

                // How the day is going, not just when the next prompt lands.
                Text("\(state.accountedPercent)%")
                    .font(Theme.serif(17, .bold))
                    .foregroundStyle(state.unloggedCount > 0 ? Theme.violet : Theme.ink)

                CountdownText(state: state)
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.ink2)
            }

            Rule()
                .padding(.top, 8)

            if let until = state.blockedUntil, let label = state.blockedLabel {
                HStack(spacing: 6) {
                    Rectangle().fill(Theme.ink).frame(width: 3, height: 12)
                    Text("\(label) until \(Formatters.time(until))")
                        .font(Theme.serif(13))
                        .foregroundStyle(Theme.ink2)
                        .lineLimit(1)
                }
                .padding(.top, 9)
            } else if let last = state.lastEntry {
                Text(last)
                    .font(Theme.serif(13))
                    .foregroundStyle(Theme.ink2)
                    .lineLimit(1)
                    .padding(.top, 9)
            }

            if state.unloggedCount > 0 {
                // The number the whole lock-screen presence exists to show you, drawn as
                // the app draws missing time everywhere else.
                HStack(spacing: 8) {
                    Marginalia(
                        state.unloggedCount == 1 ? "1 slot unlogged" : "\(state.unloggedCount) slots unlogged",
                        color: Theme.card,
                        size: 9,
                        weight: .bold
                    )
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.violet)

                    Hatching(color: Theme.violet.opacity(0.35), spacing: 6)
                        .frame(height: 16)
                }
                .padding(.top, 10)

                // One tap, phone still locked. The lowest-friction path in the app.
                if let slotID = state.actionableSlotID, let last = state.lastEntry {
                    Button(intent: LogSameAsLastIntent(slotID: slotID)) {
                        HStack(spacing: 7) {
                            Image(systemName: "arrow.turn.up.left").font(.caption2)
                            Text(last)
                                .font(Theme.serif(13))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Theme.card)
                        .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 9)
                }
            } else {
                Marginalia("All accounted for", color: Theme.ink3, size: 9)
                    .padding(.top, 10)
            }
        }
        .padding(14)
    }
}

/// Counts down to the end of the slot.
///
/// `Text(timerInterval:)` is rendered by the system, so this keeps ticking with the app
/// shut. Without it the lock screen would freeze at whatever second the app last ran.
private struct CountdownText: View {

    let state: WUUTActivityAttributes.ContentState

    var body: some View {
        if state.slotEnd > state.slotStart, state.slotEnd > .now {
            Text(timerInterval: Date.now...state.slotEnd, countsDown: true, showsHours: false)
        } else {
            Text("due")
        }
    }
}

private struct UnloggedLine: View {
    let count: Int
    var onDark: Bool = false
    var body: some View {
        Text(count == 1 ? "1 slot unlogged" : "\(count) slots unlogged")
            .font(Theme.mono(11, .bold))
            .foregroundStyle(onDark ? Theme.rule : Theme.violet)
    }
}
