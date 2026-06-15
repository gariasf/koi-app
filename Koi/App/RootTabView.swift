import SwiftUI

enum KoiTab { case glance, garage }

/// The app shell once a car exists: Glance ⇄ Garage via a custom bottom bar,
/// with a raised central ＋ Log that presents the quick-add sheet for the active car.
struct RootTabView: View {
    @EnvironmentObject private var garage: Garage
    @State private var tab: KoiTab =
        ProcessInfo.processInfo.arguments.contains("-garage") ? .garage : .glance
    @State private var showLog = false

    var body: some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
            .sheet(isPresented: $showLog) {
                if let car = garage.activeCar {
                    LogSheetView(car: car)
                        .environmentObject(garage)
                        .presentationDragIndicator(.visible)
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .glance:
            GlanceAllClearView()
        case .garage:
            NavigationStack { GarageView() }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(.glance, label: "Glance") {
                RippleMark(size: 24, color: tab == .glance ? KoiColors.sage : KoiColors.textSubdued)
            }
            Spacer(minLength: 0)
            logButton
            Spacer(minLength: 0)
            tabButton(.garage, label: "Garage") {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(tab == .garage ? KoiColors.textPrimary : KoiColors.textSubdued)
            }
        }
        .padding(.horizontal, 44)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(KoiColors.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(KoiColors.hairline).frame(height: 1)
        }
    }

    private func tabButton<Icon: View>(_ target: KoiTab,
                                       label: String,
                                       @ViewBuilder icon: () -> Icon) -> some View {
        Button { tab = target } label: {
            VStack(spacing: 4) {
                icon()
                Text(label).koiStyle(.tabLabel)
                    .foregroundStyle(tab == target ? KoiColors.textPrimary : KoiColors.textSubdued)
            }
        }
        .buttonStyle(.plain)
    }

    private var logButton: some View {
        Button { showLog = true } label: {
            Circle()
                .fill(KoiColors.sage)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                )
                .shadow(color: KoiColors.sage.opacity(0.35), radius: 10, x: 0, y: 4)
                .offset(y: -16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log")
    }
}

#Preview { RootTabView().environmentObject(Garage.preview) }
