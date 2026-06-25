import SwiftUI

enum KoiTab { case glance, timeline, log, garage }

/// The app shell once a car exists.
/// iOS 26+: the genuine native Liquid Glass tab bar — Glance · Garage as glass tabs, with Log as
/// the detached glass circle beside them (the `.search`-role slot, the Withings shape).
/// Earlier iOS: a custom floating glass capsule + detached Log circle, with swipe + spring slide.
/// Either way, Log is an action: it opens the quick-add sheet rather than being a destination.
struct RootTabView: View {
    @EnvironmentObject private var garage: Garage
    @EnvironmentObject private var fuel: FuelPriceStore
    @EnvironmentObject private var router: AppRouter
    @State private var tab: KoiTab = {
        let a = ProcessInfo.processInfo.arguments
        if a.contains("-garage") { return .garage }
        if a.contains("-story") { return .timeline }
        return .glance
    }()
    @State private var showLog = false
    @State private var devScreen: String? = RootTabView.devScreenArg()
    @State private var garagePath = NavigationPath()
    @Namespace private var tabNS

    var body: some View {
        shell
            .sheet(isPresented: $showLog) {
                if let car = garage.activeCar {
                    LogSheetView(car: car)
                        .environmentObject(garage)
                        .environmentObject(fuel)
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: Binding(get: { devScreen != nil },
                                        set: { if !$0 { devScreen = nil } })) {
                devScreenContent.presentationDragIndicator(.visible)
            }
            .overlay(alignment: .top) { toastLayer }
            .animation(.spring(duration: 0.35), value: router.toast)
            // A deep modal (MyCar import) can ask to land the user on the Garage.
            .onChange(of: router.gotoGarage) { _, _ in
                tab = .garage
                garagePath = NavigationPath()
            }
    }

    @ViewBuilder private var toastLayer: some View {
        if let t = router.toast {
            KoiToast(text: t.text)
                .id(t.id)
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: t.id) {
                    try? await Task.sleep(nanoseconds: 2_400_000_000)
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if router.toast?.id == t.id { router.toast = nil }
                    }
                }
        }
    }

    @ViewBuilder private var shell: some View {
        if #available(iOS 26.0, *) {
            nativeShell
        } else {
            legacyShell
        }
    }

    // MARK: iOS 26 — genuine native Liquid Glass tab bar + detached `.search` Log circle
    @available(iOS 26.0, *)
    private var nativeShell: some View {
        TabView(selection: $tab) {
            Tab("Glance", systemImage: "smallcircle.filled.circle", value: KoiTab.glance) {
                GlanceView()
            }
            Tab("Story", image: "ph-story", value: KoiTab.timeline) {
                TimelineView()
            }
            Tab("Garage", image: "ph-garage", value: KoiTab.garage) {
                NavigationStack(path: $garagePath) { GarageView() }
            }
            Tab("Log", image: "ph-log", value: KoiTab.log, role: .search) {
                Color.clear
            }
        }
        .tint(KoiColors.sage)
        .onChange(of: tab) { old, new in
            if new == .log {
                tab = old                       // Log is an action — bounce back + open the sheet
                showLog = true
            } else if old != new {
                garagePath = NavigationPath()
            }
        }
    }

    // MARK: pre-iOS-26 fallback — custom floating glass capsule + detached Log circle, paged content
    private var legacyShell: some View {
        legacyContent
            .safeAreaInset(edge: .bottom, spacing: 0) { legacyTabBar }
            .onChange(of: tab) { _, _ in garagePath = NavigationPath() }
    }

    private var legacyContent: some View {
        TabView(selection: $tab) {
            GlanceView()
                .tag(KoiTab.glance)
            TimelineView()
                .tag(KoiTab.timeline)
            NavigationStack(path: $garagePath) { GarageView() }
                .tag(KoiTab.garage)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var legacyTabBar: some View {
        HStack(spacing: 10) {
            navCapsule
            logCircle
        }
        .padding(.horizontal, KoiSpace.gutter)
        .padding(.top, 6)
    }

    private var navCapsule: some View {
        HStack(spacing: 2) {
            navTab(.glance, label: "Glance") {
                RippleMark(size: 22, color: tab == .glance ? KoiColors.sage : KoiColors.textSubdued)
            }
            navTab(.timeline, label: "Story") {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(tab == .timeline ? KoiColors.textPrimary : KoiColors.textSubdued)
            }
            navTab(.garage, label: "Garage") {
                Image(systemName: "car.2.fill")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(tab == .garage ? KoiColors.textPrimary : KoiColors.textSubdued)
            }
        }
        .padding(5)
        .frame(maxWidth: .infinity)
        .modifier(KoiGlassCapsule())
    }

    private func navTab<Icon: View>(_ target: KoiTab, label: String, @ViewBuilder icon: () -> Icon) -> some View {
        Button {
            if tab == target {
                if target == .garage { garagePath = NavigationPath() }
            } else {
                withAnimation(.snappy(duration: 0.3)) { tab = target }
            }
        } label: {
            VStack(spacing: 3) {
                icon().frame(height: 24)
                Text(label).koiStyle(.tabLabel)
                    .foregroundStyle(tab == target ? KoiColors.textPrimary : KoiColors.textSubdued)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if tab == target {
                    Capsule().fill(KoiColors.container.opacity(0.6))
                        .matchedGeometryEffect(id: "koiActiveTab", in: tabNS)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var logCircle: some View {
        Button { showLog = true } label: {
            Image(systemName: "pencil")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .modifier(KoiGlassLogCircle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log")
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
        case "log":          if let c = garage.activeCar { LogSheetView(car: c).environmentObject(garage).environmentObject(fuel) }
        case "cardetail":    if let c = garage.residents.first { NavigationStack { CarDetailView(car: c).environmentObject(garage) } }
        case "cardetailsub": if let c = garage.residents.last { NavigationStack { CarDetailView(car: c).environmentObject(garage) } }
        case "addplan":      NavigationStack { AddPlanCarView().environmentObject(garage) }
        case "addowned":     NavigationStack { AddOwnedCarView().environmentObject(garage) }
        case "editcar":      if let c = garage.residents.first { EditCarView(car: c).environmentObject(garage) }
        case "editcarsub":   if let c = garage.residents.last { EditCarView(car: c).environmentObject(garage) }
        case "settings":     SettingsView().environmentObject(fuel)
        case "privacy":      PrivacyPolicyView()
        case "adddoc":       if let c = garage.residents.first { AddDocumentView(car: c).environmentObject(garage) }
        case "import":       MyCarImportView().environmentObject(garage)
        case "vault":        if let c = garage.residents.first { InsuranceVaultView(car: c).environmentObject(garage) }
        case "reminder":     if let r = garage.activeReminders.first(where: { $0.kind == .mileageCap }) ?? garage.comingUp.first ?? garage.nextHorizon { ReminderDetailView(reminder: r).environmentObject(garage) }
        case "mileagehistory": if let c = garage.residents.first(where: { (garage.plan(for: $0)?.mileageCapPerMonth ?? 0) > 0 }) { MileageHistoryView(car: c).environmentObject(garage) }
        case "firstrun":     FirstRunView().environmentObject(garage)
        default:             EmptyView()
        }
    }
}

/// The nav capsule's surface — genuine Liquid Glass on iOS 26, blur material fallback.
private struct KoiGlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(KoiColors.ring, lineWidth: 1))
        }
    }
}

/// The detached Log action — sage-tinted Liquid Glass on iOS 26, solid sage fallback.
private struct KoiGlassLogCircle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(KoiColors.sage).interactive(), in: Circle())
        } else {
            content.background(KoiColors.sage, in: Circle())
        }
    }
}

#Preview { RootTabView().environmentObject(Garage.preview).environmentObject(FuelPriceStore.preview).environmentObject(AppRouter()) }
