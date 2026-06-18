import Foundation
import SwiftData

struct DetoxMockDataHelper {
    
    /// Generates 30 days of realistic mock data for detox logging
    @MainActor
    static func generateMockData(context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        
        // 1. Clear any existing logs first
        let fetchDescriptor = FetchDescriptor<DetoxLog>()
        if let existingLogs = try? context.fetch(fetchDescriptor) {
            for log in existingLogs {
                context.delete(log)
            }
        }
        
        // 2. Generate logs for the last 30 days
        for dayOffset in (1...30).reversed() {
            guard let logDate = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            
            var isClean = true
            var failReason: String? = nil
            var failNotes: String? = nil
            var isRescued = false
            var sosCount = 0
            
            // Relapse on Day -24 (Streak breaks)
            if dayOffset == 24 {
                isClean = false
                failReason = "Скука"
                failNotes = "Устал после работы, со скуки зашел в YouTube и листал Reels."
            }
            // Relapse on Day -14 (Rescued via Quest, Streak continues!)
            else if dayOffset == 14 {
                isClean = false
                failReason = "Тревога"
                failNotes = "Появилась сильная тревога из-за работы. Открыл Telegram, но вовремя опомнился и прошел квест спасения."
                isRescued = true
            }
            // Relapse on Day -4 (Streak breaks)
            else if dayOffset == 4 {
                isClean = false
                failReason = "Автопилот"
                failNotes = "На автомате кликнул на новостной сайт во время обеда."
            }
            
            // Pre-fill SOS counts on some days
            if dayOffset == 28 { sosCount = 1 }
            if dayOffset == 20 { sosCount = 2 }
            if dayOffset == 15 { sosCount = 1 }
            if dayOffset == 14 { sosCount = 1 } // Used SOS during relapse rescue
            if dayOffset == 8 { sosCount = 2 }
            if dayOffset == 2 { sosCount = 3 } // High temptation day
            
            var sosTimes: [Date] = []
            if sosCount > 0 {
                let calendar = Calendar.current
                if sosCount >= 1 {
                    if let t1 = calendar.date(bySettingHour: 10, minute: 15, second: 0, of: logDate) {
                        sosTimes.append(t1)
                    }
                }
                if sosCount >= 2 {
                    if let t2 = calendar.date(bySettingHour: 14, minute: 45, second: 0, of: logDate) {
                        sosTimes.append(t2)
                    }
                }
                if sosCount >= 3 {
                    if let t3 = calendar.date(bySettingHour: 19, minute: 30, second: 0, of: logDate) {
                        sosTimes.append(t3)
                    }
                }
            }
            
            let log = DetoxLog(
                date: logDate,
                isClean: isClean,
                failReason: failReason,
                failNotes: failNotes,
                isRescued: isRescued,
                sosCount: sosCount,
                sosTimes: sosTimes
            )
            context.insert(log)
        }
        
        // 3. Adjust UserProgress to reflect this mock history
        // Day -3, -2, -1 were clean, so current streak = 3.
        // Longest streak was Day -23 to Day -5 (19 days, since Day -14 was rescued!).
        let progressFetch = FetchDescriptor<UserProgress>()
        if let progress = try? context.fetch(progressFetch).first {
            progress.currentStreakDays = 3
            progress.longestStreakDays = 19
            progress.lastCheckInDate = calendar.date(byAdding: .day, value: -1, to: now)
        } else {
            let progress = UserProgress(
                currentStreakDays: 3,
                longestStreakDays: 19,
                lastCheckInDate: calendar.date(byAdding: .day, value: -1, to: now)
            )
            context.insert(progress)
        }
        
        // 4. Generate some mock PastStreaks!
        let pastStreaksFetch = FetchDescriptor<PastStreak>()
        if let existingStreaks = try? context.fetch(pastStreaksFetch) {
            for streak in existingStreaks {
                context.delete(streak)
            }
        }
        
        if let s1Start = calendar.date(byAdding: .day, value: -24, to: now),
           let s1End = calendar.date(byAdding: .day, value: -5, to: now) {
            let s1 = PastStreak(startDate: s1Start, endDate: s1End, failReason: "Автопилот", failNotes: "Случайно открыл соцсеть.")
            context.insert(s1)
        }
        
        if let s2Start = calendar.date(byAdding: .day, value: -4, to: now),
           let s2End = calendar.date(byAdding: .hour, value: 14, to: calendar.date(byAdding: .day, value: -2, to: now)!) {
            let s2 = PastStreak(startDate: s2Start, endDate: s2End, failReason: "Скука", failNotes: "Сорвался вечером от скуки.")
            context.insert(s2)
        }
        
        if let s3Start = calendar.date(byAdding: .day, value: -2, to: now),
           let s3End = calendar.date(byAdding: .hour, value: 12, to: s3Start) {
            let s3 = PastStreak(startDate: s3Start, endDate: s3End, failReason: "Стресс", failNotes: "Тяжелый рабочий день.")
            context.insert(s3)
        }
        
        try? context.save()
    }
    
    /// Migrates existing DetoxLogs to PastStreaks
    @MainActor
    static func migrateToPastStreaks(context: ModelContext) {
        let fetchDescriptor = FetchDescriptor<DetoxLog>(sortBy: [SortDescriptor(\.date, order: .forward)])
        guard let logs = try? context.fetch(fetchDescriptor), !logs.isEmpty else { return }
        
        var currentStreak: [DetoxLog] = []
        for log in logs {
            if log.isClean || log.isRescued {
                currentStreak.append(log)
            } else {
                if !currentStreak.isEmpty {
                    let startDate = currentStreak.first!.date
                    let endDate = currentStreak.last!.date
                    let reason = log.failReason ?? "Срыв"
                    let notes = log.failNotes
                    
                    let pastStreak = PastStreak(startDate: startDate, endDate: endDate, failReason: reason, failNotes: notes)
                    context.insert(pastStreak)
                    currentStreak = []
                }
            }
        }
        try? context.save()
    }
    
    /// Clears all logs and resets user streaks to start fresh
    @MainActor
    static func clearAllData(context: ModelContext) {
        let fetchLogs = FetchDescriptor<DetoxLog>()
        if let logs = try? context.fetch(fetchLogs) {
            for log in logs {
                context.delete(log)
            }
        }
        
        let progressFetch = FetchDescriptor<UserProgress>()
        if let progress = try? context.fetch(progressFetch).first {
            progress.currentStreakDays = 0
            progress.longestStreakDays = 0
            progress.lastCheckInDate = nil
            progress.lastActiveDate = nil
            progress.streakStartDate = nil
            progress.streakSavedToday = false
        }
        
        let pastStreaksFetch = FetchDescriptor<PastStreak>()
        if let streaks = try? context.fetch(pastStreaksFetch) {
            for streak in streaks {
                context.delete(streak)
            }
        }
        
        try? context.save()
    }
}
