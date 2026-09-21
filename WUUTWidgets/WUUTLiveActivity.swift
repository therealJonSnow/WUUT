import ActivityKit
import SwiftUI
import WidgetKit

/// The lock-screen presence.
///
/// Note there is no home screen or lock screen *widget* here, only a Live Activity. Widgets
/// read app data through App Groups, which a free Apple ID cannot use — see SPEC §9.2. The
/// Live Activity works because ActivityKit hands it the payload directly.
struct WUUTLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WUUTActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.45))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(Formatters.time(context.state.slotEnd))
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    UnloggedBadge(count: context.state.unloggedCount)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let label = context.state.blockedLabel, context.state.blockedUntil != nil {
                        Text(label)
                            .font(.caption)
                            .lineLimit(1)
                    } else if let last = context.state.lastEntry {
                        Text(last)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Image(systemName: "clock.fill")
            } compactTrailing: {
                // The number the whole lock-screen presence exists to show you.
                if context.state.unloggedCount > 0 {
                    Text("\(context.state.unloggedCount)")
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                } else {
                    CountdownText(state: context.state)
                        .monospacedDigit()
                }
            } minimal: {
                if context.state.unloggedCount > 0 {
                    Text("\(context.state.unloggedCount)")
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: "clock.fill")
                }
            }
        }
    }
}

private struct LockScreenView: View {

    let state: WUUTActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(Formatters.window(from: state.slotStart, to: state.slotEnd))
                    .font(.headline)
                    .monospacedDigit()

                Spacer()

                CountdownText(state: state)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(.orange)
            }

            if let until = state.blockedUntil, let label = state.blockedLabel {
                HStack(spacing: 5) {
                    Image(systemName: "pause.rectangle.fill").font(.caption2)
                    Text("\(label) until \(Formatters.time(until))")
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            } else if let last = state.lastEntry {
                Text(last)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            UnloggedBadge(count: state.unloggedCount)
        }
        .padding(14)
    }
}

/// Counts down to the end of the slot.
///
/// `Text(timerInterval:)` is rendered by the system, so this keeps ticking with the app shut.
/// Without it the lock screen would freeze at whatever second the app last ran.
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

private struct UnloggedBadge: View {

    let count: Int

    var body: some View {
        if count == 0 {
            Label("All logged", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        } else {
            Label(
                count == 1 ? "1 slot unlogged" : "\(count) slots unlogged",
                systemImage: "exclamationmark.circle.fill"
            )
            .font(.caption2)
            .foregroundStyle(.orange)
        }
    }
}
