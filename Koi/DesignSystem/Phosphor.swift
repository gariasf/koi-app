import SwiftUI

/// Phosphor icon glyphs (regular weight) by private-use codepoint, bundled as `Phosphor.ttf`.
/// Koi's semantic icons; SF Symbols stay for system chrome (chevrons, back, etc.).
enum Ph {
    static let car      = "\u{e112}"
    static let fuel     = "\u{e768}"   // gas-pump
    static let shield   = "\u{e40c}"   // shield-check (insurance)
    static let seal     = "\u{e606}"   // seal-check (inspection)
    static let gauge    = "\u{e628}"
    static let swap     = "\u{e0a0}"   // arrows-left-right
    static let card     = "\u{e1d2}"   // credit-card (expense)
    static let wrench   = "\u{e5d4}"   // service
    static let note     = "\u{e34c}"   // note-pencil
    static let file     = "\u{e23a}"   // file-text (document)
    static let gear     = "\u{e270}"   // settings
    static let history  = "\u{e1a0}"   // clock-counter-clockwise (story)
    static let house    = "\u{e2c2}"   // owned
    static let calendar = "\u{e10a}"   // calendar-blank (plan)
    static let bell     = "\u{e0ce}"   // remind
    static let folder   = "\u{e24a}"   // docs
    static let sparkle  = "\u{e6a2}"   // joined
}

extension String {
    /// True when this is a single Phosphor glyph (a private-use scalar), not an SF Symbol name.
    var isPhosphorGlyph: Bool {
        let s = unicodeScalars
        guard s.count == 1, let v = s.first?.value else { return false }
        return (0xE000...0xF8FF).contains(v)
    }
}

/// Renders a semantic icon — a Phosphor glyph if given one, else an SF Symbol. Lets views pass
/// either and migrate gradually without risking tofu on the not-yet-migrated chrome.
struct KoiIcon: View {
    let name: String
    var size: CGFloat = 18
    var weight: Font.Weight = .regular

    var body: some View {
        if name.isPhosphorGlyph {
            Text(name).font(.custom("Phosphor", size: size * 1.16))
        } else {
            Image(systemName: name).font(.system(size: size, weight: weight))
        }
    }
}
