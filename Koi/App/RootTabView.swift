import SwiftUI

enum KoiTab { case glance, garage }

/// The app shell once a car exists: Glance ⇄ Garage via a custom bottom bar,
/// with a raised central ＋ Log that presents the quick-add sheet for the active car.
struct RootTabView: View {
    @EnvironmentObject private var garage: Garage
    @EnvironmentObject private var fuel: FuelPriceStore
    @State private var tab: KoiTab =
        ProcessInfo.processInfo.arguments.contains("-garage") ? .garage : .glance
    @State private var showLog = false
    @State private var devScreen: String? = RootTabView.devScreenArg()
    @State private var garagePath = NavigationPath()

    var body: some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
            .sheet(isPresented: $showLog) {
                if let car = garage.activeCar {
                    LogSheetView(car: car)
                        .environmentObject(garage)
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: Binding(get: { devScreen != nil },
                                        set: { if !$0 { devScreen = nil } })) {
                devScreenContent.presentationDragIndicator(.visible)
            }
    }

    // Dev-only deep-links for screenshots: launch with `-screen <name>`.
    private static func devScreenArg() -> String? {
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-screen"), i + 1 < a.count { return a[i + 1] }
        if a.contains("-vault") { return "vault" }
        return nil
    }

    @ViewBuilder private var devScreenContent: some View {
        switch devScreen {
        case "log":          if let c = garage.activeCar { LogSheetView(car: c).environmentObject(garage) }
        case "cardetail":    if let c = garage.residents.first { NavigationStack { CarDetailView(car: c).environmentObject(garage) } }
        case "cardetailsub": if let c = garage.residents.last { NavigationStack { CarDetailView(car: c).environmentObject(garage) } }
        case "addplan":      NavigationStack { AddPlanCarView().environmentObject(garage) }
        case "addowned":     NavigationStack { AddOwnedCarView().environmentObject(garage) }
        case "editcar":      if let c = garage.residents.first { EditCarView(car: c).environmentObject(garage) }
        case "editcarsub":   if let c = garage.residents.last { EditCarView(car: c).environmentObject(garage) }
        case "addrental":    NavigationStack { AddRentalView().environmentObject(garage) }
        case "settings":     SettingsView().environmentObject(fuel)
        case "vault":        if let c = garage.residents.first { InsuranceVaultView(car: c).environmentObject(garage) }
        case "reminder":     if let r = garage.comingUp.first { ReminderDetailView(reminder: r).environmentObject(garage) }
        case "firstrun":     FirstRunView().environmentObject(garage)
        default:             EmptyView()
        }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .glance:
            GlanceView()
        case .garage:
            NavigationStack(path: $garagePath) { GarageView() }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(.glance, label: "Glance") {
                RippleMark(size: 24, color: tab == .glance ? KoiColors.sage : KoiColors.textSubdued)
            }
            logButton.frame(width: 76)
            tabButton(.garage, label: "Garage") {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(tab == .garage ? KoiColors.textPrimary : KoiColors.textSubdued)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(KoiColors.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(KoiColors.hairline).frame(height: 1)
        }
    }

    private func tabButton<Icon: View>(_ target: KoiTab,
                                       label: String,
                                       @ViewBuilder icon: () -> Icon) -> some View {
        Button {
            if tab == target {
                if target == .garage { garagePath = NavigationPath() }   // re-tap active tab → back to list
            } else {
                tab = target
            }
        } label: {
            VStack(spacing: 4) {
                icon()
                Text(label).koiStyle(.tabLabel)
                    .foregroundStyle(tab == target ? KoiColors.textPrimary : KoiColors.textSubdued)
            }
            .frame(maxWidth: .infinity, minHeight: 48)   // full-width, generous tap target
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var logButton: some View {
        Button { showLog = true } label: {
            Circle()
                .fill(KoiColors.sage)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                )
                .shadow(color: KoiColors.sage.opacity(0.35), radius: 10, x: 0, y: 4)
                .offset(y: -20)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log")
    }
}

#Preview { RootTabView().environmentObject(Garage.preview).environmentObject(FuelPriceStore.preview) }
