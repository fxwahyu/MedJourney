//
//  MedicineViewModel.swift
//  MedJourney
//

import SwiftUI
import SwiftData

/// Form state and actions for adding and managing medicines.
@Observable
final class MedicineViewModel {

    // MARK: - Form State

    var name: String = ""
    var dose: String = ""
    var notes: String = ""
    var notificationTimes: [String] = []

    var showTimePicker = false
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
        let trimmedDose = dose.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let combinedNotes = [trimmedDose, trimmedNotes]
            .filter { !$0.isEmpty }
            .joined(separator: " — ")

        let medicine = Medicine(
            name: name.trimmingCharacters(in: .whitespaces),
            notes: combinedNotes,
            notificationTimesRaw: notificationTimes.joined(separator: ","),
            isActive: true
        )
        context.insert(medicine)

        Task {
            if await NotificationService.shared.requestPermission() {
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
        }
        if medicine.isActive {
            NotificationService.shared.scheduleMedicineReminders(for: medicine)
        } else {
            NotificationService.shared.cancelMedicineReminders(for: medicine)
        }
    }
}
