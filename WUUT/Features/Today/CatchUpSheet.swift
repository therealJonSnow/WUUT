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
            .navigationTitle("Catch up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
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
                        .lineLimit(1...3)
                        .textFieldStyle(.roundedBorder)
                        .focused($textFocused)

                    if let previous = dayController.previousLoggedSlot(before: slot),
                       let previousText = previous.text {
                        Button {
                            dayController.copyPrevious(into: slot, source: .backfill, now: .now)
                            advance()
                        } label: {
                            Label("Same as previous — \(previousText)", systemImage: "arrow.turn.up.left")
                                .font(.subheadline)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
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
                Text(queue.count == 1 ? "1 left" : "\(queue.count) left")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text("Struck out at \(Formatters.time(slot.lockDate(backfillWindowMinutes: AppSettings.shared.backfillWindowMinutes)))")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
    }

    private func footer(for slot: Slot) -> some View {
        HStack(spacing: 12) {
            Button("Skip") {
                skipped.insert(slot.id)
                reset()
            }
            .buttonStyle(.bordered)

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
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(.bar)
    }

    private var allDone: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("All caught up")
                .font(.title3.weight(.semibold))
            Text("Nothing is waiting on you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
