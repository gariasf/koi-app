import Foundation

/// Per-car accent, auto-derivable from the car photo later (P9). For now set on add.
enum CarAccent: String, Codable, CaseIterable {
    case sage, slate, terracotta, ochre
}

/// A dated odometer reading. The trail that keeps the monthly-mileage gauge honest even for
/// cars that are never fuel-logged (e.g. all-inclusive subscriptions).
struct OdometerReading: Codable, Hashable {
    var date: Date
    var km: Int
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
    var purchasePrice: Decimal?
    var soldPrice: Decimal?      // set when the car leaves the garage (sell flow, later)
    var vin: String?             // chassis / vehicle identification number
    var tankCapacityL: Double?   // fuel tank size (L) — powers "Fill to full" + a sanity cap when logging
    var addedAt: Date = Date()
    var initialOdometerKm: Int?              // reading when you got the car — mileage-cap baseline + total since
    var odometerLog: [OdometerReading]?      // dated manual readings (optional so pre-existing saves decode)
    var archivedAt: Date?                    // set when shelved — hidden from the garage + not counted, but restorable
    /// Bumped on every edit. Folded into `==`/`hash` (below) so SwiftUI's value-diffing redraws
    /// subviews that store a `Car` by value (e.g. ResidentCard) when only the photo or another
    /// field changes — identity stays cheap (id + an Int), no photo-blob compare. Optional so
    /// pre-existing saves decode.
    var revision: Int?

    var fuel: FuelType { fuelType ?? .petrol }
    /// Shelved: kept on file (and restorable) but out of the active garage and every tally.
    var isArchived: Bool { archivedAt != nil }
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

    // Identity is the id plus a cheap `revision` stamp — never the full `photo` Data blob (the
    // synthesized conformance would hash/compare it on every NavigationLink value and
    // `.onChange(of: cars)`). Including `revision` keeps comparisons cheap (two scalars) while
    // letting SwiftUI's value-diffing notice in-place edits (photo, name, odometer…) that keep the
    // same id, so cards/tiles redraw immediately instead of staying stale until an app restart.
    static func == (lhs: Car, rhs: Car) -> Bool {
        lhs.id == rhs.id && (lhs.revision ?? 0) == (rhs.revision ?? 0)
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(revision ?? 0)
    }
}
