import SwiftUI
import SwiftData

/// Add, rename, recolour, reorder and archive categories.
///
/// Archive rather than delete, always: entries from months ago have to keep meaning
/// something, and deleting a category would strip the meaning out of every slot that used it.
struct CategoryEditorView: View {

    @Environment(DayController.self) private var dayController: DayController
    @Environment(\.modelContext) private var context

    @Query(sort: \LogCategory.sortOrder) private var categories: [LogCategory]

    @State private var newName = ""
    @State private var showArchived = false

    private var active: [LogCategory] {
        categories.filter { !$0.isArchived }
    }

    private var archived: [LogCategory] {
        categories.filter { $0.isArchived }
    }

    var body: some View {
        List {
            Section {
                ForEach(active, id: \.id) { category in
                    NavigationLink {
                        CategoryDetailView(category: category)
                    } label: {
                        HStack(spacing: 10) {
                            Rectangle()
                                .fill(category.color)
                                .frame(width: 10, height: 10)
                            Image(systemName: category.symbolName)
                                .font(.caption)
                                .foregroundStyle(Theme.ink2)
                                .frame(width: 18)
                            Text(category.name)
                                .font(Theme.serif(15))
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }
                .onMove(perform: move)
            } header: {
                SectionHeading("Categories")
            } footer: {
                SectionNote("Drag to reorder. Order sets how they appear when you're logging, so put the ones you use most at the top.")
            }
            .logbookRow()

            Section {
                HStack {
                    TextField("New category", text: $newName)
                        .font(Theme.serif(15))
                        .foregroundStyle(Theme.ink)
                    Button("Add") { add() }
                        .font(Theme.serif(15, .semibold))
                        .foregroundStyle(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.ink3 : Theme.ink)
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } header: {
                SectionHeading("Add")
            }
            .logbookRow()

            if !archived.isEmpty {
                Section {
                    if showArchived {
                        ForEach(archived, id: \.id) { category in
                            HStack(spacing: 10) {
                                Image(systemName: category.symbolName)
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 22)
                                Text(category.name)
                                    .font(Theme.serif(15))
                                    .foregroundStyle(Theme.ink3)
                                Spacer()
                                Button("Restore") {
                                    category.isArchived = false
                                    try? context.save()
                                }
                                .font(.footnote)
                            }
                        }
                    } else {
                        Button("Show \(archived.count) archived") { showArchived = true }
                    }
                } header: {
                    SectionHeading("Archived")
                } footer: {
                    SectionNote("Archived categories stay attached to the entries that used them, so old weeks still read correctly.")
                }
                .logbookRow()
            }
        }
        .logbookSurface()
        .logbookBars("Categories")
        .toolbar { EditButton().foregroundStyle(Theme.ink) }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = active
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, category) in reordered.enumerated() {
            category.sortOrder = index
        }
        try? context.save()
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let order = (categories.map(\.sortOrder).max() ?? -1) + 1
        let palette = DefaultCategories.colorPair(forSortOrder: order)
        let category = LogCategory(
            name: name,
            colorHex: palette.light,
            colorHexDark: palette.dark,
            symbolName: "circle.fill",
            sortOrder: order
        )
        context.insert(category)
        try? context.save()
        newName = ""
    }
}

private struct CategoryDetailView: View {

    @Bindable var category: LogCategory

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let symbols = [
        "laptopcomputer", "person.2.fill", "tray.full.fill", "iphone.gen3", "tv.fill",
        "book.fill", "figure.run", "dog.fill", "washer.fill", "bag.fill", "fork.knife",
        "person.3.fill", "tram.fill", "moon.zzz.fill", "circle.fill", "star.fill",
        "cart.fill", "music.note", "gamecontroller.fill", "paintbrush.fill",
        "hammer.fill", "leaf.fill", "airplane", "bicycle", "cup.and.saucer.fill"
    ]

    private let columns = [GridItem(.adaptive(minimum: 46), spacing: 10)]

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $category.name)
                    .font(Theme.serif(16))
                    .foregroundStyle(Theme.ink)
            } header: {
                SectionHeading("Name")
            }
            .logbookRow()

            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 10)], spacing: 10) {
                    ForEach(Array(DefaultCategories.all.enumerated()), id: \.offset) { _, spec in
                        let isSelected = category.colorHex.caseInsensitiveCompare(spec.colorHex) == .orderedSame
                        Button {
                            category.colorHex = spec.colorHex
                            category.colorHexDark = spec.colorHex
                        } label: {
                            Rectangle()
                                .fill(Color(hex: spec.colorHex))
                                .frame(width: 32, height: 32)
                                .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: isSelected ? 2.5 : 0))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                SectionHeading("Colour")
            }
            .logbookRow()

            Section {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button {
                            category.symbolName = symbol
                        } label: {
                            Image(systemName: symbol)
                                .font(.body)
                                .frame(width: 38, height: 38)
                                .background(category.symbolName == symbol ? Theme.paper : Theme.card)
                                .overlay(Rectangle().strokeBorder(
                                    category.symbolName == symbol ? Theme.ink : Theme.rule,
                                    lineWidth: category.symbolName == symbol ? 1.5 : 1))
                                .foregroundStyle(category.symbolName == symbol ? Theme.ink : Theme.ink2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                SectionHeading("Symbol")
            } footer: {
                SectionNote("The symbol is how a category is identified, not just its colour — fourteen colours cannot be told apart, so pick one you'll recognise.")
            }
            .logbookRow()

            Section {
                Button {
                    category.isArchived = true
                    try? context.save()
                    dismiss()
                } label: {
                    Text("Archive this category")
                        .font(Theme.serif(15))
                        .foregroundStyle(Theme.violet)
                }
            } footer: {
                SectionNote("Archiving hides it when logging but leaves every past entry intact.")
            }
            .logbookRow()
        }
        .logbookSurface()
        .logbookBars(category.name)
        .onDisappear { try? context.save() }
    }
}
