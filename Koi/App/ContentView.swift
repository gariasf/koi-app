import SwiftUI

/// Scaffold host. Shows the Glance all-clear proof screen and carries a small
/// dev-only affordance to flip light/dark on device (system · light · dark).
/// Remove `schemeToggle` once real navigation lands.
struct ContentView: View {
    @State private var schemeOverride: ColorScheme? = nil

    var body: some View {
        GlanceAllClearView()
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

#Preview("Light") { ContentView().preferredColorScheme(.light) }
#Preview("Dark")  { ContentView().preferredColorScheme(.dark) }
