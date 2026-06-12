import UserNotifications
import Foundation

final class NotificationService: NSObject {
    static let shared = NotificationService()

    // Notification category / action identifiers
    static let categoryID  = "MEDICINE_REMINDER"
    static let takenAction = "DOSE_TAKEN"
    static let skipAction  = "DOSE_SKIP"

    private override init() {
        super.init()
        registerCategories()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional: return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default: return false
        }
    }

    // MARK: - Register actionable categories (Skip / Taken)

    private func registerCategories() {
        let taken = UNNotificationAction(
            identifier: Self.takenAction,
            title: "Taken ✓",
            options: [.foreground]
        )
        let skip = UNNotificationAction(
            identifier: Self.skipAction,
            title: "Skip",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [taken, skip],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Schedule

    func scheduleMedicineReminders(for medicine: Medicine) {
        let center = UNUserNotificationCenter.current()
        for timeString in medicine.notificationTimes {
            let parts = timeString.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { continue }

            var comps = DateComponents()
            comps.hour   = parts[0]
            comps.minute = parts[1]

            let content = UNMutableNotificationContent()
            content.title              = "Time for \(medicine.name)"
            content.body               = medicine.notes.isEmpty ? "Tap to log your dose." : medicine.notes
            content.sound              = .default
            content.categoryIdentifier = Self.categoryID
            // Pass medicine name for in-app handling
            content.userInfo           = ["medicineName": medicine.name, "medicineID": medicine.id.uuidString]

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let id = "med_\(medicine.id.uuidString)_\(timeString.replacingOccurrences(of: ":", with: ""))"
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    // MARK: - Cancel

    func cancelMedicineReminders(for medicine: Medicine) {
        let center = UNUserNotificationCenter.current()
        let prefix = "med_\(medicine.id.uuidString)"
        center.getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {

    /// Show notifications even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handler([.banner, .sound])
    }

    /// Handle Taken / Skip action taps.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler handler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let name = info["medicineName"] as? String ?? "medicine"

        switch response.actionIdentifier {
        case Self.takenAction:
            NotificationCenter.default.post(
                name: .doseTaken,
                object: nil,
                userInfo: ["medicineName": name, "medicineID": info["medicineID"] ?? ""]
            )
        case Self.skipAction:
            NotificationCenter.default.post(
                name: .doseSkipped,
                object: nil,
                userInfo: ["medicineName": name]
            )
        default:
            break
        }
        handler()
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let doseTaken   = Notification.Name("MedJourney.doseTaken")
    static let doseSkipped = Notification.Name("MedJourney.doseSkipped")
}
