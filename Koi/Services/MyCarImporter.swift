import Foundation
import ImageIO

/// Parses a MyCar "CSV Export v2.0" file into Koi models. Pure + side-effect-free — it builds
/// cars (all owned, since MyCar has no plan concept) with their fuel/service/expense/note history;
/// `Garage.importMyCar` is what actually commits the result.
///
/// MyCar's CSV is multi-section: `## Section` then a column-header row then data rows, blank-separated.
/// Fields are comma-separated with quoted strings (which may contain commas), so it needs real CSV
/// field parsing, not a naive split.
enum MyCarImporter {

    struct Result {
        var cars: [Car] = []
        var plans: [Plan] = []
        var fuels: [FuelLog] = []
        var entries: [LogEntry] = []
        var summaries: [CarSummary] = []
        var isEmpty: Bool { cars.isEmpty }
        /// Koi car id → MyCar vehicle id, so a `.dat` backup can attach photos by id afterwards.
        var vehicleIDByCarID: [UUID: String] = [:]

        /// Keep only the chosen cars and everything attached to them.
        func selecting(_ ids: Set<UUID>) -> Result {
            var r = Result()
            r.cars = cars.filter { ids.contains($0.id) }
            r.plans = plans.filter { plan in plan.carIDs.contains { ids.contains($0) } }
            r.fuels = fuels.filter { ids.contains($0.carID) }
            r.entries = entries.filter { ids.contains($0.carID) }
            r.summaries = summaries.filter { ids.contains($0.id) }
            return r
        }

        /// Attach downscaled photos (keyed by car id) onto the cars and their summaries.
        func withPhotos(_ map: [UUID: Data]) -> Result {
            guard !map.isEmpty else { return self }
            var r = self
            r.cars = cars.map { var c = $0; if let p = map[c.id] { c.photo = p }; return c }
            r.summaries = summaries.map { var s = $0; if let p = map[s.id] { s.photo = p }; return s }
            return r
        }
    }

    struct CarSummary: Identifiable {
        let id: UUID
        let name: String
        let detail: String     // "Opel Astra GTC H"
        let fuels: Int
        let services: Int
        let expenses: Int
        let notes: Int
        var photo: Data?       // filled when a .dat backup is added
    }

    // MARK: parse
    static func parse(_ csv: String) -> Result {
        var result = Result()
        let sections = splitSections(csv)

        var indexByVID: [String: Int] = [:]   // MyCar vehicleId → index into result.cars
        var unitByVID: [String: String] = [:]  // odometerUnit ("0" = miles, else km)
        var volByVID: [String: String] = [:]   // fuelUnit ("1" = US gal, "2" = imp gal, else litres)
        var maxOdo: [String: Int] = [:]
        var readingsByVID: [String: [OdometerReading]] = [:]   // dated odometer trail, from every section
        var soldByVID: [String: Date] = [:]    // selling date → archive the car
        var counts: [String: (f: Int, s: Int, e: Int, n: Int)] = [:]

        // Fold a dated odometer reading into both the running max and the per-car trail.
        func record(_ vid: String, _ km: Int?, _ date: Date?) {
            guard let km, km > 0 else { return }
            maxOdo[vid] = max(maxOdo[vid] ?? 0, km)
            if let date { readingsByVID[vid, default: []].append(OdometerReading(date: date, km: km)) }
        }

        // Vehicles → owned cars
        if let v = sections["Vehicles"] {
            let accents: [CarAccent] = [.sage, .slate, .terracotta, .ochre]
            for row in v.rows {
                let vid = field(row, v.headers, "id")
                guard !vid.isEmpty else { continue }
                var car = Car(make: field(row, v.headers, "make"), model: field(row, v.headers, "model"))
                let name = field(row, v.headers, "name")
                if !name.isEmpty { car.nickname = name }
                car.year = int(field(row, v.headers, "year"))
                car.fuelType = fuelType(field(row, v.headers, "fuelType"))
                let unit = field(row, v.headers, "odometerUnit")
                unitByVID[vid] = unit
                let vol = field(row, v.headers, "fuelUnit")
                volByVID[vid] = vol
                car.tankCapacityL = volumeLiters(field(row, v.headers, "tankCapacity"), unit: vol).flatMap { $0 > 0 ? $0 : nil }
                car.purchasePrice = decimal(field(row, v.headers, "purchasePrice")).flatMap { $0 > 0 ? $0 : nil }
                car.soldPrice = decimal(field(row, v.headers, "sellingPrice")).flatMap { $0 > 0 ? $0 : nil }
                car.initialOdometerKm = odometerKm(field(row, v.headers, "purchaseOdometer"), unit: unit)
                car.addedAt = date(field(row, v.headers, "purchaseDateTime")) ?? Date()
                record(vid, car.initialOdometerKm, car.addedAt)
                // A car with a selling date has left — archive it (drops out of the garage and stops
                // generating reminders) while keeping its history. Record the sale odometer too.
                if let sold = date(field(row, v.headers, "sellingDateTime")) {
                    soldByVID[vid] = sold
                    record(vid, odometerKm(field(row, v.headers, "sellingOdometer"), unit: unit), sold)
                }
                car.accent = accents[result.cars.count % accents.count]
                result.cars.append(car)
                result.plans.append(Plan(kind: .owned, carIDs: [car.id]))
                indexByVID[vid] = result.cars.count - 1
                result.vehicleIDByCarID[car.id] = vid
                counts[vid] = (0, 0, 0, 0)
                // The car's free-text notes have no Car field — keep them as a dated note entry.
                let vehicleNotes = field(row, v.headers, "notes")
                if !vehicleNotes.isEmpty {
                    result.entries.append(LogEntry(carID: car.id, kind: .note, date: car.addedAt,
                                                   amount: nil, note: vehicleNotes, odometerKm: nil))
                    counts[vid]?.n += 1
                }
            }
        }

        func carID(_ vid: String) -> UUID? { indexByVID[vid].map { result.cars[$0].id } }
        func note(_ rows: [String], _ headers: [String: Int], typeColumn: String) -> String {
            let type = field(rows, headers, typeColumn)
            let notes = field(rows, headers, "Notes")
            let location = field(rows, headers, "Location")   // e.g. the workshop a service was done at
            return [type, notes, location].filter { !$0.isEmpty }.joined(separator: " · ")
        }

        // Refuels → fuel logs
        if let r = sections["Refuels"] {
            for row in r.rows {
                let vid = field(row, r.headers, "vehicleId")
                guard let cid = carID(vid) else { continue }
                let total = decimal(field(row, r.headers, "Total")) ?? 0
                // Convert the fill volume to litres (MyCar may store US/imperial gallons), so every
                // derived L/100km is correct — odometer is already unit-converted, volume must match.
                let liters = volumeLiters(field(row, r.headers, "Amount"), unit: volByVID[vid]) ?? 0
                guard total > 0 || liters > 0 else { continue }       // skip empty refuels
                let odo = odometerKm(field(row, r.headers, "Odometer"), unit: unitByVID[vid])
                let when = date(field(row, r.headers, "DateTime")) ?? Date()
                // TankLevelAfter ~100 ⇒ filled to full; blank ⇒ unknown (treated as full downstream).
                let filledToFull = double(field(row, r.headers, "TankLevelAfter")).map { $0 >= 99.5 }
                let missedPrevious = field(row, r.headers, "MissedPreviousRefuel") == "1"
                result.fuels.append(FuelLog(
                    carID: cid,
                    date: when,
                    amount: total, currency: "EUR", liters: liters,
                    odometerKm: odo,
                    station: nilIfEmpty(field(row, r.headers, "Location")),
                    filledToFull: filledToFull,
                    missedPrevious: missedPrevious))
                record(vid, odo, when)
                counts[vid]?.f += 1
            }
        }

        // Services / Expenses / Notes → log entries
        func ingest(_ section: String, kind: LogKind, typeColumn: String, sumColumn: String?) {
            guard let s = sections[section] else { return }
            for row in s.rows {
                let vid = field(row, s.headers, "vehicleId")
                guard let cid = carID(vid) else { continue }
                let odo = odometerKm(field(row, s.headers, "Odometer"), unit: unitByVID[vid])
                let amount = sumColumn.flatMap { decimal(field(row, s.headers, $0)) }.flatMap { $0 > 0 ? $0 : nil }
                let text = kind == .note ? field(row, s.headers, "Notes") : note(row, s.headers, typeColumn: typeColumn)
                if kind == .note && text.isEmpty { continue }
                let when = date(field(row, s.headers, "DateTime")) ?? Date()
                result.entries.append(LogEntry(
                    carID: cid, kind: kind,
                    date: when,
                    amount: amount, note: text, odometerKm: odo))
                record(vid, odo, when)
                switch kind { case .service: counts[vid]?.s += 1; case .expense: counts[vid]?.e += 1; case .note: counts[vid]?.n += 1 }
            }
        }
        ingest("Services", kind: .service, typeColumn: "Service", sumColumn: "Sum")
        ingest("Expenses", kind: .expense, typeColumn: "Expense", sumColumn: "Sum")
        ingest("NoteEvents", kind: .note, typeColumn: "Notes", sumColumn: nil)

        // Odometer events feed the dated trail (and the current reading).
        if let o = sections["OdometerEvents"] {
            for row in o.rows {
                let vid = field(row, o.headers, "vehicleId")
                record(vid, odometerKm(field(row, o.headers, "Odometer"), unit: unitByVID[vid]),
                       date(field(row, o.headers, "DateTime")))
            }
        }

        // Apply the highest reading seen as each car's current odometer; build summaries in car order.
        var vidByIndex: [Int: String] = [:]
        for (vid, idx) in indexByVID { vidByIndex[idx] = vid }
        for idx in result.cars.indices {
            guard let vid = vidByIndex[idx] else { continue }
            let initial = result.cars[idx].initialOdometerKm ?? 0
            let current = max(maxOdo[vid] ?? 0, initial)
            if current > 0 { result.cars[idx].odometerKm = current }
            // Persist the dated odometer trail (collapsed to one reading per day) so the mileage
            // gauge and the fuel-economy / distance lines have real history after import.
            if let readings = readingsByVID[vid], !readings.isEmpty {
                let cal = Calendar.current
                var byDay: [Date: Int] = [:]
                for r in readings.sorted(by: { $0.date < $1.date }) { byDay[cal.startOfDay(for: r.date)] = r.km }
                result.cars[idx].odometerLog = byDay.map { OdometerReading(date: $0.key, km: $0.value) }
                    .sorted { $0.date < $1.date }
            }
            if let sold = soldByVID[vid] { result.cars[idx].archivedAt = sold }
            let c = counts[vid] ?? (0, 0, 0, 0)
            let car = result.cars[idx]
            result.summaries.append(CarSummary(
                id: car.id,
                name: car.displayName,
                detail: [car.make, car.model].filter { !$0.isEmpty }.joined(separator: " "),
                fuels: c.f, services: c.s, expenses: c.e, notes: c.n, photo: car.photo))
        }
        return result
    }

    // MARK: sections
    private struct Section { var headers: [String: Int]; var rows: [[String]] }

    private static func splitSections(_ csv: String) -> [String: Section] {
        var sections: [String: Section] = [:]
        var current: String?
        var needHeader = false
        for rawLine in csv.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
            if line.hasPrefix("## ") {
                current = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                sections[current!] = Section(headers: [:], rows: [])
                needHeader = true
                continue
            }
            if line.hasPrefix("#") { continue }                  // the "# My Car CSV Export" title
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            guard let key = current else { continue }
            let fields = csvFields(line)
            if needHeader {
                var map: [String: Int] = [:]
                for (i, name) in fields.enumerated() { map[name] = i }
                sections[key]?.headers = map
                needHeader = false
            } else {
                sections[key]?.rows.append(fields)
            }
        }
        return sections
    }

    /// CSV field splitter — handles quoted fields, embedded commas, and "" escaped quotes.
    private static func csvFields(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { current.append("\""); i += 2; continue }
                    inQuotes = false
                } else { current.append(c) }
            } else if c == "\"" {
                inQuotes = true
            } else if c == "," {
                fields.append(current); current = ""
            } else {
                current.append(c)
            }
            i += 1
        }
        fields.append(current)
        return fields
    }

    // MARK: field helpers
    private static func field(_ row: [String], _ cols: [String: Int], _ name: String) -> String {
        guard let i = cols[name], i < row.count else { return "" }
        return row[i].trimmingCharacters(in: .whitespaces)
    }
    private static func nilIfEmpty(_ s: String) -> String? { s.isEmpty ? nil : s }
    private static func int(_ s: String) -> Int? { Int(s) ?? Double(s).map { Int($0) } }
    private static func double(_ s: String) -> Double? { s.isEmpty ? nil : Double(s) }
    private static func decimal(_ s: String) -> Decimal? { s.isEmpty ? nil : Decimal(string: s) }

    /// MyCar odometer can be miles (odometerUnit "0") or km; normalise to km, drop zero/blank.
    private static func odometerKm(_ s: String, unit: String?) -> Int? {
        guard let v = double(s), v > 0 else { return nil }
        let km = unit == "0" ? v * 1.60934 : v
        return Int(km.rounded())
    }

    /// MyCar fuel volume can be US gallons (fuelUnit "1") or imperial gallons ("2"); normalise to
    /// litres so every derived L/100km is right. Anything else (incl. blank) is treated as litres.
    private static func volumeLiters(_ s: String, unit: String?) -> Double? {
        guard let v = double(s), v > 0 else { return nil }
        switch unit {
        case "1": return v * 3.785411784   // US gallon → L
        case "2": return v * 4.54609       // imperial gallon → L
        default:  return v                 // litres
        }
    }

    private static func fuelType(_ code: String) -> FuelType {
        switch code {
        case "0": return .petrol
        case "1": return .diesel
        case "2": return .lpg
        case "3": return .cng
        case "4": return .electric
        default:  return .other
        }
    }

    /// MyCar timestamps: "...T...Z" (UTC) or "...T..." with millis and no zone (treat as local).
    private static func date(_ s: String) -> Date? {
        guard !s.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        if s.hasSuffix("Z") {
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"; f.timeZone = TimeZone(identifier: "UTC")
        } else {
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"; f.timeZone = .current
        }
        return f.date(from: s)
    }

    // MARK: photos (from a .dat backup)
    /// Pull each car's photo out of a MyCar `.dat` (a ZIP), keyed by Koi car id, downscaled.
    /// Globs the archive (any image under the car's folder, preferring the wide hero) instead of a
    /// single hard-coded path, so it survives MyCar layout/extension changes. Returns [:] if the
    /// data isn't a readable ZIP or holds no car images — the caller surfaces that to the user.
    static func photos(fromDat data: Data, vehicleIDByCarID: [UUID: String]) -> [UUID: Data] {
        guard let zip = ZipReader(data) else { return [:] }
        let imageExts = ["jpg", "jpeg", "png", "heic"]
        let imageNames = zip.names.filter { name in
            let l = name.lowercased(); return imageExts.contains { l.hasSuffix("." + $0) }
        }
        func extractDownscaled(_ name: String) -> Data? {
            guard let raw = zip.extract(name) else { return nil }
            return downscaledJPEG(raw, maxPixel: 1400) ?? raw
        }
        func pickWide(_ names: [String]) -> String? {
            names.first { $0.lowercased().contains("wideimage") } ?? names.first
        }

        var out: [UUID: Data] = [:]
        for (carID, vid) in vehicleIDByCarID {
            let needle = "/\(vid.lowercased())/"
            let forVID = imageNames.filter { $0.lowercased().contains(needle) }
            if let name = pickWide(forVID), let photo = extractDownscaled(name) { out[carID] = photo }
        }
        // Single-car fallback: folder ids didn't line up but there's exactly one car and an image.
        if out.isEmpty, vehicleIDByCarID.count == 1, let carID = vehicleIDByCarID.keys.first,
           let name = pickWide(imageNames), let photo = extractDownscaled(name) {
            out[carID] = photo
        }
        return out
    }

    /// Downscale + re-encode a JPEG via ImageIO — applies the EXIF orientation and drops metadata.
    private static func downscaledJPEG(_ data: Data, maxPixel: Int) -> Data? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out as CFMutableData, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cg, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
