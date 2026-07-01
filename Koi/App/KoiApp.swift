import SwiftUI

@main
struct KoiApp: App {
    @StateObject private var garage = Garage()
    @StateObject private var router = AppRouter()
    @StateObject private var units = Units()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(garage)
                .environmentObject(router)
                .environmentObject(units)
        }
    }
}
