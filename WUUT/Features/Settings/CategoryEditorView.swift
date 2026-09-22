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
                            Image(systemName: category.symbolName)
                                .foregroundStyle(category.color)
                                .frame(width: 22)
                            Text(category.name)
                        }
                    }
                }
                .onMove(perform: move)
            } header: {
                Text("Categories")
            } footer: {
                Text("Drag to reorder. Order sets how they appear when you're logging, so put the ones you use most at the top.")
            }

            Section("Add") {
                HStack {
                    TextField("New category", text: $newName)
                    Button("Add") { add() }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if !archived.isEmpty {
                Section {
                    if showArchived {
                        ForEach(archived, id: \.id) { category in
                            HStack(spacing: 10) {
                                Image(systemName: category.symbolName)
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 22)
                                Text(category.name)
                                    .foregroundStyle(.secondary)
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
                    Text("Archived")
                } footer: {
                    Text("Archived categories stay attached to the entries that used them, so old weeks still read correctly.")
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar { EditButton() }
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
            Section("Name") {
                TextField("Name", text: $category.name)
            }

            Section("Colour") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 10)], spacing: 10) {
                    ForEach(Array(DefaultCategories.all.enumerated()), id: \.offset) { _, spec in
                        let isSelected = category.colorHex.caseInsensitiveCompare(spec.colorHex) == .orderedSame
                        Button {
                            category.colorHex = spec.colorHex
                            category.colorHexDark = spec.colorHexDark
                        } label: {
                            Circle()
                                .fill(Color(hex: spec.colorHex))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button {
                            category.symbolName = symbol
                        } label: {
                            Image(systemName: symbol)
                                .font(.body)
                                .frame(width: 38, height: 38)
                                .background(
                                    category.symbolName == symbol
                                        ? category.color.opacity(0.22)
                                        : Color.secondary.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 9)
                                )
                                .foregroundStyle(category.symbolName == symbol ? category.color : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Symbol")
            } footer: {
                Text("The symbol is how a category is identified in charts, not just its colour — so pick one you'll recognise.")
            }

            Section {
                Button("Archive this category", role: .destructive) {
                    category.isArchived = true
                    try? context.save()
                    dismiss()
                }
            } footer: {
                Text("Archiving hides it when logging but leaves every past entry intact.")
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? context.save() }
    }
}
