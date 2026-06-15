import UIKit

/// Small, satisfying confirmations. Device-only (the simulator has no Taptic Engine).
enum Haptics {
    @MainActor static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    @MainActor static func tap() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
