import SwiftUI
import UIKit
import CoreImage

/// Shared CoreImage context — creating one per call sets up a full render pipeline and is costly.
private let koiAverageColorContext = CIContext(options: [.workingColorSpace: NSNull()])

extension CarAccent {
    /// Derive a calm per-car accent from a photo's average colour — snapped into the
    /// brand's muted range (never a raw dominant colour).
    static func derive(from image: UIImage) -> CarAccent {
        guard let avg = image.averageColor else { return .slate }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        avg.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        if s < 0.12 { return .slate }            // desaturated / metallic → slate
        let hue = h * 360
        switch hue {
        case 60..<175:           return .sage        // greens
        case 30..<60:            return .ochre       // yellow / amber
        case 0..<30, 340...360:  return .terracotta  // reds / oranges
        default:                 return .slate       // blues / violets → slate
        }
    }
}

extension UIImage {
    /// Downscaled, re-encoded JPEG for storage. The UIImage round-trip strips EXIF/GPS
    /// metadata (privacy) and the resize keeps the on-disk blob small (a card never needs
    /// full-resolution bytes). Opaque JPEG — car photos don't need alpha.
    func preparedForStorage(maxDimension: CGFloat = 1024, quality: CGFloat = 0.8) -> Data? {
        let longest = max(size.width, size.height)
        let factor = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: (size.width * factor).rounded(), height: (size.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    /// 1×1 average colour via CoreImage.
    var averageColor: UIColor? {
        guard let cg = cgImage else { return nil }
        let input = CIImage(cgImage: cg)
        let extent = CIVector(cgRect: input.extent)
        guard let filter = CIFilter(name: "CIAreaAverage",
                                    parameters: [kCIInputImageKey: input, kCIInputExtentKey: extent]),
              let output = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        koiAverageColorContext.render(output, toBitmap: &bitmap, rowBytes: 4,
                                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                                      format: .RGBA8, colorSpace: nil)
        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255,
                       blue: CGFloat(bitmap[2]) / 255, alpha: 1)
    }
}
