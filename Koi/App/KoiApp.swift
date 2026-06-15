import SwiftUI

@main
struct KoiApp: App {
    @StateObject private var garage = Garage()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(garage)
        }
    }
}
