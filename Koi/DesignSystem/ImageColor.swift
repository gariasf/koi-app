import SwiftUI
import UIKit
import CoreImage

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
    /// 1×1 average colour via CoreImage.
    var averageColor: UIColor? {
        guard let cg = cgImage else { return nil }
        let input = CIImage(cgImage: cg)
        let extent = CIVector(cgRect: input.extent)
        guard let filter = CIFilter(name: "CIAreaAverage",
                                    parameters: [kCIInputImageKey: input, kCIInputExtentKey: extent]),
              let output = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(output, toBitmap: &bitmap, rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)
        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255,
                       blue: CGFloat(bitmap[2]) / 255, alpha: 1)
    }
}
