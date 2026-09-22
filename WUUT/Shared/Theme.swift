import SwiftUI

extension Color {

    /// Six-digit hex, with or without a leading hash. Falls back to grey rather than
    /// trapping — a mistyped category colour should not be able to crash the app.
    init(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()

        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            self = .gray
            return
        }

        self.init(
            .sRGB,
            red: Double((value & 0xFF0000) >> 16) / 255,
            green: Double((value & 0x00FF00) >> 8) / 255,
            blue: Double(value & 0x0000FF) / 255,
            opacity: 1
        )
    }
}

/// The Logbook palette.
///
/// WUUT is a ledger, not a diary — its own spec says so — and it is drawn like one: soft
/// ivory paper, violet ruling in the manner of a Rhodia pad, ink for the writing.
///
/// **Violet is reserved.** It rules the page and it marks time you failed to account for,
/// and it is used for nothing else. No category may claim it; the seeded set excludes a
/// band of hues either side of it.
///
/// **Logged time is quiet, unaccounted time is loud.** That inversion is the point. Time
/// you recorded is finished and wants nothing from you, so it recedes; time you lost is
/// the first thing your eye lands on. The stock iOS treatment did the exact opposite,
/// rendering missing time as pale grey that politely got out of the way.
///
/// **Light appearance only, deliberately.** The app forces `.light` rather than shipping a
/// half-considered dark mode: paper at night is a different design, not an inverted one,
/// and it is better to do it properly later than badly now.
enum Theme {

    // MARK: Page
    static let paper      = Color(hex: "F7F1DE")   // the page
    static let card       = Color(hex: "FDF8EA")   // a leaf laid on it
    static let rule       = Color(hex: "C0AECC")   // ruled line, Rhodia violet
    static let ruleFaint  = Color(hex: "DFD5E5")

    // MARK: Ink
    static let ink        = Color(hex: "1E1A13")   // the writing
    static let ink2       = Color(hex: "6A6150")   // secondary
    static let ink3       = Color(hex: "9A9078")   // tertiary

    // MARK: Reserved
    /// Unaccounted time, and nothing else.
    static let violet     = Color(hex: "54268F")
    /// The plate an unaccounted row sits on.
    static let violetSoft = Color(hex: "E3D9EE")

    static let slotRowMinHeight: CGFloat = 54

    // MARK: Type
    //
    // Serif for what you wrote, mono for what the clock says. Times and durations are
    // data and line up in a column like a ledger; entries are prose and read like it.

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Diagonal hatching. Used to strike out time that was never accounted for, so a lost
/// quarter hour reads as a hole in the page rather than a differently coloured row.
struct Hatching: View {

    var color: Color
    var spacing: CGFloat = 7
    var lineWidth: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x = -size.height
            while x < size.width {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += spacing
            }
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Chrome
//
// Applied everywhere rather than per-screen, because the thing that made the app look
// generic was not any one view — it was twenty views each quietly accepting the defaults.

extension View {

    /// A `Form` or `List` on the page: hides the system grouped background so the paper
    /// shows through. Without this a Form insists on `systemGroupedBackground` whatever
    /// you put behind it.
    func logbookSurface() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
    }

    /// A row on a leaf of paper rather than a grey card.
    func logbookRow() -> some View {
        self.listRowBackground(Theme.card)
    }

    /// Navigation chrome in the page's own colours.
    func logbookBars(_ title: String = "") -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

/// A section heading in the ledger's voice: tracked small caps, not a system header.
struct SectionHeading: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Marginalia(text, color: Theme.ink2, weight: .bold)
            .padding(.top, 4)
    }
}

/// Explanatory text under a section. Serif, because it is prose.
struct SectionNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(Theme.serif(12))
            .foregroundStyle(Theme.ink3)
    }
}

/// The app's button: a flat ink block. Nothing in this app is a rounded blue capsule.
struct LedgerButtonStyle: ButtonStyle {
    var filled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.serif(16, .semibold))
            .foregroundStyle(filled ? Theme.card : Theme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(filled ? Theme.ink : Theme.card)
            .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: filled ? 0 : 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// A hairline in the ruling colour. A ledger is made of these.
struct Rule: View {
    var color: Color = Theme.rule
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
    }
}

/// Small-caps label — uppercased, tracked out, quiet. Used for category names, column
/// headings and the UNACCOUNTED mark.
struct Marginalia: View {
    let text: String
    var color: Color = Theme.ink2
    var size: CGFloat = 9
    var weight: Font.Weight = .regular

    var body: some View {
        Text(text.uppercased())
            .font(Theme.mono(size, weight))
            .tracking(1.1)
            .foregroundStyle(color)
    }
}
