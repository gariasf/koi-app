import SwiftUI

/// The signature Koi/Sure elevation: a tiny soft shadow paired with a 1px alpha-on-black ring.
/// Depth comes from shadow + hairline, never gradients.
struct KoiCardModifier: ViewModifier {
    var cornerRadius: CGFloat = KoiRadius.card
    var padding: CGFloat = KoiSpace.cardPad
    var fill: Color = KoiColors.container

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(KoiColors.ring, lineWidth: 1)
            )
            .shadow(color: KoiColors.cardShadow, radius: 2, x: 0, y: 1)
    }
}

extension View {
    func koiCard(cornerRadius: CGFloat = KoiRadius.card,
                 padding: CGFloat = KoiSpace.cardPad,
                 fill: Color = KoiColors.container) -> some View {
        modifier(KoiCardModifier(cornerRadius: cornerRadius, padding: padding, fill: fill))
    }
}
