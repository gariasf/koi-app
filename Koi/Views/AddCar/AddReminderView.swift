import SwiftUI

/// Add a reminder to a car (service / inspection / insurance). Mileage-cap reminders are
/// derived from a plan, not added by hand.
struct AddReminderView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    let car: Car

    @State private var kind: ReminderKind = .service
    @State private var title = ""
    @State private var dueDate = Date().addingTimeInterval(30 * 86_400)

    private let kinds: [ReminderKind] = [.service, .inspection, .insurance]
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "New reminder") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    kindPicker
                    KoiField(label: "Title", placeholder: titlePlaceholder, text: $title)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Due").koiStyle(.eyebrow).foregroundStyle(KoiColors.textSubdued)
                        DatePicker("", selection: $dueDate, displayedComponents: .date)
                            .labelsHidden().tint(KoiColors.sage)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 18)
                .padding(.bottom, 12)
            }
            KoiPrimaryButton(title: "Save reminder", enabled: canSave) { save() }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var kindPicker: some View {
        HStack(spacing: 4) {
            ForEach(kinds, id: \.self) { k in
                Button { kind = k } label: {
                    Text(kindLabel(k)).koiStyle(.meta)
                        .foregroundStyle(kind == k ? .white : KoiColors.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background { if kind == k { Capsule().fill(KoiColors.sage) } }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(KoiColors.insetFill, in: Capsule())
    }

    private func kindLabel(_ k: ReminderKind) -> String {
        switch k {
        case .service:    return "Service"
        case .inspection: return "Inspection"
        case .insurance:  return "Insurance"
        case .mileageCap: return "Mileage"
        }
    }

    private var titlePlaceholder: String {
        switch kind {
        case .service:    return "Oil & filter service"
        case .inspection: return "ITV inspection"
        case .insurance:  return "Insurance renewal"
        case .mileageCap: return "Mileage this month"
        }
    }

    private func save() {
        garage.addReminder(Reminder(carID: car.id, kind: kind,
                                    title: title.trimmingCharacters(in: .whitespaces),
                                    detail: car.displayName, dueDate: dueDate))
        Haptics.success()
        dismiss()
    }
}

#Preview { AddReminderView(car: Garage.preview.residents.first!).environmentObject(Garage.preview) }
