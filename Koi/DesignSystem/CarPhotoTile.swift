import SwiftUI
import UIKit

/// Decoded-image cache so a photo isn't re-decoded on every SwiftUI body pass (scroll,
/// transitions, sheet presentation). Keyed by car id + byte count, so editing the photo
/// (new byte count) misses the cache and re-decodes.
private let koiPhotoCache = NSCache<NSString, UIImage>()

/// A car's hero image — the user's photo if set, otherwise the per-car accent tint
/// (so an empty card still looks intentional).
struct CarPhotoTile: View {
    let car: Car
    var height: CGFloat

    var body: some View {
        Group {
            if let image = decodedImage {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    car.accent.tile
                    Image(systemName: "car.fill")          // tasteful per-car silhouette stand-in
                        .font(.system(size: min(48, height * 0.34)))
                        .foregroundStyle(car.accent.text.opacity(0.40))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }

    private var decodedImage: UIImage? {
        guard let data = car.photo else { return nil }
        let key = "\(car.id.uuidString)-\(data.count)" as NSString
        if let cached = koiPhotoCache.object(forKey: key) { return cached }
        guard let img = UIImage(data: data) else { return nil }
        koiPhotoCache.setObject(img, forKey: key)
        return img
    }
}
