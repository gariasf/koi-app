import SwiftUI

/// Minimal settings — fuel product + region (province) for the live price feed.
struct SettingsView: View {
    @EnvironmentObject private var fuel: FuelPriceStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("koi.theme") private var theme = "system"

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "Settings")
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    appearanceSection
                    fuelTypeSection
                    regionSection
                    footer
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .preferredColorScheme(themeScheme)
        .onChange(of: fuel.provinceID) { Task { await fuel.refresh() } }
    }

    private var themeScheme: ColorScheme? {
        switch theme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Appearance")
            HStack(spacing: 4) {
                seg("System", active: theme == "system") { theme = "system" }
                seg("Light", active: theme == "light") { theme = "light" }
                seg("Dark", active: theme == "dark") { theme = "dark" }
            }
            .padding(4)
            .background(KoiColors.insetFill, in: Capsule())
        }
    }

    private var fuelTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Fuel price")
            HStack(spacing: 4) {
                seg("Diesel", active: fuel.product == .diesel) { fuel.product = .diesel }
                seg("Petrol", active: fuel.product == .petrol) { fuel.product = .petrol }
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

    private var regionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Region")
            Menu {
                ForEach(Province.all) { p in
                    Button(p.name) { fuel.setProvince(p.id) }
                }
            } label: {
                HStack {
                    Text(fuel.provinceName).koiStyle(.body).foregroundStyle(KoiColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(KoiColors.textSubdued)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(KoiColors.fieldFill, in: RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous).strokeBorder(KoiColors.border, lineWidth: 1))
            }
            Text("Prices come from the Spanish government open feed (minetur), cached on device.")
                .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock").font(.system(size: 12)).foregroundStyle(KoiColors.textSubdued)
            Text("Everything stays on your device.").koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
        }
        .padding(.top, 4)
    }
}

#Preview { SettingsView().environmentObject(FuelPriceStore.preview) }
