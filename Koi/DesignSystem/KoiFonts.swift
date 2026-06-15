import SwiftUI

/// Geist faces, referenced by their PostScript names (bundled under Resources/Fonts).
/// Geist Sans for all UI/copy (workhorse weight 500); Geist Mono for every number that matters.
enum KoiFont {
    enum Sans: String {
        case light    = "Geist-Light"
        case regular  = "Geist-Regular"
        case medium   = "Geist-Medium"
        case semibold = "Geist-SemiBold"
        case bold     = "Geist-Bold"
    }
    enum Mono: String {
        case regular = "GeistMono-Regular"
        case medium  = "GeistMono-Medium"
        case bold    = "GeistMono-Bold"
    }

    // `fixedSize` keeps pixel-exact fidelity with the hifi mocks.
    // TODO: production should use `.custom(_, size:, relativeTo:)` for Dynamic Type.
    static func sans(_ size: CGFloat, _ w: Sans = .medium) -> Font { .custom(w.rawValue, fixedSize: size) }
    static func mono(_ size: CGFloat, _ w: Mono = .regular) -> Font { .custom(w.rawValue, fixedSize: size) }
}

/// A type-scale entry: font + letter-spacing + line-spacing + casing.
/// Values map to the README "Type scale (as used)" table.
struct KoiTextStyle {
    var font: Font
    var tracking: CGFloat = 0
    var lineSpacing: CGFloat = 0
    var uppercase: Bool = false

    static let allClearHero = KoiTextStyle(font: KoiFont.sans(46, .medium), tracking: -1.15)        // 46 / 500, -0.025em
    static let pageTitle    = KoiTextStyle(font: KoiFont.sans(28, .medium), tracking: -0.42)        // 28 / 500, -0.015em
    static let carName      = KoiTextStyle(font: KoiFont.sans(24, .medium))                          // 24 / 500
    static let glanceLine   = KoiTextStyle(font: KoiFont.sans(22, .medium), tracking: -0.26)        // 22 / 500, -0.012em
    static let listTitle    = KoiTextStyle(font: KoiFont.sans(16, .medium))                          // 15–17 / 500
    static let body         = KoiTextStyle(font: KoiFont.sans(15, .regular), lineSpacing: 3)         // 14–16 / 400
    static let meta         = KoiTextStyle(font: KoiFont.sans(12.5, .regular))                        // 12.5 / 400
    static let eyebrow      = KoiTextStyle(font: KoiFont.sans(11, .semibold), tracking: 0.77, uppercase: true) // 11 / 600, +0.07em
    static let tabLabel     = KoiTextStyle(font: KoiFont.sans(11, .medium))                           // 11 / 500
    static let wordmark     = KoiTextStyle(font: KoiFont.sans(28, .semibold), tracking: 6.4)         // 26–30 / 600, +0.22–0.24em

    // Geist Mono — numbers are heroes.
    static let monoLg = KoiTextStyle(font: KoiFont.mono(17, .medium))
    static let monoMd = KoiTextStyle(font: KoiFont.mono(15, .medium))
    static let monoSm = KoiTextStyle(font: KoiFont.mono(12.5, .regular))
}

extension View {
    func koiStyle(_ s: KoiTextStyle) -> some View {
        self.font(s.font)
            .tracking(s.tracking)
            .lineSpacing(s.lineSpacing)
            .textCase(s.uppercase ? .uppercase : nil)
    }
}
