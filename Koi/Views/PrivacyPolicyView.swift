import SwiftUI

/// The privacy policy, shown in-app (Settings → Privacy). Mirrors `docs/privacy-policy.md`,
/// which is the same text hosted for the App Store Connect "privacy policy URL" field.
struct PrivacyPolicyView: View {
    @Environment(\.openURL) private var openURL

    /// The hosted copy of this policy. Set this to your GitHub Pages (or other) URL before
    /// submitting, and use the same URL in App Store Connect. Until then the in-app text stands.
    private let onlineURL = URL(string: "https://koi.gariasf.com/privacy-policy")

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "Privacy")
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Koi keeps everything on your device. There's no account, no sign-in, and no Koi server, so there's nothing for us to collect, see, or sell.")
                        .koiStyle(.body).foregroundStyle(KoiColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    section("What stays on your device",
                            "Your cars, plans, costs, fuel logs, photos, reminders and any insurance details live only on this iPhone, and in your own encrypted iCloud device backup, which only you can access. Photos are downscaled and stripped of location/EXIF metadata when you add them.")
                    section("Nothing leaves your device",
                            "Koi has no servers and makes no network requests of its own. Your data is never uploaded, shared, or sent anywhere — it simply lives on your iPhone.")
                    section("No tracking",
                            "Koi has no advertising, no analytics, and no third-party tracking. It doesn't track you across other apps or websites.")
                    section("Data we collect",
                            "None. On the App Store this is declared as “Data Not Collected.”")
                    section("Your control",
                            "Your data is yours and on your device: export it (Settings → Export my data) or erase all of it (Settings → Delete all data) at any time. Removing the app also removes its data.")
                    section("Children", "Koi is a general-audience app and is not directed at children.")
                    section("Contact", "Questions about privacy? Email hello@gariasf.com.")

                    if let onlineURL {
                        Button { openURL(onlineURL) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "safari").font(.system(size: 13, weight: .semibold))
                                Text("View this policy online").koiStyle(.body)
                            }
                            .foregroundStyle(KoiColors.sageText)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }

                    Text("Last updated 16 June 2026")
                        .koiStyle(.meta).foregroundStyle(KoiColors.textFaint)
                        .padding(.top, 4)
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .background(KoiColors.surface.ignoresSafeArea())
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: title)
            Text(body)
                .koiStyle(.meta).foregroundStyle(KoiColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview { PrivacyPolicyView() }
