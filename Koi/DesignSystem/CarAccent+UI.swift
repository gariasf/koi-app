import SwiftUI

/// Maps a per-car accent to its tile / text / pill colors, so each car is recognizable
/// by hue without reading a label.
extension CarAccent {
    var tile: Color {
        switch self {
        case .sage:       return KoiColors.sageTint
        case .slate:      return KoiColors.slateTile
        case .terracotta: return KoiColors.terracottaTile
        case .ochre:      return KoiColors.ochreTint
        }
    }
    var text: Color {
        switch self {
        case .sage:       return KoiColors.sageText
        case .slate:      return KoiColors.slateText
        case .terracotta: return KoiColors.terracottaText
        case .ochre:      return KoiColors.ochreText
        }
    }
    var pillBackground: Color { tile }
}
