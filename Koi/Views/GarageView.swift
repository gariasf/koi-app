import SwiftUI

/// The shelf — every car at a glance. Residents (on a plan) + guests (rentals).
struct GarageView: View {
    @EnvironmentObject private var garage: Garage
    @State private var showAdd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                titleRow

                if !garage.residents.isEmpty {
                    Eyebrow(text: "Residents").padding(.top, 4)
                    ForEach(garage.residents) { car in
                        NavigationLink(value: car) {
                            ResidentCard(car: car,
                                         planLabel: garage.plan(for: car)?.kind.label ?? "Owned",
                                         provider: garage.plan(for: car)?.provider)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !garage.rentals.isEmpty {
                    Eyebrow(text: "Guests · past rentals").padding(.top, 8)
                    ForEach(garage.rentals) { rental in
                        NavigationLink(value: rental) { GuestRow(rental: rental) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, KoiSpace.gutter)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Car.self) { car in
            CarDetailView(car: car)
        }
        .navigationDestination(for: Rental.self) { rental in
            RentalDetailView(rental: rental)
        }
        .sheet(isPresented: $showAdd) {
            AddCarSheet().environmentObject(garage)
        }
    }

    private var titleRow: some View {
        HStack {
            Text("Garage").koiStyle(.pageTitle).foregroundStyle(KoiColors.textPrimary)
            Spacer()
            Button { showAdd = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(KoiColors.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(KoiColors.container, in: Circle())
                    .overlay(Circle().strokeBorder(KoiColors.ring, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a car")
        }
        .padding(.top, 4)
    }
}

/// A resident card: per-car-tinted photo tile + name + type pill + meta + mono odometer.
struct ResidentCard: View {
    let car: Car
    let planLabel: String
    var provider: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            car.accent.tile.frame(height: 130)

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
    }

    private var metaLine: String {
        if let provider, !provider.isEmpty { return "\(provider) · \(car.subtitle)" }
        return car.subtitle
    }
}

/// A guest (rental) episode — lighter than a resident card.
struct GuestRow: View {
    let rental: Rental

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: KoiRadius.tile, style: .continuous)
                .fill(CarAccent.terracotta.tile)
                .frame(width: 46, height: 46)
                .overlay(
                    Text(rental.car.model.isEmpty ? "—" : String(rental.car.model.prefix(3)))
                        .koiStyle(.monoSm).foregroundStyle(CarAccent.terracotta.text)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text("\(rental.car.displayName) · \(rental.company)")
                    .koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary)
                Text("\(KoiFormat.shortDate(rental.pickup)) – \(KoiFormat.shortDate(rental.dropoff))")
                    .koiStyle(.meta).foregroundStyle(KoiColors.textSecondary)
            }
            Spacer(minLength: 8)
            Text(rental.returned ? "Returned" : "Active")
                .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(KoiColors.insetFill, in: Capsule())
        }
        .koiCard()
    }
}

/// Add-a-car flow launched from the Garage ＋. Pick a relationship → push its form.
struct AddCarSheet: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ModalHeader(title: "Add a car") { dismiss() }
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Relationship.allCases) { r in
                            NavigationLink(value: r) {
                                OptionRowContent(icon: r.icon, title: r.title, subtitle: r.subtitle)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, KoiSpace.gutter)
                    .padding(.top, 18)
                }
            }
            .background(KoiColors.surface.ignoresSafeArea())
            .navigationDestination(for: Relationship.self) { r in
                switch r {
                case .own:    AddOwnedCarView(onSaved: { dismiss() }).environmentObject(garage)
                case .plan:   AddPlanCarView(onSaved: { dismiss() }).environmentObject(garage)
                case .borrow: AddRentalView(onSaved: { dismiss() }).environmentObject(garage)
                }
            }
        }
    }
}

#Preview { NavigationStack { GarageView() }.environmentObject(Garage.preview) }
