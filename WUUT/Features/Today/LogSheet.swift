import SwiftUI

/// Records or edits one entry.
///
/// The screen you will see more than any other, so it is kept to one page with nothing
/// decorative on it. This is documentation, not a diary: a line or two about what you were
/// doing, a category, optional tags. Nothing here should invite a paragraph.
struct LogSheet: View {

    let slot: Slot
    let now: Date

    @Environment(DayController.self) private var dayController: DayController
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var selectedCategory: LogCategory?
    @State private var tagField = ""
    @State private var didLoad = false

    @FocusState private var textFocused: Bool

    private var categories: [LogCategory] { dayController.activeCategories() }
    private var suggestedTags: [Tag] { Array(dayController.allTags().prefix(8)) }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What were you up to?", text: $text, axis: .vertical)
                        .font(Theme.serif(16))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1...4)
                        .focused($textFocused)
                        .submitLabel(.done)

                    if let previous = dayController.previousLoggedSlot(before: slot),
                       let previousText = previous.text {
                        Button {
                            text = previousText
                            selectedCategory = previous.category
                            tagField = previous.tagKeys.joined(separator: ", ")
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.turn.up.left")
                                    .font(.caption)
                                    .foregroundStyle(Theme.ink3)
                                Text(previousText)
                                    .font(Theme.serif(13))
                                    .foregroundStyle(Theme.ink2)
                                    .lineLimit(1)
                            }
                        }
                    }
                } header: {
                    // The window this entry accounts for, in the ledger's mono.
                    HStack {
                        Text(slot.displayWindow)
                            .font(Theme.mono(13, .bold))
                            .foregroundStyle(Theme.ink)
                        if slot.isStub {
                            Marginalia(Formatters.duration(minutes: slot.durationMinutes),
                                       color: Theme.ink3, size: 8)
                        }
                        Spacer()
                    }
                    .textCase(nil)
                    .padding(.bottom, 2)
                } footer: {
                    footer
                }
                .logbookRow()

                Section {
                    CategoryPicker(categories: categories, selection: $selectedCategory)
                } header: {
                    SectionHeading("Category")
                }
                .logbookRow()

                Section {
                    TextField("Tags, comma separated", text: $tagField)
                        .font(Theme.mono(13))
                        .foregroundStyle(Theme.ink)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if !suggestedTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 7) {
                                ForEach(suggestedTags, id: \.id) { tag in
                                    Button {
                                        append(tag: tag.displayName)
                                    } label: {
                                        Text("#\(tag.displayName)")
                                            .font(Theme.mono(10))
                                            .foregroundStyle(Theme.ink2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .overlay(Rectangle().strokeBorder(Theme.rule, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    SectionHeading("Tags")
                }
                .logbookRow()

                if slot.state == .logged {
                    Section {
                        Button {
                            dayController.clear(slot: slot, now: .now)
                            dismiss()
                        } label: {
                            Text("Clear this entry")
                                .font(Theme.serif(15))
                                .foregroundStyle(Theme.violet)
                        }
                    }
                    .logbookRow()
                }
            }
            .logbookSurface()
            .logbookBars(slot.state == .logged ? "Edit entry" : "Log entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(Theme.serif(15))
                        .foregroundStyle(Theme.ink2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(Theme.serif(15, .semibold))
                        .foregroundStyle(canSave ? Theme.ink : Theme.ink3)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if slot.state == .unaccounted {
            SectionNote("This slot was struck out and counts as unaccounted time. It can't be edited.")
        } else if !slot.isInProgress(at: now) {
            let lock = slot.lockDate(backfillWindowMinutes: AppSettings.shared.backfillWindowMinutes)
            SectionNote("Struck out at \(Formatters.time(lock)).")
        } else {
            SectionNote("Still running. You'll be prompted at \(Formatters.time(slot.endAt)).")
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        text = slot.text ?? ""
        selectedCategory = slot.category
        tagField = slot.tagKeys.joined(separator: ", ")
        // Straight into the field: every second between opening this and typing is a
        // second you might decide not to bother.
        textFocused = slot.state != .logged
    }

    private func append(tag: String) {
        var tags = TextNormalizer.parseTagField(tagField)
        let key = TextNormalizer.tagKey(tag)
        guard !tags.contains(where: { TextNormalizer.tagKey($0) == key }) else { return }
        tags.append(tag)
        tagField = tags.joined(separator: ", ")
    }

    private func save() {
        let source: EntrySource = slot.isInProgress(at: now) ? .app : .backfill
        dayController.log(
            slot: slot,
            text: text,
            category: selectedCategory,
            tagKeys: TextNormalizer.parseTagField(tagField),
            source: slot.state == .logged ? slot.source : source,
            now: .now
        )
        dismiss()
    }
}

/// Category chips as ink marks in a grid. One tap, not a picker wheel's four.
///
/// Selection is shown by the mark filling and the label going to ink — never by colour
/// alone, since fourteen categories cannot be told apart that way.
struct CategoryPicker: View {

    let categories: [LogCategory]
    @Binding var selection: LogCategory?

    private let columns = [GridItem(.adaptive(minimum: 116), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(categories, id: \.id) { category in
                let isSelected = selection?.id == category.id
                Button {
                    selection = isSelected ? nil : category
                } label: {
                    HStack(spacing: 7) {
                        Rectangle()
                            .fill(category.color)
                            .frame(width: 9, height: 9)
                        Text(category.name.uppercased())
                            .font(Theme.mono(9, isSelected ? .bold : .regular))
                            .tracking(1.0)
                            .foregroundStyle(isSelected ? Theme.ink : Theme.ink2)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 9)
                    .background(isSelected ? Theme.paper : Color.clear)
                    .overlay(
                        Rectangle().strokeBorder(
                            isSelected ? Theme.ink : Theme.rule,
                            lineWidth: isSelected ? 1.5 : 1
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
