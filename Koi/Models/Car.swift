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
    var year: Int?               // model / build year ("make year")
    var plate: String?
    var odometerKm: Int?
    var nickname: String?
    var accent: CarAccent = .sage
    var photo: Data?
    // New fields are optional so existing saved cars keep decoding.
    var fuelType: FuelType?
    var registrationYear: Int?   // matriculation
    var purchaseYear: Int?       // when you got it (esp. second-hand)
    var powerHP: Int?            // DIN hp / CV
    var fiscalPowerCV: Double?   // potencia fiscal (CVF) — from the vehicle papers
    var torqueNm: Int?
    var purchasePrice: Decimal?
    var soldPrice: Decimal?      // set when the car leaves the garage (sell flow, later)
    var addedAt: Date = Date()

    var fuel: FuelType { fuelType ?? .petrol }
    /// Year you've had it from, for "owned since".
    var ownedSinceYear: Int? { purchaseYear ?? registrationYear ?? year }

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
