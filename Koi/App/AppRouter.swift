import SwiftUI

/// App-wide light router: a transient toast plus a one-shot "go to Garage" pulse — so a deep modal
/// (the MyCar import, nested inside Settings) can land the user on the Garage and confirm the result,
/// without threading callbacks through every sheet.
final class AppRouter: ObservableObject {
    struct Toast: Equatable, Identifiable { let id = UUID(); let text: String }

    @Published var toast: Toast?
    @Published var gotoGarage = 0   // bump to request the Garage tab (and tear down open modals)

    /// Call after a successful import: route to the Garage and raise a confirmation toast.
    func importSucceeded(_ text: String) {
        gotoGarage += 1
        toast = Toast(text: text)
    }
}
