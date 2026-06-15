import SwiftUI
import Foundation

/// Editable plan fields, shared by the add-plan form and the edit flow.
struct PlanFormData {
    var kind: PlanKind = .subscription
    var provider = ""
    var monthly = ""
    var mileageCap = ""
    var startDate = Date()
    var hasEnd = false
    var endDate = Date().addingTimeInterval(365 * 86_400)
    var includesInsurance = true
    var includesMaintenance = true
    var includesRoadside = true
    var allowsSwap = true
    var swapIntervalMonths = 6

    init() {}

    init(from plan: Plan) {
        kind = plan.kind
        provider = plan.provider ?? ""
        monthly = plan.monthlyCost.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
        mileageCap = plan.mileageCapPerMonth.map(String.init) ?? ""
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
        case .subscription:
            includesInsurance = true; includesMaintenance = true; includesRoadside = true
            allowsSwap = true; hasEnd = false
        case .lease, .finance:
            includesInsurance = false; includesMaintenance = false; includesRoadside = false
            allowsSwap = false; hasEnd = true
        case .owned:
            break
        }
    }

    func apply(to plan: inout Plan) {
        plan.kind = kind
        plan.provider = provider.trimmingCharacters(in: .whitespaces)
        plan.monthlyCost = Decimal(string: monthly.filter { $0.isNumber || $0 == "." })
        plan.mileageCapPerMonth = Int(mileageCap.filter(\.isNumber))
        plan.startedAt = startDate
        plan.endsAt = hasEnd ? endDate : nil
        plan.includesInsurance = includesInsurance
        plan.includesMaintenance = includesMaintenance
        plan.includesRoadside = includesRoadside
        plan.allowsSwap = allowsSwap
        plan.swapIntervalMonths = allowsSwap ? swapIntervalMonths : nil
    }
}

/// Lease / Finance / Subscription segmented control.
struct PlanKindSegmented: View {
    @Binding var kind: PlanKind
    var body: some View {
        HStack(spacing: 4) {
            seg("Lease", .lease)
            seg("Finance", .finance)
            seg("Subscription", .subscription)
        }
        .padding(4)
        .background(KoiColors.insetFill, in: Capsule())
    }
    private func seg(_ label: String, _ k: PlanKind) -> some View {
        Button { kind = k } label: {
            Text(label).koiStyle(.meta)
                .foregroundStyle(kind == k ? .white : KoiColors.textSecondary)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background { if kind == k { Capsule().fill(KoiColors.sage) } }
        }
        .buttonStyle(.plain)
    }
}

struct PlanFieldsSection: View {
    @Binding var data: PlanFormData

    var body: some View {
        VStack(spacing: 16) {
            KoiField(label: "Provider", placeholder: "Mocean", text: $data.provider)
            HStack(alignment: .top, spacing: 12) {
                KoiField(label: "Monthly", placeholder: "€459", text: $data.monthly, keyboard: .numberPad)
                KoiField(label: "Mileage cap", placeholder: "1,500 /mo", text: $data.mileageCap, mono: true, keyboard: .numberPad)
            }
            termCard
            includedCard
            swapCard
        }
    }

    private var termCard: some View {
        VStack(spacing: 0) {
            dateRow("Starts", $data.startDate)
            hairline
            KoiToggleRow(title: "Has an end date", isOn: $data.hasEnd).padding(14)
            if data.hasEnd {
                hairline
                dateRow("Ends", $data.endDate)
            }
        }
        .koiCard(padding: 0)
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
            KoiToggleRow(title: "Insurance",
                         subtitle: data.includesInsurance ? "No separate policy to add" : nil,
                         isOn: $data.includesInsurance).padding(14)
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
                HStack(spacing: 6) {
                    Text("Swap interval").koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
                    Spacer()
                    ForEach([3, 6, 12], id: \.self) { m in
                        Button { data.swapIntervalMonths = m } label: {
                            Text("\(m) mo").koiStyle(.meta)
                                .foregroundStyle(data.swapIntervalMonths == m ? .white : KoiColors.textSecondary)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background { if data.swapIntervalMonths == m { Capsule().fill(KoiColors.sage) } else { Capsule().fill(KoiColors.insetFill) } }
                        }
                        .buttonStyle(.plain)
                    }
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
