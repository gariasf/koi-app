import SwiftUI

@main
struct KoiApp: App {
    @StateObject private var garage = Garage()
    @StateObject private var fuel = FuelPriceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(garage)
                .environmentObject(fuel)
        }
    }
}
