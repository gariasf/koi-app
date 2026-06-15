import SwiftUI

/// First run — one friendly question sets the model. No login wall.
struct FirstRunView: View {
    @EnvironmentObject private var garage: Garage
    @State private var presented: Relationship?

    var body: some View {
        ZStack {
            KoiColors.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    brand
                        .padding(.top, 44)
                        .padding(.bottom, 36)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Let's add your first car.")
                            .koiStyle(.pageTitle).foregroundStyle(KoiColors.textPrimary)
                        Text("One answer sets sensible defaults. How do you have it?")
                            .koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 18)

                    VStack(spacing: 12) {
                        ForEach(Relationship.allCases) { r in
                            OptionRow(icon: r.icon, title: r.title, subtitle: r.subtitle) {
                                presented = r
                            }
                        }
                    }

                    Text("Lease, finance and subscription share one shape — Koi just sets the right defaults.")
                        .koiStyle(.meta).foregroundStyle(KoiColors.textFaint)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 14)

                    HStack(spacing: 6) {
                        Image(systemName: "lock")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(KoiColors.textSubdued)
                        Text("No account needed · stays on your device")
                            .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, KoiSpace.gutter)
            }
        }
        .sheet(item: $presented) { r in
            switch r {
            case .own:    AddOwnedCarView().environmentObject(garage)
            case .plan:   AddPlanCarView().environmentObject(garage)
            case .borrow: AddRentalView().environmentObject(garage)
            }
        }
    }

    private var brand: some View {
        VStack(spacing: 14) {
            RippleMark(size: 58)
            Text("koi").koiStyle(.wordmark).foregroundStyle(KoiColors.textPrimary)
            Text("your cars, calmly").koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
        }
    }
}

#Preview { FirstRunView().environmentObject(Garage(persists: false)) }
