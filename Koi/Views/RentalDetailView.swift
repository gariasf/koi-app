import SwiftUI

/// Guest detail — a rental. Shows the trip + a one-tap Return that retires it to history.
struct RentalDetailView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    let rental: Rental

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                backRow
                CarAccent.terracotta.tile
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: KoiRadius.card, style: .continuous))
                header
                detailCard
                if !rental.returned {
                    KoiPrimaryButton(title: "Mark as returned", systemIcon: "checkmark") {
                        garage.markReturned(rental)
                        Haptics.success()
                        dismiss()
                    }
                    .padding(.top, 4)
                    Text("Closes the episode — it moves to Guests · past.")
                        .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, KoiSpace.gutter)
            .padding(.bottom, 24)
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var backRow: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 15, weight: .medium))
                    Text("Garage").koiStyle(.body)
                }
                .foregroundStyle(KoiColors.textSecondary)
                .padding(.vertical, 8)
                .padding(.trailing, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.top, 8)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(rental.car.displayName).koiStyle(.carName).foregroundStyle(KoiColors.textPrimary)
                Text(rental.company).koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
            }
            Spacer(minLength: 8)
            Text(rental.returned ? "Returned" : "Active")
                .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(KoiColors.insetFill, in: Capsule())
        }
    }

    private var detailCard: some View {
        VStack(spacing: 0) {
            row("Pickup", KoiFormat.shortDate(rental.pickup))
            hairline
            row("Return", KoiFormat.shortDate(rental.dropoff))
            hairline
            row("Fuel policy", rental.fuelPolicyFullToFull ? "Full → full" : "Prepaid")
            hairline
            row("Excess", rental.excess.map { KoiFormat.money($0) } ?? "—", mono: true)
            hairline
            row("Extra cover (CDW)", rental.cdwTaken ? "Taken" : "No")
        }
        .koiCard(padding: 0)
    }

    private func row(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label).koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
            Spacer()
            Text(value).koiStyle(mono ? .monoMd : .body).foregroundStyle(KoiColors.textPrimary)
        }
        .padding(14)
    }

    private var hairline: some View {
        Rectangle().fill(KoiColors.hairline).frame(height: 1).padding(.horizontal, 14)
    }
}

#Preview {
    let g = Garage.preview
    return NavigationStack { RentalDetailView(rental: g.rentals.first!) }.environmentObject(g)
}
