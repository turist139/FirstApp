import Foundation
import SwiftData

@Model
final class DetoxProfile {
    var id: UUID
    var name: String
    var icon: String
    var creationDate: Date
    
    var detoxHabits: [String]
    var currentStreakDays: Int
    var longestStreakDays: Int
    var lastCheckInDate: Date?
    var streakStartDate: Date?
    var streakSavedToday: Bool
    var streakQuestsCompleted: Int
    
    init(
        id: UUID = UUID(),
        name: String = "Основной",
        icon: String = "flame.fill",
        creationDate: Date = Date(),
        detoxHabits: [String] = [],
        currentStreakDays: Int = 0,
        longestStreakDays: Int = 0,
        lastCheckInDate: Date? = nil,
        streakStartDate: Date? = nil,
        streakSavedToday: Bool = false,
        streakQuestsCompleted: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.creationDate = creationDate
        self.detoxHabits = detoxHabits
        self.currentStreakDays = currentStreakDays
        self.longestStreakDays = longestStreakDays
        self.lastCheckInDate = lastCheckInDate
        self.streakStartDate = streakStartDate
        self.streakSavedToday = streakSavedToday
        self.streakQuestsCompleted = streakQuestsCompleted
    }
}
