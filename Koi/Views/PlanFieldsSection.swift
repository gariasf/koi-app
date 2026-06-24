import SwiftUI
import Foundation

/// Editable plan fields, shared by the add-plan form and the edit flow.
struct PlanFormData {
    var kind: PlanKind = .subscription
    var provider = ""
    var monthly = ""
    var initialPayment = ""
    var mileageCap = ""
    var poolsMileage = false
    var startDate = Date()
    var hasEnd = false
    var endDate = Date().addingTimeInterval(365 * 86_400)
    var includesInsurance = false
    var includesMaintenance = false
    var includesRoadside = false
    var allowsSwap = false
    var swapIntervalMonths = 6
    var capPeriod: CapPeriod = .month

    init() {}

    init(from plan: Plan) {
        kind = plan.kind
        provider = plan.provider ?? ""
        monthly = plan.monthlyCost.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
        initialPayment = plan.initialPayment.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
        mileageCap = plan.mileageCapPerMonth.map(String.init) ?? ""
        poolsMileage = plan.mileagePools ?? false
        capPeriod = plan.capPeriod
        startDate = plan.startedAt
        if let e = plan.endsAt { hasEnd = true; endDate = e }
        includesInsurance = plan.includesInsurance
        includesMaintenance = plan.includesMaintenance
        includesRoadside = plan.includesRoadside
        allowsSwap = plan.allowsSwap
        swapIntervalMonths = plan.swapIntervalMonths ?? 6
    }

    var isValid: Bool { !provider.trimmingCharacters(in: .whitespaces).isEmpty }

    mutating func applyPreset() {
        switch kind {
        case .finance:                                 // a loan you're paying off; the car is yours at the end
            includesInsurance = false; includesMaintenance = false; includesRoadside = false
            allowsSwap = false; mileageCap = ""; hasEnd = true
        case .subscription, .lease, .owned:            // "Plan" — the user toggles what their plan includes
            break
        }
    }

    func apply(to plan: inout Plan) {
        plan.kind = kind
        plan.provider = provider.trimmingCharacters(in: .whitespaces)
        plan.monthlyCost = KoiFormat.decimal(monthly)
        plan.initialPayment = KoiFormat.decimal(initialPayment)
        plan.mileageCapPerMonth = Int(mileageCap.filter(\.isNumber))
        plan.mileageCapPeriod = capPeriod
        plan.mileagePools = (Int(mileageCap.filter(\.isNumber)) ?? 0) > 0 ? poolsMileage : nil
        plan.startedAt = startDate
        plan.endsAt = hasEnd ? endDate : nil
        plan.includesInsurance = includesInsurance
        plan.includesMaintenance = includesMaintenance
        plan.includesRoadside = includesRoadside
        plan.allowsSwap = allowsSwap
        plan.swapIntervalMonths = allowsSwap ? swapIntervalMonths : nil
    }
}

/// Plan / Finance segmented control.
struct PlanKindSegmented: View {
    @Binding var kind: PlanKind
    var body: some View {
        Picker("Plan type", selection: $kind) {
            Text("Plan").tag(PlanKind.subscription)
            Text("Finance").tag(PlanKind.finance)
        }
        .pickerStyle(.segmented)
    }
}

struct PlanFieldsSection: View {
    @Binding var data: PlanFormData

    var body: some View {
        VStack(spacing: 16) {
            KoiField(label: providerLabel, placeholder: providerPlaceholder, text: $data.provider)
            HStack(alignment: .top, spacing: 12) {
                KoiField(label: "Monthly", placeholder: "€459", text: $data.monthly, mono: true, keyboard: .decimalPad)
                KoiField(label: depositLabel, placeholder: "€0", text: $data.initialPayment, mono: true, keyboard: .decimalPad)
            }
            // A mileage cap (and its reset interval) only applies to a plan, not financing.
            if data.kind != .finance { mileageCapCard }
            termCard
            // "What's included" only fits subscription/lease. Financing is just the loan.
            if data.kind != .finance { includedCard }
            // Swapping one car for another is a subscription feature.
            if data.kind == .subscription { swapCard }
        }
    }

    private var providerLabel: String { data.kind == .finance ? "Lender" : "Provider" }
    private var providerPlaceholder: String { data.kind == .finance ? "Santander" : "Mocean" }
    private var depositLabel: String { data.kind == .finance ? "Down payment" : "Deposit" }

    private var termCard: some View {
        VStack(spacing: 0) {
            dateRow("Starts", $data.startDate)
            hairline
            endRow
        }
        .koiCard(padding: 0)
    }

    // One row, no separate toggle: tap to add an end date, tap the ✕ to clear it back to open-ended.
    private var endRow: some View {
        HStack {
            Text("Ends").koiStyle(.body).foregroundStyle(KoiColors.textPrimary)
            Spacer()
            if data.hasEnd {
                DatePicker("", selection: $data.endDate, displayedComponents: .date)
                    .labelsHidden().tint(KoiColors.sage)
                Button { data.hasEnd = false } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 16))
                        .foregroundStyle(KoiColors.textSubdued)
                }
                .buttonStyle(.plain).padding(.leading, 6)
            } else {
                Button { data.hasEnd = true } label: {
                    Text("Add an end date").koiStyle(.body).foregroundStyle(KoiColors.sageText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
    }

    private var mileageCapCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            KoiField(label: "Mileage cap (km)", placeholder: "1,500", text: $data.mileageCap, mono: true, keyboard: .numberPad, grouped: true)
            Picker("Resets", selection: $data.capPeriod) {
                ForEach(CapPeriod.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            if (Int(data.mileageCap.filter(\.isNumber)) ?? 0) > 0 {
                VStack(spacing: 0) {
                    KoiToggleRow(title: "Unused km roll over",
                                 subtitle: data.poolsMileage ? "Banks under-driven \(data.capPeriod.noun)s" : "Strict \(data.capPeriod.noun)ly cap",
                                 isOn: $data.poolsMileage).padding(14)
                }
                .koiCard(padding: 0)
                if data.poolsMileage {
                    Text("For contracts that only read the odometer at the end. The gauge shows your real allowance, including what you didn't use.")
                        .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                }
            }
        }
    }

    private func dateRow(_ label: String, _ binding: Binding<Date>) -> some View {
        HStack {
            Text(label).koiStyle(.body).foregroundStyle(KoiColors.textPrimary)
            Spacer()
            DatePicker("", selection: binding, displayedComponents: .date).labelsHidden().tint(KoiColors.sage)
        }
        .padding(14)
    }

    private var includedCard: some View {
        VStack(spacing: 0) {
            KoiToggleRow(title: "Insurance", isOn: $data.includesInsurance).padding(14)
            hairline
            KoiToggleRow(title: "Maintenance & service", isOn: $data.includesMaintenance).padding(14)
            hairline
            KoiToggleRow(title: "Roadside assistance", isOn: $data.includesRoadside).padding(14)
        }
        .koiCard(padding: 0)
    }

    private var swapCard: some View {
        VStack(spacing: 0) {
            KoiToggleRow(title: "Lets you swap cars",
                         subtitle: data.allowsSwap ? "Every \(data.swapIntervalMonths) months" : "Off for this plan",
                         isOn: $data.allowsSwap).padding(14)
            if data.allowsSwap {
                hairline
                HStack {
                    Text("Swap interval").koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
                    Spacer()
                    Picker("Swap interval", selection: $data.swapIntervalMonths) {
                        Text("3 mo").tag(3)
                        Text("6 mo").tag(6)
                        Text("12 mo").tag(12)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }
                .padding(14)
            }
        }
        .koiCard(padding: 0)
    }

    private var hairline: some View {
        Rectangle().fill(KoiColors.hairline).frame(height: 1).padding(.horizontal, 14)
    }
}
