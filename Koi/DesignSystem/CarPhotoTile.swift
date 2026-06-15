import SwiftUI
import UIKit

/// A car's hero image — the user's photo if set, otherwise the per-car accent tint
/// (so an empty card still looks intentional).
struct CarPhotoTile: View {
    let car: Car
    var height: CGFloat

    var body: some View {
        Group {
            if let data = car.photo, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                car.accent.tile
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }
}
