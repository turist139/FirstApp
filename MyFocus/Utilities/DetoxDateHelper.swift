import Foundation
import SwiftData

struct DetoxDateHelper {
    static func detoxDay(for date: Date, boundaryHour: Int) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        if hour >= boundaryHour {
            return calendar.startOfDay(for: date)
        } else {
            return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: date) ?? date)
        }
    }
    
    static func endOfDetoxDay(for date: Date, boundaryHour: Int) -> Date {
        let dayStart = detoxDay(for: date, boundaryHour: boundaryHour)
        let calendar = Calendar.current
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return date }
        return calendar.date(byAdding: .hour, value: boundaryHour, to: nextDay) ?? date
    }
    
    static func isDateSameDetoxDay(_ date1: Date, _ date2: Date, boundaryHour: Int) -> Bool {
        let day1 = detoxDay(for: date1, boundaryHour: boundaryHour)
        let day2 = detoxDay(for: date2, boundaryHour: boundaryHour)
        return Calendar.current.isDate(day1, inSameDayAs: day2)
    }
    
    static func formatBoundaryHour(_ hour: Int) -> String {
        if hour == 0 {
            return "полночь"
        } else {
            return String(format: "%02d:00", hour)
        }
    }
    
    static func calculateActiveHours(from relapseDate: Date?, creationDate: Date) -> Int {
        let start = relapseDate ?? creationDate
        let now = Date()
        if start > now { return 0 }
        return Int(now.timeIntervalSince(start) / 3600.0)
    }
    
    static func calculateStreakDays(from relapseDate: Date?, creationDate: Date, boundaryHour: Int) -> Int {
        var start: Date
        if let relapseDate = relapseDate {
            let endOfRelapseDay = endOfDetoxDay(for: relapseDate, boundaryHour: boundaryHour)
            let remainingHours = endOfRelapseDay.timeIntervalSince(relapseDate) / 3600.0
            
            if remainingHours < 6 {
                start = endOfRelapseDay
            } else {
                start = relapseDate
            }
        } else {
            start = creationDate
        }
        
        let now = Date()
        if start > now {
            return 0
        } else {
            return Int(now.timeIntervalSince(start) / (3600.0 * 24.0))
        }
    }
    
    static func recalculateStreak(logs: [DetoxLog], boundaryHour: Int, profile: DetoxProfile?) {
        guard let profile = profile else { return }
        let calendar = Calendar.current
        let todayDetoxDay = detoxDay(for: Date(), boundaryHour: boundaryHour)
        
        // Group logs by their detox day, taking the worst-status log for each day
        var logsByDay: [Date: DetoxLog] = [:]
        for log in logs {
            let day = detoxDay(for: log.date, boundaryHour: boundaryHour)
            if let existing = logsByDay[day] {
                let existingIsMinor = !existing.isClean && existing.relapseDuration == "пару минут"
                let existingSeverity = !existing.isClean ? (existing.isRescued || existingIsMinor ? 1 : 2) : 0
                
                let currentIsMinor = !log.isClean && log.relapseDuration == "пару минут"
                let currentSeverity = !log.isClean ? (log.isRescued || currentIsMinor ? 1 : 2) : 0
                
                if currentSeverity > existingSeverity {
                    logsByDay[day] = log
                } else if currentSeverity == existingSeverity {
                    if existing.date < log.date {
                        logsByDay[day] = log
                    }
                }
            } else {
                logsByDay[day] = log
            }
        }
        
        let sortedDays = logsByDay.keys.sorted()
        var currentStreak = 0
        var longestStreak = 0
        
        var prevDay: Date? = nil
        var penaltyDay: Date? = nil
        
        // Default to nil, will be updated by the loop if there are breaks
        profile.streakStartDate = nil
        
        for day in sortedDays {
            guard let log = logsByDay[day] else { continue }
            
            let isMinor = !log.isClean && log.relapseDuration == "пару минут"
            
            if log.isClean || log.isRescued || isMinor {
                // Streak continues
                prevDay = day
            } else {
                // Relapse without rescue: streak breaks
                prevDay = nil
                profile.streakStartDate = log.date
            }
        }
        
        currentStreak = calculateStreakDays(from: profile.streakStartDate, creationDate: profile.creationDate, boundaryHour: boundaryHour)
        
        profile.currentStreakDays = currentStreak
        profile.longestStreakDays = longestStreak
    }
}
