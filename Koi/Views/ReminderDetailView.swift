import SwiftUI

/// A reminder, opened. Context + a calm, one-tap resolve (or a low-guilt snooze).
/// The pattern for every "coming up" item.
struct ReminderDetailView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    let reminder: Reminder

    private var urgency: Urgency { garage.urgency(reminder) }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "Reminder") { dismiss() }

            ScrollView {
                VStack(spacing: 18) {
                    RoundedRectangle(cornerRadius: KoiRadius.tile, style: .continuous)
                        .fill(urgency.tile.bg)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: reminder.kind.icon)
                                .font(.system(size: 26, weight: .regular))
                                .foregroundStyle(urgency.tile.fg)
                        )
                        .padding(.top, 12)

                    VStack(spacing: 6) {
                        Text(reminder.title).koiStyle(.glanceLine).foregroundStyle(KoiColors.textPrimary)
                        Text(reminder.detail).koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
                    }
                    .multilineTextAlignment(.center)

                    Text(garage.countdown(reminder))
                        .koiStyle(.monoMd).foregroundStyle(urgency.countdownColor)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(urgency.tile.bg, in: Capsule())

                    if let date = reminder.dueDate {
                        infoCard(label: "Due", value: date.formatted(.dateTime.day().month(.wide).year()))
                    }

                    if reminder.kind == .insurance, let policy = policyForReminder {
                        policyMiniCard(policy)
                    }

                    Text("No rush — Koi will give you a gentle nudge again closer to the time.")
                        .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.bottom, 12)
            }

            VStack(spacing: 10) {
                KoiPrimaryButton(title: primaryTitle, systemIcon: "checkmark") {
                    garage.resolve(reminder); Haptics.success(); dismiss()
                }
                Button { garage.snooze(reminder); dismiss() } label: {
                    Text("Remind me later").koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, KoiSpace.gutter)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(KoiColors.surface.ignoresSafeArea())
    }

    private var primaryTitle: String {
        switch reminder.kind {
        case .insurance:  return "Mark as renewed"
        case .inspection: return "Mark as passed"
        default:          return "Mark as done"
        }
    }

    private func infoCard(label: String, value: String) -> some View {
        HStack {
            Text(label).koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
            Spacer()
            Text(value).koiStyle(.body).foregroundStyle(KoiColors.textPrimary)
        }
        .koiCard()
    }

    private var policyForReminder: InsurancePolicy? {
        garage.policies.first { $0.carID == reminder.carID }
    }

    private func policyMiniCard(_ p: InsurancePolicy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled").foregroundStyle(KoiColors.sage)
                Text(p.insurer).koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary)
                Spacer()
                Text(p.policyNumber).koiStyle(.monoSm).foregroundStyle(KoiColors.textSecondary)
            }
            HStack(spacing: 10) {
                if let prem = p.premium {
                    Text(KoiFormat.money(prem, code: p.currency) + " / yr")
                        .koiStyle(.monoMd).foregroundStyle(KoiColors.textPrimary)
                }
                if let last = p.premiumLastYear {
                    Text("last year " + KoiFormat.money(last, code: p.currency))
                        .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                }
                Spacer(minLength: 0)
            }
        }
        .koiCard()
    }
}

private extension Urgency {
    var tile: GlanceTint {
        switch self {
        case .neutral:  return .neutral
        case .comingUp: return .ochre
        case .overdue:  return .red
        }
    }
    var countdownColor: Color {
        switch self {
        case .neutral:  return KoiColors.textSubdued
        case .comingUp: return KoiColors.ochreText
        case .overdue:  return KoiColors.red
        }
    }
}

#Preview {
    let g = Garage.preview
    return ReminderDetailView(reminder: g.comingUp.first!).environmentObject(g)
}
