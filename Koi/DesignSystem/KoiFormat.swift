import Foundation

/// Number/money/date formatting. Numbers are heroes — keep them tabular and consistent.
enum KoiFormat {
    static func money(_ amount: Decimal, code: String = "EUR") -> String {
        amount.formatted(.currency(code: code).precision(.fractionLength(2)))
    }

    static func efficiency(_ l100: Double) -> String {
        String(format: "%.1f L/100km", l100)
    }

    static func liters(_ l: Double) -> String {
        String(format: "%.1f L", l)
    }

    static func km(_ km: Int) -> String {
        km.formatted(.number.grouping(.automatic)) + " km"
    }

    static func pricePerLiter(_ p: Double) -> String {
        String(format: "€%.3f /L", p)
    }

    /// "Tue, 10 Jun"
    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}
