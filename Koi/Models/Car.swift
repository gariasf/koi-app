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
    var addedAt: Date = Date()

    /// Nickname wins; otherwise make + model; otherwise a gentle fallback.
    var displayName: String {
        if let nickname, !nickname.isEmpty { return nickname }
        let mm = [make, model].filter { !$0.isEmpty }.joined(separator: " ")
        return mm.isEmpty ? "Your car" : mm
    }

    /// "Volkswagen Golf · 2018" — shown under the display name when a nickname is used.
    var subtitle: String {
        var parts: [String] = []
        let mm = [make, model].filter { !$0.isEmpty }.joined(separator: " ")
        if !mm.isEmpty { parts.append(mm) }
        if let year { parts.append(String(year)) }
        return parts.joined(separator: " · ")
    }
}
