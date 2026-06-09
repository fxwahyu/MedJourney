import SwiftUI
import SwiftData

@Observable
final class MedicineViewModel {

    // MARK: - Form State

    var name: String = ""
    var dose: String = ""
    var notes: String = ""
    var notificationTimes: [String] = []

    // Legacy Date-based picker (kept for compat)
    var newTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    var showTimePicker = false

    // Custom wheel picker state
    var pickerHour: Int = 8
    var pickerMinute: Int = 0

    var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions

    func addCurrentTime() {
        let timeString = String(format: "%02d:%02d", pickerHour, pickerMinute)
        guard !notificationTimes.contains(timeString) else { return }
        withAnimation { notificationTimes.append(timeString) }
        notificationTimes.sort()
    }

    func removeTime(at offsets: IndexSet) {
        withAnimation { notificationTimes.remove(atOffsets: offsets) }
    }

    func saveMedicine(context: ModelContext) {
        // Combine dose into notes if dose is filled
        let combinedNotes: String
        if dose.trimmingCharacters(in: .whitespaces).isEmpty {
            combinedNotes = notes.trimmingCharacters(in: .whitespaces)
        } else {
            let notesText = notes.trimmingCharacters(in: .whitespaces)
            combinedNotes = notesText.isEmpty
                ? dose.trimmingCharacters(in: .whitespaces)
                : "\(dose.trimmingCharacters(in: .whitespaces)) — \(notesText)"
        }

        let medicine = Medicine(
            name: name.trimmingCharacters(in: .whitespaces),
            notes: combinedNotes,
            notificationTimesRaw: notificationTimes.joined(separator: ","),
            isActive: true
        )
        context.insert(medicine)
        Task {
            let granted = await NotificationService.shared.requestPermission()
            if granted {
                NotificationService.shared.scheduleMedicineReminders(for: medicine)
            }
        }
    }

    func deleteMedicine(_ medicine: Medicine, context: ModelContext) {
        NotificationService.shared.cancelMedicineReminders(for: medicine)
        context.delete(medicine)
    }

    func toggleActive(_ medicine: Medicine) {
        withAnimation {
            medicine.isActive.toggle()
            medicine.updatedAt = Date()
        }
        if medicine.isActive {
            NotificationService.shared.scheduleMedicineReminders(for: medicine)
        } else {
            NotificationService.shared.cancelMedicineReminders(for: medicine)
        }
    }
}

extension Medicine {
    var updatedAt: Date {
        get { startDate }
        set { startDate = newValue }
    }
}
