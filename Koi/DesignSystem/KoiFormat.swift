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
        String(format: "€%.3f/L", p)
    }

    static func distance(_ km: Double) -> String {
        km < 1 ? "\(Int((km * 1000).rounded())) m away" : String(format: "%.1f km away", km)
    }

    /// "Tue, 10 Jun"
    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    // MARK: Number input parsing
    // One locale-safe path for every user-entered number. Handles both the custom keypad
    // (always ".") and the system decimalPad (which shows "," on Spanish/most-EU keyboards),
    // plus thousands grouping. Treats the LAST separator as the decimal point — so "12,50",
    // "12.50" and "1.234,56" all parse correctly, never as a 100× value.
    static func decimal(_ s: String) -> Decimal? {
        let n = normalizeNumber(s)
        return n.isEmpty ? nil : Decimal(string: n)
    }

    static func double(_ s: String) -> Double? {
        let n = normalizeNumber(s)
        return n.isEmpty ? nil : Double(n)
    }

    private static func normalizeNumber(_ s: String) -> String {
        let allowed = s.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" }
        guard let lastSep = allowed.lastIndex(where: { $0 == "." || $0 == "," }) else {
            return allowed   // no separator → plain integer digits
        }
        var out = ""
        for idx in allowed.indices {
            let ch = allowed[idx]
            if ch == "." || ch == "," {
                if idx == lastSep { out.append(".") }   // the decimal point; earlier ones are grouping → drop
            } else {
                out.append(ch)
            }
        }
        return out
    }
}
