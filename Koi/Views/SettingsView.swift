import SwiftUI

/// Minimal settings — fuel product + region (province) for the live price feed.
struct SettingsView: View {
    @EnvironmentObject private var fuel: FuelPriceStore
    @EnvironmentObject private var garage: Garage
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
                    if fuel.available { regionSection }
                    dataSection
                    footer
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .onChange(of: fuel.provinceID) { Task { await fuel.refresh() } }
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
            Text("Prices come from the Spanish government’s open feed (minetur), and are kept on your device.")
                .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Your data")
            Text(fuel.available
                 ? "Koi keeps your cars, plans, costs, photos, reminders and any insurance details on this device. The only thing it sends is your chosen region, so it can fetch local fuel prices from the Spanish government feed. No account, no personal data."
                 : "Koi keeps your cars, plans, costs, photos, reminders and any insurance details on this device. Nothing leaves your phone — no account, no servers, no personal data.")
                .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                Button { showImport = true } label: {
                    actionRow(icon: "square.and.arrow.down", title: "Import from MyCar", tint: KoiColors.textPrimary)
                }
                .buttonStyle(.plain)
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
}

#Preview { SettingsView().environmentObject(FuelPriceStore.preview) }
