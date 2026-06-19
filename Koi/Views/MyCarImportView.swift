import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Bring history across from the MyCar app. Pick its CSV export, preview what was found, import.
struct MyCarImportView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss

    @State private var showImporter = false
    @State private var parsed: MyCarImporter.Result?
    @State private var failed = false
    @State private var selected: Set<UUID> = []
    @State private var showDatImporter = false

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "Import from MyCar")
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Bring your history across from the MyCar app. In MyCar, export your data as a CSV, then choose that file here. Your cars come in as owned, with their fill-ups, services and expenses.")
                        .koiStyle(.meta).foregroundStyle(KoiColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let p = parsed, !p.isEmpty {
                        preview(p)
                        KoiTextButton(title: p.summaries.contains { $0.photo != nil } ? "Photos added — pick another .dat" : "Add photos from a .dat backup",
                                      systemIcon: "photo") { showDatImporter = true }
                        KoiTextButton(title: "Choose a different file", systemIcon: "arrow.triangle.2.circlepath", role: .muted) { showImporter = true }
                    } else {
                        chooseButton
                        if failed {
                            Text("Couldn't read that file. Make sure it's the CSV that MyCar exports (not the .dat backup).")
                                .koiStyle(.meta).foregroundStyle(KoiColors.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 18)
                .padding(.bottom, 12)
            }
            if let p = parsed, !p.isEmpty {
                KoiPrimaryButton(title: "Import \(selected.count) car\(selected.count == 1 ? "" : "s")",
                                 systemIcon: "square.and.arrow.down", enabled: !selected.isEmpty) {
                    garage.importMyCar(p.selecting(selected))
                    Haptics.success()
                    dismiss()
                }
                .padding(.horizontal, KoiSpace.gutter).padding(.top, 10).padding(.bottom, 12)
            }
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
            parsed = nil; failed = false
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { failed = true; return }
            let r = MyCarImporter.parse(text)
            if r.isEmpty { failed = true } else { parsed = r; selected = Set(r.cars.map { $0.id }) }
        }
        .onAppear {
            // dev: `-importdemo` shows the selectable preview without a file picker
            if parsed == nil, ProcessInfo.processInfo.arguments.contains("-importdemo") {
                let r = MyCarImporter.parse(Self.demoCSV)
                if !r.isEmpty { parsed = r; selected = Set(r.cars.map { $0.id }) }
            }
        }
        .fileImporter(isPresented: $showDatImporter, allowedContentTypes: [.data]) { result in
            guard case .success(let url) = result, let p = parsed else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return }
            let map = MyCarImporter.photos(fromDat: data, vehicleIDByCarID: p.vehicleIDByCarID)
            if !map.isEmpty { parsed = p.withPhotos(map) }
        }
    }

    private var chooseButton: some View {
        Button { showImporter = true } label: {
            VStack(spacing: 8) {
                Image(systemName: "doc.badge.arrow.up").font(.system(size: 24, weight: .regular))
                    .foregroundStyle(KoiColors.sageText)
                Text("Choose a MyCar CSV").koiStyle(.body).foregroundStyle(KoiColors.textPrimary)
            }
            .frame(maxWidth: .infinity).frame(height: 120)
            .background(KoiColors.insetFill, in: RoundedRectangle(cornerRadius: KoiRadius.cardSmall, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: KoiRadius.cardSmall, style: .continuous)
                .strokeBorder(KoiColors.border, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        }
        .buttonStyle(.plain)
    }

    private func preview(_ p: MyCarImporter.Result) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Choose what to import")
            VStack(spacing: 0) {
                ForEach(Array(p.summaries.enumerated()), id: \.element.id) { idx, s in
                    let isOn = selected.contains(s.id)
                    Button { toggle(s.id) } label: {
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                carThumb(s)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(s.name).koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary)
                                    Text(countsLine(s)).koiStyle(.meta).foregroundStyle(KoiColors.textSecondary)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(isOn ? KoiColors.sage : KoiColors.textSubdued)
                            }
                            .padding(14)
                            if idx < p.summaries.count - 1 {
                                Rectangle().fill(KoiColors.hairline).frame(height: 1).padding(.leading, 14)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .koiCard(padding: 0)
        }
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        Haptics.tap()
    }

    private func countsLine(_ s: MyCarImporter.CarSummary) -> String {
        var parts = [s.detail]
        if s.fuels > 0 { parts.append("\(s.fuels) fill-up\(s.fuels == 1 ? "" : "s")") }
        if s.services > 0 { parts.append("\(s.services) service\(s.services == 1 ? "" : "s")") }
        if s.expenses > 0 { parts.append("\(s.expenses) expense\(s.expenses == 1 ? "" : "s")") }
        if s.notes > 0 { parts.append("\(s.notes) note\(s.notes == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private func carThumb(_ s: MyCarImporter.CarSummary) -> some View {
        if let d = s.photo, let ui = UIImage(data: d) {
            Image(uiImage: ui).resizable().scaledToFill()
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: KoiRadius.tile, style: .continuous))
        } else {
            IconTile(systemName: "car", tint: .sage)
        }
    }

    /// dev-only sample for `-importdemo` (real parser, no file picker).
    static let demoCSV = [
        "# My Car CSV Export v2.0", "",
        "## Vehicles",
        "id,name,make,model,year,odometerUnit,hasTripMeter,hasOnboardComputer,notes,fuelType,fuelUnit,tankCapacity,fuelEfficiencyUnit,fuelType2,fuelUnit2,tankCapacity2,fuelEfficiencyUnit2,purchaseDateTime,purchasePrice,purchaseOdometer,sellingDateTime,sellingPrice,sellingOdometer,details",
        "v1,\"Max\",\"Opel\",\"Astra\",2008,1,0,1,\"\",1,0,52.00,24,,,,,2019-07-26T22:00:00.000Z,4800.00,82047.0,,0.00,0.0,",
        "v2,\"Koi\",\"Hyundai\",\"Kona\",2025,1,0,1,\"\",0,0,47.00,24,,,,,2025-06-08T22:00:00.000Z,0.00,9525.0,,0.00,0.0,",
        "",
        "## Refuels",
        "vehicleId,DateTime,Location,Odometer,Notes,Driver,TripDistance,FuelType,IsSecondaryFuelType,UnitPrice,Amount,TankLevelAfter,MissedPreviousRefuel,Total",
        "v1,2025-12-28T15:14:00.000,\"\",156878.0,\"\",\"\",,1,0,1.2469,31.95,100.00,0,39.84",
        "",
        "## Services",
        "vehicleId,DateTime,Location,Odometer,Notes,Driver,Service,Sum",
        "v1,2024-02-05T11:58:00.000,\"\",139049.0,\"\",\"\",\"Engine Oil\",141.94",
    ].joined(separator: "\n")
}

#Preview { MyCarImportView().environmentObject(Garage.preview) }
