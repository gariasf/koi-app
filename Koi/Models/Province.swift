import Foundation

/// Spanish provinces (INE codes) — the region the fuel feed is queried by.
/// Bundled (stable reference data) to keep Settings local-first / offline-friendly.
struct Province: Identifiable, Hashable {
    let id: String      // INE province code, e.g. "28"
    let name: String
}

extension Province {
    static let all: [Province] = [
        .init(id: "01", name: "Álava"),       .init(id: "02", name: "Albacete"),
        .init(id: "03", name: "Alicante"),    .init(id: "04", name: "Almería"),
        .init(id: "05", name: "Ávila"),       .init(id: "06", name: "Badajoz"),
        .init(id: "07", name: "Balears"),     .init(id: "08", name: "Barcelona"),
        .init(id: "09", name: "Burgos"),      .init(id: "10", name: "Cáceres"),
        .init(id: "11", name: "Cádiz"),       .init(id: "12", name: "Castellón"),
        .init(id: "13", name: "Ciudad Real"), .init(id: "14", name: "Córdoba"),
        .init(id: "15", name: "A Coruña"),    .init(id: "16", name: "Cuenca"),
        .init(id: "17", name: "Girona"),      .init(id: "18", name: "Granada"),
        .init(id: "19", name: "Guadalajara"), .init(id: "20", name: "Gipuzkoa"),
        .init(id: "21", name: "Huelva"),      .init(id: "22", name: "Huesca"),
        .init(id: "23", name: "Jaén"),        .init(id: "24", name: "León"),
        .init(id: "25", name: "Lleida"),      .init(id: "26", name: "La Rioja"),
        .init(id: "27", name: "Lugo"),        .init(id: "28", name: "Madrid"),
        .init(id: "29", name: "Málaga"),      .init(id: "30", name: "Murcia"),
        .init(id: "31", name: "Navarra"),     .init(id: "32", name: "Ourense"),
        .init(id: "33", name: "Asturias"),    .init(id: "34", name: "Palencia"),
        .init(id: "35", name: "Las Palmas"),  .init(id: "36", name: "Pontevedra"),
        .init(id: "37", name: "Salamanca"),   .init(id: "38", name: "S. C. Tenerife"),
        .init(id: "39", name: "Cantabria"),   .init(id: "40", name: "Segovia"),
        .init(id: "41", name: "Sevilla"),     .init(id: "42", name: "Soria"),
        .init(id: "43", name: "Tarragona"),   .init(id: "44", name: "Teruel"),
        .init(id: "45", name: "Toledo"),      .init(id: "46", name: "Valencia"),
        .init(id: "47", name: "Valladolid"),  .init(id: "48", name: "Bizkaia"),
        .init(id: "49", name: "Zamora"),      .init(id: "50", name: "Zaragoza"),
        .init(id: "51", name: "Ceuta"),       .init(id: "52", name: "Melilla"),
    ]

    static func name(for id: String) -> String {
        all.first { $0.id == id }?.name ?? "—"
    }
}
