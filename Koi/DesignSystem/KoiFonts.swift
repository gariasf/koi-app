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

    // `relativeTo:` keeps the mock's exact sizes at the default text size while still
    // honouring Dynamic Type when the user scales text up/down.
    static func sans(_ size: CGFloat, _ w: Sans = .medium, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(w.rawValue, size: size, relativeTo: style)
    }
    static func mono(_ size: CGFloat, _ w: Mono = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(w.rawValue, size: size, relativeTo: style)
    }
}

/// A type-scale entry: font + letter-spacing + line-spacing + casing.
struct KoiTextStyle {
    var font: Font
    var tracking: CGFloat = 0
    var lineSpacing: CGFloat = 0
    var uppercase: Bool = false

    static let allClearHero = KoiTextStyle(font: KoiFont.sans(46, .medium, relativeTo: .largeTitle), tracking: -1.15)
    static let pageTitle    = KoiTextStyle(font: KoiFont.sans(28, .medium, relativeTo: .title), tracking: -0.42)
    static let carName      = KoiTextStyle(font: KoiFont.sans(24, .medium, relativeTo: .title2))
    static let glanceLine   = KoiTextStyle(font: KoiFont.sans(22, .medium, relativeTo: .title3), tracking: -0.26)
    static let listTitle    = KoiTextStyle(font: KoiFont.sans(16, .medium, relativeTo: .headline))
    static let body         = KoiTextStyle(font: KoiFont.sans(15, .regular, relativeTo: .body), lineSpacing: 3)
    static let meta         = KoiTextStyle(font: KoiFont.sans(12.5, .regular, relativeTo: .footnote))
    static let eyebrow      = KoiTextStyle(font: KoiFont.sans(11, .semibold, relativeTo: .caption2), tracking: 0.77, uppercase: true)
    static let tabLabel     = KoiTextStyle(font: KoiFont.sans(11, .medium, relativeTo: .caption2))
    static let wordmark     = KoiTextStyle(font: KoiFont.sans(28, .semibold, relativeTo: .title), tracking: 6.4)

    static let monoLg = KoiTextStyle(font: KoiFont.mono(17, .medium, relativeTo: .headline))
    static let monoMd = KoiTextStyle(font: KoiFont.mono(15, .medium, relativeTo: .body))
    static let monoSm = KoiTextStyle(font: KoiFont.mono(12.5, .regular, relativeTo: .footnote))
}

extension View {
    func koiStyle(_ s: KoiTextStyle) -> some View {
        self.font(s.font)
            .tracking(s.tracking)
            .lineSpacing(s.lineSpacing)
            .textCase(s.uppercase ? .uppercase : nil)
    }
}
