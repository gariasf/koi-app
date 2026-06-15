import Foundation

/// Client for the Spanish government (minetur) fuel-price REST API.
/// Province endpoint returns every product per station; we keep diesel + petrol-95.
struct FuelPriceService {
    private let base = "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes"

    func fetch(provinceID: String) async throws -> [FuelStation] {
        let url = URL(string: "\(base)/EstacionesTerrestres/FiltroProvincia/\(provinceID)")!
        var (data, _) = try await URLSession.shared.data(from: url)
        data = Self.stripBOM(data)   // the feed is served with a UTF-8 BOM
        let feed = try JSONDecoder().decode(Feed.self, from: data)
        return feed.stations.compactMap(Self.map)
    }

    // MARK: Wire format (accented/spaced keys, comma decimals, empty string = not sold)
    private struct Feed: Decodable {
        let stations: [RawStation]
        enum CodingKeys: String, CodingKey { case stations = "ListaEESSPrecio" }
    }

    private struct RawStation: Decodable {
        let rotulo, direccion, municipio, provincia, lat, lon, ideess, gasoleoA, gasolina95: String?
        enum CodingKeys: String, CodingKey {
            case rotulo = "Rótulo"
            case direccion = "Dirección"
            case municipio = "Municipio"
            case provincia = "Provincia"
            case lat = "Latitud"
            case lon = "Longitud (WGS84)"
            case ideess = "IDEESS"
            case gasoleoA = "Precio Gasoleo A"
            case gasolina95 = "Precio Gasolina 95 E5"
        }
    }

    private static func map(_ r: RawStation) -> FuelStation? {
        guard let id = r.ideess, let brand = r.rotulo else { return nil }
        return FuelStation(
            id: id,
            brand: brand.capitalized,
            address: r.direccion ?? "",
            municipality: (r.municipio ?? "").capitalized,
            province: (r.provincia ?? "").capitalized,
            latitude: number(r.lat),
            longitude: number(r.lon),
            dieselPrice: number(r.gasoleoA),
            petrolPrice: number(r.gasolina95)
        )
    }

    /// Parse a Spanish-format number ("1,549" / "40,528778"); empty → nil.
    private static func number(_ s: String?) -> Double? {
        guard let s, !s.isEmpty else { return nil }
        return Double(s.replacingOccurrences(of: ",", with: "."))
    }

    private static func stripBOM(_ data: Data) -> Data {
        let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
        return data.starts(with: bom) ? data.subdata(in: 3 ..< data.count) : data
    }
}
