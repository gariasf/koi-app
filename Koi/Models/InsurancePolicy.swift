import Foundation

/// A motor policy the user carries (owned / lease / finance). Subscriptions bundle
/// insurance into the plan, so there's no separate policy to add.
struct InsurancePolicy: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var carID: UUID
    var insurer: String
    var policyNumber: String
    var coverage: String          // "Comprehensive"
    var premium: Decimal?
    var premiumLastYear: Decimal? // cost trend
    var validFrom: Date?
    var validTo: Date?            // renewal date — feeds a renewal reminder
    var currency: String = "EUR"
}
