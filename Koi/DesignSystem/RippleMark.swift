import SwiftUI

/// The "koi" brand mark — a concentric pond ripple: three nested circles in sage.
/// Ported from the inline SVG in the prototype (viewBox 0 0 24 24:
/// circle r9.2 stroke 1.5, r5.1 stroke 1.5 @0.7, r1.9 filled).
struct RippleMark: View {
    var size: CGFloat
    var color: Color = KoiColors.sage

    var body: some View {
        let s = size / 24                  // prototype authored in a 24-unit viewBox
        ZStack {
            Circle()
                .stroke(color, lineWidth: 1.5 * s)
                .frame(width: 18.4 * s, height: 18.4 * s)   // r = 9.2
            Circle()
                .stroke(color.opacity(0.7), lineWidth: 1.5 * s)
                .frame(width: 10.2 * s, height: 10.2 * s)   // r = 5.1
            Circle()
                .fill(color)
                .frame(width: 3.8 * s, height: 3.8 * s)     // r = 1.9
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
