import SwiftUI

/// Minimal settings — appearance, display units, and your data.
struct SettingsView: View {
    @EnvironmentObject private var units: Units
    @EnvironmentObject private var garage: Garage
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @AppStorage("koi.theme") private var theme = "system"
    @State private var confirmErase = false
    @State private var exportURL: URL?
    @State private var showPrivacy = false
    @State private var showImport = false

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "Settings")
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    appearanceSection
                    unitsSection
                    dataSection
                    footer
                    versionLine
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .task { exportURL = garage.exportJSON() }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Appearance")
            Picker("Appearance", selection: $theme) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
        }
    }

    private var unitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow(text: "Units")
            unitPickerRow("Distance") {
                Picker("Distance", selection: $units.distance) {
                    ForEach(DistanceUnit.allCases) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented)
            }
            unitPickerRow("Fuel economy") {
                Picker("Fuel economy", selection: $units.economy) {
                    ForEach(EconomyUnit.allCases) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented)
            }
            unitPickerRow("Volume") {
                Picker("Volume", selection: $units.volume) {
                    ForEach(VolumeUnit.allCases) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented)
            }
            unitPickerRow("Currency") {
                Menu {
                    ForEach(Self.currencyChoices, id: \.self) { c in
                        Button(currencyLabel(c)) { units.currencyCode = c }
                    }
                } label: {
                    HStack {
                        Text(currencyLabel(units.currencyCode)).koiStyle(.body).foregroundStyle(KoiColors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(KoiColors.textSubdued)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(KoiColors.fieldFill, in: RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous).strokeBorder(KoiColors.border, lineWidth: 1))
                }
            }
            Text("Default from your device’s region — change anytime.")
                .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
        }
    }

    private func unitPickerRow<P: View>(_ label: String, @ViewBuilder picker: () -> P) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).koiStyle(.body).foregroundStyle(KoiColors.textPrimary)
            picker()
        }
    }

    private static let currencyChoices = ["EUR", "USD", "GBP", "NOK", "SEK", "DKK", "CHF", "CAD", "AUD", "JPY"]
    private func currencyLabel(_ code: String) -> String {
        let sym = ["EUR": "€", "USD": "$", "GBP": "£", "NOK": "kr", "SEK": "kr", "DKK": "kr",
                   "CHF": "Fr", "CAD": "$", "AUD": "$", "JPY": "¥"][code] ?? code
        return "\(code) \(sym)"
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Your data")
            Text("Koi keeps your cars, plans, costs, photos, reminders and any insurance details on this device. Nothing leaves your phone. No account, no servers, no personal data.")
                .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                Button { showImport = true } label: {
                    actionRow(icon: "square.and.arrow.down", title: "Import from MyCar", tint: KoiColors.textPrimary)
                }
                .buttonStyle(.plain)
                Rectangle().fill(KoiColors.hairline).frame(height: 1).padding(.horizontal, 14)
                Link(destination: URL(string: "mailto:hello@gariasf.com")!) {
                    actionRow(icon: "envelope", title: "Contact us", tint: KoiColors.textPrimary)
                }
                Rectangle().fill(KoiColors.hairline).frame(height: 1).padding(.horizontal, 14)
                Button { showPrivacy = true } label: {
                    actionRow(icon: "hand.raised", title: "Privacy policy", tint: KoiColors.textPrimary)
                }
                .buttonStyle(.plain)
                Rectangle().fill(KoiColors.hairline).frame(height: 1).padding(.horizontal, 14)
                if let exportURL {
                    ShareLink(item: exportURL) {
                        actionRow(icon: "square.and.arrow.up", title: "Export my data", tint: KoiColors.sageText)
                    }
                    Rectangle().fill(KoiColors.hairline).frame(height: 1).padding(.horizontal, 14)
                }
                Button(role: .destructive) { confirmErase = true } label: {
                    actionRow(icon: "trash", title: "Delete all data", tint: KoiColors.red)
                }
                .buttonStyle(.plain)
            }
            .koiCard(padding: 0)
        }
        .confirmationDialog("Delete everything?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Delete all data", role: .destructive) { garage.eraseAll(); Haptics.success(); dismiss() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes every car, plan, log and document from this device, and can’t be undone.")
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacyPolicyView().presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showImport) {
            MyCarImportView().environmentObject(garage).presentationDragIndicator(.visible)
        }
        // Import finished and asked to route to the Garage — close Settings so it shows through.
        .onChange(of: router.gotoGarage) { _, _ in dismiss() }
    }

    private func actionRow(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(tint).frame(width: 24)
            Text(title).koiStyle(.body).foregroundStyle(tint)
            Spacer()
        }
        .padding(14)
        .contentShape(Rectangle())
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock").font(.system(size: 12)).foregroundStyle(KoiColors.textSubdued)
            Text("Everything stays on this device and in your private iCloud backup. Koi has no servers of its own.")
                .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    // App version + build — handy when someone reports an issue.
    private var versionLine: some View {
        Text("Koi \(Self.appVersion)")
            .koiStyle(.meta).foregroundStyle(KoiColors.textFaint)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
    }

    static var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(v) (\(b))"
    }
}

#Preview { SettingsView().environmentObject(Units.preview).environmentObject(Garage.preview).environmentObject(AppRouter()) }
