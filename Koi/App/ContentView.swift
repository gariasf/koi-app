import SwiftUI

/// Root router. Empty garage → first run; otherwise → the tabbed app shell.
/// Carries a small dev-only light/dark toggle (remove once navigation matures).
struct ContentView: View {
    @EnvironmentObject private var garage: Garage
    @State private var schemeOverride: ColorScheme?

    var body: some View {
        Group {
            if garage.isEmpty {
                FirstRunView()
            } else {
                RootTabView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: garage.isEmpty)
        .preferredColorScheme(schemeOverride)
        .overlay(alignment: .topTrailing) { schemeToggle }
    }

    private var schemeToggle: some View {
        Button {
            switch schemeOverride {
            case .none:   schemeOverride = .light
            case .light:  schemeOverride = .dark
            case .dark:   schemeOverride = nil
            @unknown default: schemeOverride = nil
            }
        } label: {
            Image(systemName: toggleSymbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(KoiColors.textSubdued)
                .padding(8)
        }
        .padding(.top, 50)
        .padding(.trailing, 10)
        .accessibilityLabel("Toggle color scheme (scaffold)")
    }

    private var toggleSymbol: String {
        switch schemeOverride {
        case .none:  return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark:  return "moon"
        @unknown default: return "circle.lefthalf.filled"
        }
    }
}

#Preview("First run") { ContentView().environmentObject(Garage(persists: false)) }
#Preview("App · light") { ContentView().environmentObject(Garage.preview).preferredColorScheme(.light) }
#Preview("App · dark") { ContentView().environmentObject(Garage.preview).preferredColorScheme(.dark) }
