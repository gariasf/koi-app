import SwiftUI
import UIKit

extension UIColor {
    /// Build a UIColor from a 0xRRGGBB literal.
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue:  CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    /// A dynamic color that resolves to `light` or `dark` per the active interface style.
    init(light: UInt, dark: UInt, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

/// Koi semantic color tokens — light + dark, ported verbatim from the design handoff.
/// Source of truth: `sure-tokens/colors_and_type.css` + README "Design tokens (exact)".
/// Koi layers a warm-paper canvas + sage/ochre accents over the Sure neutral system.
enum KoiColors {
    // MARK: Surfaces
    static let surface   = Color(light: 0xF4F2EC, dark: 0x0C0B0A) // warm paper / near-black
    static let container = Color(light: 0xFFFFFF, dark: 0x1A1917) // card
    static let fieldFill = Color(light: 0xFFFFFF, dark: 0x221F1C)
    static let insetFill = Color(light: 0xEDEBE4, dark: 0x221F1C) // inset / group fill
    static let sheet     = Color(light: 0xFFFFFF, dark: 0x151412) // Log sheet

    // MARK: Text
    static let textPrimary   = Color(light: 0x1A1916, dark: 0xF4F2EC)
    static let textSecondary = Color(light: 0x6B6862, dark: 0xA6A29A)
    static let textSubdued   = Color(light: 0x9A968D, dark: 0x6E6A62)
    static let textFaint     = Color(light: 0xA8A49B, dark: 0x6E6A62)

    // MARK: Lines & elevation (always 1px, alpha-on-black/white — never solid gray)
    static let hairline   = Color(light: 0x11100C, dark: 0xFFFFFF, lightAlpha: 0.07, darkAlpha: 0.08)
    static let border     = Color(light: 0x11100C, dark: 0xFFFFFF, lightAlpha: 0.10, darkAlpha: 0.10)
    static let ring       = Color(light: 0x11100C, dark: 0xFFFFFF, lightAlpha: 0.06, darkAlpha: 0.07)
    static let cardShadow = Color(light: 0x11100C, dark: 0x000000, lightAlpha: 0.05, darkAlpha: 0.40)

    // MARK: Sage — primary / all-clear / resting
    static let sage     = Color(light: 0x7C8B6F, dark: 0x9DB082)
    static let sageText = Color(light: 0x5A6B49, dark: 0xB6C79C)
    static let sageTint = Color(light: 0xE8EEDF, dark: 0x222A1E)

    // MARK: Ochre — gently coming up
    static let ochre     = Color(light: 0xC2893E, dark: 0xD6A964)
    static let ochreText = Color(light: 0x9A6722, dark: 0xD6A964)
    static let ochreTint = Color(light: 0xF6ECDC, dark: 0x2C2415)

    // MARK: Red — overdue / money-at-risk ONLY (never on a resting screen)
    static let red = Color(light: 0xEC2222, dark: 0xED4E4E)

    // MARK: Per-car accents (light values from the mocks; dark approximated)
    static let slateTile      = Color(light: 0xDCE2E8, dark: 0x232A30)
    static let slateText      = Color(light: 0x52606F, dark: 0xAEB9C5)
    static let terracottaTile = Color(light: 0xE7DAD2, dark: 0x2E2620)
    static let terracottaText = Color(light: 0x9A6450, dark: 0xCBA08C)

    // MARK: All-clear bloom — the single soft-light element (a "bloom", not a gradient)
    static let bloom = Color(light: 0xD8E2C7, dark: 0x3A472C)
}
