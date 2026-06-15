import SwiftUI

/// Root router. Empty garage → first run; otherwise → the tabbed app shell.
/// Theme follows the user's choice in Settings (System / Light / Dark).
struct ContentView: View {
    @EnvironmentObject private var garage: Garage
    @AppStorage("koi.theme") private var theme = "system"

    var body: some View {
        Group {
            if garage.isEmpty {
                FirstRunView()
            } else {
                RootTabView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: garage.isEmpty)
        .preferredColorScheme(preferredScheme)
    }

    private var preferredScheme: ColorScheme? {
        switch theme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil   // system
        }
    }
}

#Preview("First run") {
    ContentView().environmentObject(Garage(persists: false)).environmentObject(FuelPriceStore.preview)
}
#Preview("App") {
    ContentView().environmentObject(Garage.preview).environmentObject(FuelPriceStore.preview)
}
