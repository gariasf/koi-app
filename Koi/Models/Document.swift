import Foundation

enum DocumentKind: String, Codable, CaseIterable {
    case insurance, registration, inspection, other

    var label: String {
        switch self {
        case .insurance:    return "Insurance"
        case .registration: return "Registration"
        case .inspection:   return "Inspection"
        case .other:        return "Other"
        }
    }

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
    var imageData: Data?   // a photo/scan of the document (downscaled + metadata-stripped on import)
    var pdfData: Data?     // a PDF of the document, stored as-is (optional so older docs still decode)
    var fileName: String?  // original PDF filename, for display

    /// Whether anything is attached (image or PDF) — drives the tappable/openable state.
    var hasFile: Bool { imageData != nil || pdfData != nil }
    var isPDF: Bool { pdfData != nil }
}
