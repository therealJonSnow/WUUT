import SwiftUI

/// Records or edits one entry.
///
/// Kept deliberately small. This is documentation, not a diary: a line or two about what you
/// were doing, a category, optional tags. Nothing here should invite you to write a paragraph.
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

    private var categories: [LogCategory] {
        dayController.activeCategories()
    }

    private var suggestedTags: [Tag] {
        Array(dayController.allTags().prefix(8))
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "What were you up to?",
                        text: $text,
                        axis: .vertical
                    )
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
                            Label("Same as last — \(previousText)", systemImage: "arrow.turn.up.left")
                                .font(.footnote)
                                .lineLimit(1)
                        }
                    }
                } header: {
                    Text(slot.displayWindow)
                } footer: {
                    footer
                }

                Section("Category") {
                    CategoryPicker(
                        categories: categories,
                        selection: $selectedCategory
                    )
                }

                Section {
                    TextField("Tags, comma separated", text: $tagField)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if !suggestedTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(suggestedTags, id: \.id) { tag in
                                    Button {
                                        append(tag: tag.displayName)
                                    } label: {
                                        Text("#\(tag.displayName)")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.secondary.opacity(0.15), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    Text("Tags")
                }

                if slot.state == .logged {
                    Section {
                        Button("Clear this entry", role: .destructive) {
                            dayController.clear(slot: slot, now: .now)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(slot.state == .logged ? "Edit entry" : "Log entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if slot.state == .unaccounted {
            Text("This slot locked and counts as unaccounted time. It can't be edited.")
        } else if !slot.isInProgress(at: now) {
            let lock = slot.lockDate(backfillWindowMinutes: AppSettings.shared.backfillWindowMinutes)
            Text("Locks at \(Formatters.time(lock)).")
        } else {
            Text("Still running. You'll be prompted at \(Formatters.time(slot.endAt)).")
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        text = slot.text ?? ""
        selectedCategory = slot.category
        tagField = slot.tagKeys.joined(separator: ", ")
        // Straight into the field: every second between opening this and typing is a second
        // you might decide not to bother.
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

/// Category chips in a wrapping grid. A picker wheel would be four taps; this is one.
struct CategoryPicker: View {

    let categories: [LogCategory]
    @Binding var selection: LogCategory?

    private let columns = [GridItem(.adaptive(minimum: 108), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(categories, id: \.id) { category in
                let isSelected = selection?.id == category.id
                Button {
                    selection = isSelected ? nil : category
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: category.symbolName).font(.caption)
                        Text(category.name)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                    .background(
                        isSelected ? category.color : category.color.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 9)
                    )
                    .foregroundStyle(isSelected ? Color.white : category.color)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
