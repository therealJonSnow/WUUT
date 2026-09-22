import SwiftUI

/// The catch-up queue: walks unfilled slots oldest first.
///
/// Built for clearing six slots in under a minute, because that is the realistic failure
/// mode — not one forgotten quarter hour but a whole afternoon that got away. Every control
/// is reachable with a thumb and nothing needs a category to be saved.
struct CatchUpSheet: View {

    let now: Date

    @Environment(DayController.self) private var dayController: DayController
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var selectedCategory: LogCategory?
    @State private var skipped: Set<UUID> = []

    @FocusState private var textFocused: Bool

    private var queue: [Slot] {
        dayController.fillableSlots(now: now).filter { !skipped.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let slot = queue.first {
                    content(for: slot)
                } else {
                    allDone
                }
            }
            .logbookBars("Catch up")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(Theme.serif(15))
                        .foregroundStyle(Theme.ink2)
                }
            }
        }
    }

    private func content(for slot: Slot) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(for: slot)

                    TextField("What were you up to?", text: $text, axis: .vertical)
                        .font(Theme.serif(16))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1...3)
                        .focused($textFocused)
                        .padding(12)
                        .background(Theme.card)
                        .overlay(Rectangle().strokeBorder(Theme.rule, lineWidth: 1))

                    if let previous = dayController.previousLoggedSlot(before: slot),
                       let previousText = previous.text {
                        Button {
                            dayController.copyPrevious(into: slot, source: .backfill, now: .now)
                            advance()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.turn.up.left").font(.caption)
                                Text(previousText)
                                    .font(Theme.serif(14))
                                    .lineLimit(1)
                                Spacer()
                            }
                            .foregroundStyle(Theme.ink2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .overlay(Rectangle().strokeBorder(Theme.rule, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                        CategoryPicker(
                            categories: dayController.activeCategories(),
                            selection: $selectedCategory
                        )
                    }
                }
                .padding(20)
            }

            footer(for: slot)
        }
        .background(Theme.paper)
        .onAppear { textFocused = true }
    }

    private func header(for slot: Slot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(slot.displayWindow)
                    .font(Theme.mono(19, .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Marginalia(queue.count == 1 ? "1 left" : "\(queue.count) left",
                           color: Theme.ink2, weight: .bold)
            }
            Text("Struck out at \(Formatters.time(slot.lockDate(backfillWindowMinutes: AppSettings.shared.backfillWindowMinutes)))")
                .font(Theme.mono(10))
                .foregroundStyle(Theme.ink3)
        }
    }

    private func footer(for slot: Slot) -> some View {
        HStack(spacing: 12) {
            Button("Skip") {
                skipped.insert(slot.id)
                reset()
            }
            .buttonStyle(LedgerButtonStyle(filled: false))
            .frame(width: 96)

            Button {
                let saved = dayController.log(
                    slot: slot,
                    text: text,
                    category: selectedCategory,
                    tagKeys: [],
                    source: .backfill,
                    now: .now
                )
                if saved { advance() }
            } label: {
                Text("Save and next")
            }
            .buttonStyle(LedgerButtonStyle())
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(Theme.card)
        .overlay(alignment: .top) { Rule(color: Theme.ink) }
    }

    private var allDone: some View {
        VStack(spacing: 14) {
            Text("All caught up")
                .font(Theme.serif(24, .semibold))
                .foregroundStyle(Theme.ink)
            Text("Nothing is waiting on you.")
                .font(Theme.serif(14))
                .foregroundStyle(Theme.ink2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper)
    }

    /// Keeps the category between entries — consecutive slots are usually the same sort of
    /// thing — but never the text, which would quietly duplicate an entry you didn't mean.
    private func advance() {
        text = ""
        if queue.isEmpty { dismiss() }
    }

    private func reset() {
        text = ""
        if queue.isEmpty { dismiss() }
    }
}
