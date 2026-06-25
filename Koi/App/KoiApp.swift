import SwiftUI

@main
struct KoiApp: App {
    @StateObject private var garage = Garage()
    @StateObject private var fuel = FuelPriceStore()
    @StateObject private var location = LocationProvider()
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(garage)
                .environmentObject(fuel)
                .environmentObject(location)
                .environmentObject(router)
        }
    }
}
