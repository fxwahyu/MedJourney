import Foundation
import SwiftData

@Model
final class ChecklistItem {

    @Attribute(.unique)
    var id: UUID
    var text: String
    var emoji: String
    var isChecked: Bool
    var sortOrder: Int
    var sourceCheckupId: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        emoji: String = "✅",
        isChecked: Bool = false,
        sortOrder: Int = 0,
        sourceCheckupId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.emoji = emoji
        self.isChecked = isChecked
        self.sortOrder = sortOrder
        self.sourceCheckupId = sourceCheckupId
        self.createdAt = createdAt
    }
}
