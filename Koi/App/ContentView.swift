import SwiftUI
import UIKit

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
        .onAppear { applyTheme() }
        .onChange(of: theme) { applyTheme() }
    }

    /// Override the window's interface style — applies the theme everywhere, including
    /// sheets (which don't reliably inherit `.preferredColorScheme`).
    private func applyTheme() {
        let style: UIUserInterfaceStyle = theme == "light" ? .light : (theme == "dark" ? .dark : .unspecified)
        for scene in UIApplication.shared.connectedScenes {
            (scene as? UIWindowScene)?.windows.forEach { $0.overrideUserInterfaceStyle = style }
        }
    }
}

#Preview("First run") {
    ContentView().environmentObject(Garage(persists: false)).environmentObject(FuelPriceStore.preview)
}
#Preview("App") {
    ContentView().environmentObject(Garage.preview).environmentObject(FuelPriceStore.preview)
}
