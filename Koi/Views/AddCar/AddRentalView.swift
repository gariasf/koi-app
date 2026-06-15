import SwiftUI

/// Add · Rental — a time-boxed guest. Pickup/return, fuel policy, excess/CDW.
struct AddRentalView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    var onSaved: (() -> Void)? = nil

    @State private var company = ""
    @State private var carName = ""
    @State private var pickup = Date()
    @State private var dropoff = Date().addingTimeInterval(4 * 86_400)
    @State private var fuelFullToFull = true
    @State private var excess = ""
    @State private var cdw = true

    private var canSave: Bool {
        !company.trimmingCharacters(in: .whitespaces).isEmpty
            && !carName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "New car · Rental")

            ScrollView {
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        KoiField(label: "Company", placeholder: "Europcar", text: $company)
                        KoiField(label: "Car", placeholder: "Fiat 500", text: $carName)
                    }
                    HStack(alignment: .top, spacing: 12) {
                        dateField("Pickup", $pickup)
                        dateField("Return", $dropoff)
                    }
                    fuelPolicy
                    excessCard
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 18)
                .padding(.bottom, 12)
            }

            KoiPrimaryButton(title: "Add rental", enabled: canSave) { save() }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func dateField(_ label: String, _ binding: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).koiStyle(.eyebrow).foregroundStyle(KoiColors.textSubdued)
            DatePicker("", selection: binding, displayedComponents: .date)
                .labelsHidden()
                .tint(KoiColors.sage)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fuelPolicy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Fuel policy").koiStyle(.eyebrow).foregroundStyle(KoiColors.textSubdued)
            HStack(spacing: 4) {
                seg("Full → full", active: fuelFullToFull) { fuelFullToFull = true }
                seg("Prepaid", active: !fuelFullToFull) { fuelFullToFull = false }
            }
            .padding(4)
            .background(KoiColors.insetFill, in: Capsule())
        }
    }

    private func seg(_ label: String, active: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).koiStyle(.meta)
                .foregroundStyle(active ? .white : KoiColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background { if active { Capsule().fill(KoiColors.sage) } }
        }
        .buttonStyle(.plain)
    }

    private var excessCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Excess").koiStyle(.body).foregroundStyle(KoiColors.textPrimary)
                Spacer()
                TextField("€1,200", text: $excess)
                    .koiStyle(.monoMd).foregroundStyle(KoiColors.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .frame(width: 110)
            }
            .padding(14)
            Rectangle().fill(KoiColors.hairline).frame(height: 1).padding(.horizontal, 14)
            KoiToggleRow(title: "Extra cover (CDW) taken",
                         subtitle: "Lower excess, peace of mind",
                         isOn: $cdw)
                .padding(14)
        }
        .koiCard(padding: 0)
    }

    private func save() {
        var car = Car(make: "", model: carName.trimmingCharacters(in: .whitespaces))
        car.accent = .terracotta
        let rental = Rental(company: company.trimmingCharacters(in: .whitespaces),
                            car: car,
                            pickup: pickup,
                            dropoff: dropoff,
                            fuelPolicyFullToFull: fuelFullToFull,
                            excess: Decimal(string: excess.filter { $0.isNumber }),
                            cdwTaken: cdw,
                            returned: false)
        garage.addRental(rental)
        Haptics.success()
        if let onSaved { onSaved() } else { dismiss() }
    }
}

#Preview { AddRentalView().environmentObject(Garage(persists: false)) }
