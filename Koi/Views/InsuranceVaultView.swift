import SwiftUI

/// A car's documents vault — the Docs destination. Insurance adapts to the relationship:
/// owned/lease/finance → a Wallet-style policy card + renewal; subscription → "Included";
/// (rentals capture excess/CDW on the rental itself, not here.)
struct InsuranceVaultView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    let car: Car
    @State private var showAddPolicy = false

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "Insurance")
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    insuranceSection
                    vaultSection
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .sheet(isPresented: $showAddPolicy) {
            AddPolicyView(car: car).environmentObject(garage).presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder private var insuranceSection: some View {
        if garage.insuranceIncludedInPlan(for: car) {
            includedCard
        } else if let policy = garage.policy(for: car) {
            InsuranceCard(policy: policy, vehicle: vehicleLine)
            renewRow(policy)
        } else {
            addPolicyPrompt
        }
    }

    private var includedCard: some View {
        HStack(spacing: 12) {
            IconTile(systemName: "shield.lefthalf.filled", tint: .sage)
            VStack(alignment: .leading, spacing: 3) {
                Text("Included in your plan").koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary)
                Text(includedSubtitle).koiStyle(.meta).foregroundStyle(KoiColors.textSecondary)
            }
            Spacer(minLength: 8)
        }
        .koiCard()
    }
    private var includedSubtitle: String {
        if let p = garage.plan(for: car)?.provider, !p.isEmpty { return "No separate policy — \(p) covers it" }
        return "No separate policy to add"
    }

    private var addPolicyPrompt: some View {
        Button { showAddPolicy = true } label: {
            HStack(spacing: 12) {
                IconTile(systemName: "umbrella", tint: .sage)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Add a policy").koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary)
                    Text("Keep the card, track the renewal").koiStyle(.meta).foregroundStyle(KoiColors.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .medium)).foregroundStyle(KoiColors.textSubdued)
            }
            .koiCard()
        }
        .buttonStyle(.plain)
    }

    private func renewRow(_ policy: InsurancePolicy) -> some View {
        let days = policy.validTo.map(daysUntil)
        let soon = (days ?? .max) <= 21
        return HStack {
            Text(renewText(policy))
                .koiStyle(.meta)
                .foregroundStyle(soon ? KoiColors.ochreText : KoiColors.textSecondary)
            Spacer()
            Button { garage.renew(policy); Haptics.success() } label: {
                Text("Renew").koiStyle(.body).foregroundStyle(KoiColors.sageText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    private var vaultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Also in the vault")
            let docs = garage.carDocuments(for: car).filter { $0.kind != .insurance }
            if docs.isEmpty {
                Text("Nothing else here yet.").koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(docs.enumerated()), id: \.element.id) { idx, d in
                        docRow(d, last: idx == docs.count - 1)
                    }
                }
                .koiCard(padding: 0)
            }
            // TODO: native document picker / scan (P9).
            Button { } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .medium))
                    Text("Add document").koiStyle(.body)
                }
                .foregroundStyle(KoiColors.sageText)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    private func docRow(_ d: Document, last: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(systemName: d.kind.icon, tint: .neutral)
                VStack(alignment: .leading, spacing: 3) {
                    Text(d.title).koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary)
                    if let s = d.subtitle { Text(s).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued) }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .medium)).foregroundStyle(KoiColors.textSubdued)
            }
            .padding(14)
            if !last { Rectangle().fill(KoiColors.hairline).frame(height: 1).padding(.leading, 14) }
        }
    }

    private var vehicleLine: String {
        if let plate = car.plate, !plate.isEmpty { return "\(car.displayName) · \(plate)" }
        return car.displayName
    }

    private func renewText(_ p: InsurancePolicy) -> String {
        guard let to = p.validTo else { return "" }
        let date = to.formatted(.dateTime.day().month(.abbreviated))
        let days = daysUntil(to)
        if days < 0 { return "Renewal overdue · \(date)" }
        return "Renews in \(days) days · \(date)"
    }

    private func daysUntil(_ date: Date) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
    }
}

/// The Wallet-style keepsake: white card, sage top band, insurer + coverage, 2×2 data
/// grid, and a barcode "roadside proof" strip.
struct InsuranceCard: View {
    let policy: InsurancePolicy
    let vehicle: String

    var body: some View {
        VStack(spacing: 0) {
            KoiColors.sage.frame(height: 7)
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "shield.lefthalf.filled").font(.system(size: 20)).foregroundStyle(KoiColors.sage)
                        Text(policy.insurer).koiStyle(.carName).foregroundStyle(KoiColors.textPrimary)
                    }
                    Spacer()
                    Text(policy.coverage).koiStyle(.meta).foregroundStyle(KoiColors.sageText)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(KoiColors.sageTint, in: Capsule())
                }
                HStack(spacing: 0) {
                    gridCell("Policy no.", policy.policyNumber, mono: true)
                    gridCell("Premium", premiumText, mono: true)
                }
                HStack(spacing: 0) {
                    gridCell("Vehicle", vehicle)
                    gridCell("Valid until", validText, mono: true)
                }
                VStack(spacing: 6) {
                    Image(systemName: "barcode").resizable().scaledToFit().frame(height: 36)
                        .foregroundStyle(KoiColors.textPrimary)
                    Text("Roadside proof").koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
            .padding(18)
        }
        .background(KoiColors.container)
        .clipShape(RoundedRectangle(cornerRadius: KoiRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: KoiRadius.card, style: .continuous).strokeBorder(KoiColors.ring, lineWidth: 1))
        .shadow(color: KoiColors.cardShadow, radius: 6, x: 0, y: 4)
    }

    private func gridCell(_ label: String, _ value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).koiStyle(.eyebrow).foregroundStyle(KoiColors.textSubdued)
            Text(value).koiStyle(mono ? .monoMd : .body).foregroundStyle(KoiColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var premiumText: String {
        policy.premium.map { KoiFormat.money($0, code: policy.currency) + " / yr" } ?? "—"
    }
    private var validText: String {
        policy.validTo?.formatted(.dateTime.day().month(.abbreviated).year()) ?? "—"
    }
}

#Preview {
    InsuranceVaultView(car: Garage.preview.residents.first!).environmentObject(Garage.preview)
}
