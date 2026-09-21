import SwiftUI

/// Declares the next stretch of time in advance.
///
/// This is what keeps the app usable during a meeting, a drive or a film. It pre-fills the
/// slots it covers and stops them prompting — and because it is a prediction rather than a
/// claim, any slot it filled can still be overwritten afterwards. See SPEC §7.4.
struct BlockOutSheet: View {

    let now: Date

    @Environment(DayController.self) private var dayController: DayController
    @Environment(\.dismiss) private var dismiss

    @State private var minutes = 60
    @State private var customMinutes = 60
    @State private var usingCustom = false
    @State private var text = ""
    @State private var selectedCategory: LogCategory?

    @FocusState private var textFocused: Bool

    private let presets = [30, 45, 60, 90, 120]

    private var effectiveMinutes: Int {
        usingCustom ? max(15, customMinutes) : minutes
    }

    private var endsAt: Date {
        now.addingTimeInterval(TimeInterval(effectiveMinutes * 60))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What are you doing?", text: $text)
                        .focused($textFocused)
                } header: {
                    Text("Activity")
                } footer: {
                    Text("Every slot in the block is filled with this. You can change any of them afterwards.")
                }

                Section("Duration") {
                    Picker("Duration", selection: Binding(
                        get: { usingCustom ? -1 : minutes },
                        set: { value in
                            if value == -1 {
                                usingCustom = true
                            } else {
                                usingCustom = false
                                minutes = value
                            }
                        }
                    )) {
                        ForEach(presets, id: \.self) { preset in
                            Text(Formatters.duration(minutes: preset)).tag(preset)
                        }
                        Text("Custom").tag(-1)
                    }
                    .pickerStyle(.segmented)

                    if usingCustom {
                        Stepper(
                            "\(Formatters.duration(minutes: customMinutes))",
                            value: $customMinutes,
                            in: 15...480,
                            step: 15
                        )
                    }

                    LabeledContent("Ends at") {
                        Text(Formatters.time(endsAt))
                            .monospacedDigit()
                    }
                }

                Section("Category") {
                    CategoryPicker(
                        categories: dayController.activeCategories(),
                        selection: $selectedCategory
                    )
                }
            }
            .navigationTitle("Block out")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Block") {
                        dayController.createBlockOut(
                            minutes: effectiveMinutes,
                            text: text,
                            category: selectedCategory,
                            now: .now
                        )
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { textFocused = true }
        }
    }
}
