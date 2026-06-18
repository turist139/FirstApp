import Foundation
import SwiftData

@Model
final class UserProgress {
    var id: UUID
    var totalXP: Int
    var currentLevel: Int
    var currentStreakDays: Int
    var longestStreakDays: Int
    var availableFreezes: Int
    var unlockedPaletteIDs: [String]
    var lastActiveDate: Date?
    var streakStartDate: Date?
    
    // Dopamine Detox properties
    var detoxHabits: [String]
    var lastCheckInDate: Date?
    var streakSavedToday: Bool
    var streakQuestsCompleted: Int
    
    init(
        id: UUID = UUID(),
        totalXP: Int = 0,
        currentLevel: Int = 1,
        currentStreakDays: Int = 0,
        longestStreakDays: Int = 0,
        availableFreezes: Int = 1,
        unlockedPaletteIDs: [String] = ["default"],
        lastActiveDate: Date? = nil,
        streakStartDate: Date? = nil,
        detoxHabits: [String] = ["YouTube", "Новости", "Telegram", "Прямые эфиры"],
        lastCheckInDate: Date? = nil,
        streakSavedToday: Bool = false,
        streakQuestsCompleted: Int = 0
    ) {
        self.id = id
        self.totalXP = totalXP
        self.currentLevel = currentLevel
        self.currentStreakDays = currentStreakDays
        self.longestStreakDays = longestStreakDays
        self.availableFreezes = availableFreezes
        self.unlockedPaletteIDs = unlockedPaletteIDs
        self.lastActiveDate = lastActiveDate
        self.streakStartDate = streakStartDate
        self.detoxHabits = detoxHabits
        self.lastCheckInDate = lastCheckInDate
        self.streakSavedToday = streakSavedToday
        self.streakQuestsCompleted = streakQuestsCompleted
    }
}
