import Foundation
import SwiftData

@Model
final class Medicine {

    @Attribute(.unique)
    var id: UUID
    var name: String
    var notes: String
    var notificationTimesRaw: String
    var isActive: Bool
    var startDate: Date
    var createdAt: Date

    var notificationTimes: [String] {
        get {
            notificationTimesRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set { notificationTimesRaw = newValue.joined(separator: ",") }
    }

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        notificationTimesRaw: String = "",
        isActive: Bool = true,
        startDate: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.notificationTimesRaw = notificationTimesRaw
        self.isActive = isActive
        self.startDate = startDate
        self.createdAt = createdAt
    }
}
