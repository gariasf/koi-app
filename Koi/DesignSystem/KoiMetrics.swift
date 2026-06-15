import CoreGraphics

/// Corner radii (README: phone 46 · card 16–18 · field 10 · tile 11–13 · pill 999).
enum KoiRadius {
    static let phone: CGFloat     = 46
    static let card: CGFloat      = 18
    static let cardSmall: CGFloat = 16
    static let field: CGFloat     = 10
    static let tile: CGFloat      = 12
    static let pill: CGFloat      = 999
}

/// Spacing — 4px base; common gaps 8/10/12/14; card padding 14–18; page gutter 22–24.
enum KoiSpace {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let cardPad: CGFloat = 16
    static let gutter: CGFloat  = 22
}
