import SwiftUI

/// Swap the car on a subscription plan. The plan continues; the new car joins the
/// lineage and becomes active; the prior car retires into history.
struct AddSwapCarView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    let plan: Plan
    let currentCar: Car
    var onSaved: (() -> Void)? = nil

    @State private var makeModel = ""
    @State private var odometer = ""

    private var canSave: Bool { !makeModel.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "Swap car") { dismiss() }
            ScrollView {
                VStack(spacing: 16) {
                    explainer
                    KoiField(label: "New car · make & model", placeholder: "Hyundai Ioniq 5", text: $makeModel)
                    KoiField(label: "Odometer", placeholder: "0 km", text: $odometer, mono: true, keyboard: .numberPad)
                    planCard
                }
                .padding(.horizontal, KoiSpace.gutter).padding(.top, 18).padding(.bottom, 12)
            }
            KoiPrimaryButton(title: "Swap car", enabled: canSave) { save() }
                .padding(.horizontal, KoiSpace.gutter).padding(.top, 10).padding(.bottom, 12)
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var explainer: some View {
        HStack(spacing: 12) {
            IconTile(systemName: "arrow.triangle.2.circlepath", tint: .sage)
            Text("The plan continues — cost, reminders and history carry over. \(currentCar.displayName) retires into the lineage.")
                .koiStyle(.meta).foregroundStyle(KoiColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .koiCard()
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Plan continues")
            Text(planLine).koiStyle(.monoMd).foregroundStyle(KoiColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .koiCard()
    }

    private var planLine: String {
        var parts: [String] = []
        if let p = plan.provider, !p.isEmpty { parts.append(p) }
        if let m = plan.monthlyCost { parts.append(KoiFormat.money(m) + "/mo") }
        if let cap = plan.mileageCapPerMonth { parts.append("\(cap) km/mo") }
        return parts.joined(separator: " · ")
    }

    private func save() {
        let trimmed = makeModel.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
        var car = Car(make: parts.first ?? trimmed, model: parts.count > 1 ? parts[1] : "")
        car.odometerKm = Int(odometer.filter(\.isNumber))
        car.accent = currentCar.accent   // keep the slot's colour — same relationship continuing
        garage.swapCar(in: plan, to: car)
        if let onSaved { onSaved() } else { dismiss() }
    }
}

#Preview {
    let g = Garage.preview
    return NavigationStack {
        AddSwapCarView(plan: g.plans.last!, currentCar: g.residents.last!)
    }.environmentObject(g)
}
