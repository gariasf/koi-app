import SwiftUI
import UIKit

/// The shelf — every car you live with, at a glance.
struct GarageView: View {
    @EnvironmentObject private var garage: Garage
    @State private var showAdd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !garage.residents.isEmpty {
                    Eyebrow(text: "Residents")
                        .padding(.bottom, 14)   // clear the floating ＋ so the first card isn't flush under it
                    ForEach(garage.residents) { car in
                        NavigationLink(value: car) {
                            ResidentCard(car: car,
                                         planLabel: garage.plan(for: car)?.kind.label ?? "Owned",
                                         provider: garage.plan(for: car)?.provider)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !garage.archivedCars.isEmpty {
                    Eyebrow(text: "Archived")
                        .padding(.top, garage.residents.isEmpty ? 14 : 18)
                    VStack(spacing: 0) {
                        ForEach(Array(garage.archivedCars.enumerated()), id: \.element.id) { idx, car in
                            ArchivedRow(car: car) { garage.unarchiveCar(car); Haptics.success() }
                            if idx < garage.archivedCars.count - 1 {
                                Rectangle().fill(KoiColors.hairline).frame(height: 1).padding(.leading, 14)
                            }
                        }
                    }
                    .koiCard(padding: 0)
                }
            }
            .padding(.horizontal, KoiSpace.gutter)
            .padding(.top, 28)
            .padding(.bottom, 16)
        }
        // The ＋ floats OVER the list as an overlay (NOT a sibling of the card NavigationLinks — that
        // mis-routes the first tap on iOS 17), so the cards scroll cleanly beneath it with no header
        // band cutting in. Bonus: the glass now has content behind it to refract while you scroll.
        .overlay(alignment: .topTrailing) {
            KoiIconButton(systemName: Ph.plus, accessibilityLabel: "Add a car", style: .glass) { showAdd = true }
                .padding(.trailing, KoiSpace.gutter)
                .padding(.top, 18)
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Car.self) { car in
            CarDetailView(car: car)
        }
        .sheet(isPresented: $showAdd) {
            AddCarSheet().environmentObject(garage)
        }
    }

}

/// A resident card: per-car-tinted photo tile + name + type pill + meta + mono odometer.
struct ResidentCard: View {
    let car: Car
    let planLabel: String
    var provider: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            CarPhotoTile(car: car, height: 130)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(car.displayName).koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary)
                    Spacer(minLength: 8)
                    Text(planLabel).koiStyle(.meta).foregroundStyle(car.accent.text)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(car.accent.pillBackground, in: Capsule())
                }
                Text(metaLine).koiStyle(.meta).foregroundStyle(KoiColors.textSecondary)
                if let odo = car.odometerKm {
                    Text(KoiFormat.km(odo)).koiStyle(.monoSm).foregroundStyle(KoiColors.textPrimary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(KoiColors.container)
        .clipShape(RoundedRectangle(cornerRadius: KoiRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KoiRadius.card, style: .continuous)
                .strokeBorder(KoiColors.ring, lineWidth: 1)
        )
        .shadow(color: KoiColors.cardShadow, radius: 2, x: 0, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: KoiRadius.card, style: .continuous))
    }

    private var metaLine: String {
        [provider, car.subtitle].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// A shelved car: muted row that taps through to its detail, with a quick restore on the side.
struct ArchivedRow: View {
    let car: Car
    let onRestore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: car) {
                HStack(spacing: 12) {
                    thumb
                    VStack(alignment: .leading, spacing: 3) {
                        Text(car.displayName).koiStyle(.listTitle).foregroundStyle(KoiColors.textSecondary)
                        if !car.subtitle.isEmpty {
                            Text(car.subtitle).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                        }
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onRestore) {
                Image(systemName: "tray.and.arrow.up")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(car.accent.text)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Move \(car.displayName) back to garage")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var thumb: some View {
        if let d = car.photo, let ui = UIImage(data: d) {
            Image(uiImage: ui).resizable().scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: KoiRadius.tile, style: .continuous))
                .saturation(0.4).opacity(0.8)
        } else {
            IconTile(systemName: "car", tint: .sage)
        }
    }
}

/// Add-a-car flow launched from the Garage ＋. Pick a relationship → its form opens as a
/// drawer over the picker (swipe it down to go back to the picker; save closes everything).
struct AddCarSheet: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Relationship?

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "Add a car")
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Relationship.allCases) { r in
                        OptionRow(icon: r.icon, title: r.title, subtitle: r.subtitle) { selected = r }
                    }
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 18)
            }
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .sheet(item: $selected) { r in
            Group {
                switch r {
                case .own:  AddOwnedCarView(onSaved: { dismiss() })
                case .plan: AddPlanCarView(onSaved: { dismiss() })
                }
            }
            .environmentObject(garage)
            .presentationDragIndicator(.visible)
        }
    }
}

#Preview { NavigationStack { GarageView() }.environmentObject(Garage.preview) }
