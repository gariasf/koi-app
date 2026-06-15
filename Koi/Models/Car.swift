import Foundation

/// Per-car accent, auto-derivable from the car photo later (P9). For now set on add.
enum CarAccent: String, Codable, CaseIterable {
    case sage, slate, terracotta, ochre
}

/// A vehicle. The user thinks in cars; the system threads them onto a `Plan`.
struct Car: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var make: String
    var model: String
    var year: Int?
    var plate: String?
    var odometerKm: Int?
    var nickname: String?
    var accent: CarAccent = .sage
    var photo: Data?
    var fuelRegionID: String?    // per-car region override for the fuel feed; nil = app default
    var addedAt: Date = Date()

    /// Nickname wins; otherwise make + model; otherwise a gentle fallback.
    var displayName: String {
        if let nickname, !nickname.isEmpty { return nickname }
        let mm = [make, model].filter { !$0.isEmpty }.joined(separator: " ")
        return mm.isEmpty ? "Your car" : mm
    }

    /// Secondary line under the display name. Avoids repeating the title: when there's a
    /// nickname the subtitle carries make/model (+year); otherwise just the year (or empty).
    var subtitle: String {
        let mm = [make, model].filter { !$0.isEmpty }.joined(separator: " ")
        if let nickname, !nickname.isEmpty {
            var parts: [String] = []
            if !mm.isEmpty { parts.append(mm) }
            if let year { parts.append(String(year)) }
            return parts.joined(separator: " · ")
        }
        return year.map(String.init) ?? ""
    }
}
