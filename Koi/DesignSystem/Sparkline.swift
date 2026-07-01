import SwiftUI

/// A calm bar sparkline — a value series drawn as slim bars, the latest highlighted. Heights
/// normalise to the series max so the shape reads regardless of scale. Used small in the car card
/// and larger on the insights screen.
struct BarSparkline: View {
    let values: [Double]
    var highlightLast = true
    var barColor: Color = KoiColors.textSubdued
    var highlightColor: Color = KoiColors.sage
    var height: CGFloat = 26
    var barWidth: CGFloat = 4
    var spacing: CGFloat = 3

    var body: some View {
        let maxV = max(values.max() ?? 1, 0.0001)
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                Capsule()
                    .fill(highlightLast && i == values.count - 1 ? highlightColor : barColor.opacity(0.45))
                    .frame(width: barWidth, height: max(3, CGFloat(v / maxV) * height))
            }
        }
        .frame(height: height, alignment: .bottom)
    }
}

/// A calm line sparkline — the series as a polyline with a soft area fill underneath. Self-scales
/// to its own min/max so the trend shape is always visible.
struct LineSparkline: View {
    let values: [Double]
    var color: Color = KoiColors.sage
    var fill = true
    var lineWidth: CGFloat = 1.7

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                if fill, pts.count > 1 {
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: geo.size.height))
                        pts.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [color.opacity(0.16), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                }
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: first); pts.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        let span = max(hi - lo, 0.0001)
        let inset = lineWidth                                  // keep the stroke off the very edge
        let usable = max(size.height - inset * 2, 1)
        let stepX = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            CGPoint(x: CGFloat(i) * stepX, y: inset + usable - CGFloat((v - lo) / span) * usable)
        }
    }
}

/// A horizontal segmented bar — the cost breakdown (capital / fuel / service / other), each segment
/// sized to its share. Zero-value segments collapse.
struct SegmentBar: View {
    struct Segment: Identifiable { let id = UUID(); let value: Double; let color: Color; let label: String }
    let segments: [Segment]
    var height: CGFloat = 12

    var body: some View {
        let total = max(segments.reduce(0) { $0 + $1.value }, 0.0001)
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(segments.filter { $0.value > 0 }) { s in
                    s.color.frame(width: max(0, (geo.size.width - 6) * CGFloat(s.value / total)))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
    }
}
