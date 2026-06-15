import SwiftUI
import UIKit

/// Labeled form field — eyebrow label + bordered fill (radius 10, 1px ring), optional hint.
struct KoiField: View {
    let label: String
    var placeholder: String = ""
    @Binding var text: String
    var mono: Bool = false
    var keyboard: UIKeyboardType = .default
    var hint: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).koiStyle(.eyebrow).foregroundStyle(KoiColors.textSubdued)
            TextField(placeholder, text: $text)
                .koiStyle(mono ? .monoMd : .body)
                .foregroundStyle(KoiColors.textPrimary)
                .keyboardType(keyboard)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(KoiColors.fieldFill, in: RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous)
                        .strokeBorder(KoiColors.border, lineWidth: 1)
                )
            if let hint {
                Text(hint).koiStyle(.meta).foregroundStyle(KoiColors.textFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Full-width primary action (sage, white label). The Log/Save button language.
struct KoiPrimaryButton: View {
    let title: String
    var systemIcon: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemIcon {
                    Image(systemName: systemIcon).font(.system(size: 16, weight: .medium))
                }
                Text(title).koiStyle(.listTitle)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                KoiColors.sage.opacity(enabled ? 1 : 0.4),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .disabled(!enabled)
    }
}

/// The visual content of an option row (icon tile + title + subtitle + chevron) on a card.
/// Split from the button form so it can also back a `NavigationLink`.
struct OptionRowContent: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemName: icon, tint: .neutral)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary)
                Text(subtitle)
                    .koiStyle(.meta).foregroundStyle(KoiColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(KoiColors.textSubdued)
        }
        .koiCard()
    }
}

/// Tappable option row (button form).
struct OptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            OptionRowContent(icon: icon, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }
}

/// A labeled toggle row (sage = on). Used in grouped "what's included" cards.
struct KoiToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).koiStyle(.body).foregroundStyle(KoiColors.textPrimary)
                if let subtitle {
                    Text(subtitle).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(KoiColors.sage)
        }
    }
}

/// Modal nav row: Cancel (leading) + centered title, hairline underline.
/// Centered sheet title. Sheets dismiss via the drag handle (swipe down) — no redundant
/// Cancel/Done button.
struct ModalHeader: View {
    let title: String

    var body: some View {
        Text(title).koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, KoiSpace.gutter)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(KoiColors.hairline).frame(height: 1)
            }
    }
}
