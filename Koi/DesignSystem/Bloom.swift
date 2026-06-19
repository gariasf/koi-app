import SwiftUI

/// The all-clear bloom: a single blurred sage disc that breathes very slowly behind the
/// hero headline. The one soft-light exception in the whole app — not a gradient fill.
/// Prototype: 280×280, blur ~44, koiBloom 7s ease-in-out, scale 1→1.09, opacity .62→.82.
struct Bloom: View {
    var color: Color = KoiColors.bloom
    @State private var breathing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 280, height: 280)
            .blur(radius: 44)
            .scaleEffect(breathing ? 1.09 : 1.0)
            .opacity(breathing ? 0.82 : 0.62)
            .onAppear {
                // duration 3.5s autoreversing == a full 7s breath cycle
                withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
