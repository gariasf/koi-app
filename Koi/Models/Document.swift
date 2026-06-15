import Foundation

enum DocumentKind: String, Codable, CaseIterable {
    case insurance, registration, inspection, other

    /// SF Symbols placeholders for Lucide shield / file-text / shield-check.
    var icon: String {
        switch self {
        case .insurance:    return "shield.lefthalf.filled"
        case .registration: return "doc.text"
        case .inspection:   return "checkmark.seal"
        case .other:        return "doc"
        }
    }
}

/// A document kept in a car's vault (Apple-Wallet-style keepsake).
struct Document: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var carID: UUID
    var kind: DocumentKind
    var title: String
    var subtitle: String?
}
