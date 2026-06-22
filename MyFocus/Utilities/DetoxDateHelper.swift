import Foundation
import SwiftData

struct DetoxDateHelper {
    struct StreakHistoryItem: Identifiable {
        let id = UUID()
        let length: Int
        let duration: TimeInterval?
        let startDate: Date
        let endDate: Date?
        let reason: String
        let notes: String?
    }

    struct RelapseHistoryItem: Identifiable {
        let id = UUID()
        let startDate: Date
        let endDate: Date?
        let duration: TimeInterval
        let reason: String
        let notes: String?
    }

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
    
    static func calculateStreakDays(from relapseDate: Date?, creationDate: Date, currentBoundaryHour: Int, startBoundaryHour: Int?) -> Int {
        let baseDate = relapseDate ?? creationDate
        let boundaryToUse = startBoundaryHour ?? currentBoundaryHour
        let endOfDay = endOfDetoxDay(for: baseDate, boundaryHour: boundaryToUse)
        let remainingHours = endOfDay.timeIntervalSince(baseDate) / 3600.0
        
        let startDetoxDay = detoxDay(for: baseDate, boundaryHour: boundaryToUse)
        let effectiveStartDay: Date
        
        if remainingHours >= 6 {
            effectiveStartDay = startDetoxDay
        } else {
            // Start counting from the next detox day
            effectiveStartDay = Calendar.current.date(byAdding: .day, value: 1, to: startDetoxDay) ?? startDetoxDay
        }
        
        let currentDetoxDay = detoxDay(for: Date(), boundaryHour: currentBoundaryHour)
        return calculateStreakDaysBetween(effectiveStartDay: effectiveStartDay, endDetoxDay: currentDetoxDay)
    }
    
    static func calculateStreakDaysBetween(effectiveStartDay: Date, endDetoxDay: Date) -> Int {
        let components = Calendar.current.dateComponents([.day], from: effectiveStartDay, to: endDetoxDay)
        return max(0, components.day ?? 0)
    }
    
    static func getEffectiveStartDay(for baseDate: Date, boundaryHour: Int) -> Date {
        let endOfDay = endOfDetoxDay(for: baseDate, boundaryHour: boundaryHour)
        let remainingHours = endOfDay.timeIntervalSince(baseDate) / 3600.0
        let startDetoxDay = detoxDay(for: baseDate, boundaryHour: boundaryHour)
        
        if remainingHours >= 6 {
            return startDetoxDay
        } else {
            return Calendar.current.date(byAdding: .day, value: 1, to: startDetoxDay) ?? startDetoxDay
        }
    }
    
    
    static func getSeverity(for log: DetoxLog) -> Int {
        if log.isClean { return 0 }
        let isMinor = log.relapseDuration == "пару минут"
        if log.isRescued || isMinor { return 1 }
        return 2
    }

    static func getLogsByDay(logs: [DetoxLog], boundaryHour: Int) -> [Date: DetoxLog] {
        var logsByDay: [Date: DetoxLog] = [:]
        for log in logs {
            let startDay = detoxDay(for: log.date, boundaryHour: boundaryHour)
            let endDay = detoxDay(for: log.endDate ?? log.date, boundaryHour: boundaryHour)
            
            var currentDay = startDay
            while currentDay <= endDay {
                if let existing = logsByDay[currentDay] {
                    let existingSeverity = getSeverity(for: existing)
                    let currentSeverity = getSeverity(for: log)
                    
                    if currentSeverity > existingSeverity {
                        logsByDay[currentDay] = log
                    } else if currentSeverity == existingSeverity {
                        if existing.date < log.date {
                            logsByDay[currentDay] = log
                        }
                    }
                } else {
                    logsByDay[currentDay] = log
                }
                currentDay = Calendar.current.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
            }
        }
        return logsByDay
    }

    static func generateHistory(logs: [DetoxLog], profile: DetoxProfile?, boundaryHour: Int) -> (streaks: [StreakHistoryItem], relapses: [RelapseHistoryItem]) {
        var streaks: [StreakHistoryItem] = []
        var relapses: [RelapseHistoryItem] = []
        guard let profile = profile else { return (streaks, relapses) }
        
        let logsByDay = getLogsByDay(logs: logs, boundaryHour: boundaryHour)
        let sortedDays = logsByDay.keys.sorted()
        let calendar = Calendar.current
        
        var currentStreakStartDate = profile.creationDate
        var currentStreakStartBoundaryHour = boundaryHour
        var previousDay: Date? = nil
        
        for day in sortedDays {
            guard let log = logsByDay[day] else { continue }
            
            let severity = getSeverity(for: log)
            let isCleanDay = severity < 2
            
            if let prev = previousDay {
                let daysDiff = calendar.dateComponents([.day], from: prev, to: day).day ?? 0
                if daysDiff > 1 {
                    let effectiveStart = getEffectiveStartDay(for: currentStreakStartDate, boundaryHour: currentStreakStartBoundaryHour)
                    let endDetoxDay = calendar.date(byAdding: .day, value: 1, to: prev) ?? prev
                    let length = calculateStreakDaysBetween(effectiveStartDay: effectiveStart, endDetoxDay: endDetoxDay)
                    streaks.append(StreakHistoryItem(length: length, duration: nil, startDate: currentStreakStartDate, endDate: endDetoxDay, reason: "Пропущен чек-ин", notes: nil))
                    
                    currentStreakStartDate = log.date
                    currentStreakStartBoundaryHour = boundaryHour
                }
            } else {
                let creationDetoxDay = detoxDay(for: profile.creationDate, boundaryHour: boundaryHour)
                let daysDiff = calendar.dateComponents([.day], from: creationDetoxDay, to: day).day ?? 0
                if daysDiff > 1 {
                    currentStreakStartDate = log.date
                    currentStreakStartBoundaryHour = boundaryHour
                }
            }
            
            if !isCleanDay {
                let effectiveStart = getEffectiveStartDay(for: currentStreakStartDate, boundaryHour: currentStreakStartBoundaryHour)
                let length = calculateStreakDaysBetween(effectiveStartDay: effectiveStart, endDetoxDay: day)
                streaks.append(StreakHistoryItem(length: length, duration: nil, startDate: currentStreakStartDate, endDate: log.date, reason: log.failReason ?? "Срыв", notes: log.failNotes))
                
                let relapseEnd = log.endDate ?? log.date
                let relapseDuration = relapseEnd.timeIntervalSince(log.date)
                relapses.append(RelapseHistoryItem(startDate: log.date, endDate: log.endDate, duration: relapseDuration, reason: log.failReason ?? "Срыв", notes: log.failNotes))
                
                currentStreakStartDate = relapseEnd
                currentStreakStartBoundaryHour = boundaryHour
            }
            
            previousDay = day
        }
        
        let todayDetoxDay = detoxDay(for: Date(), boundaryHour: boundaryHour)
        if let prev = previousDay {
            let daysDiff = calendar.dateComponents([.day], from: prev, to: todayDetoxDay).day ?? 0
            if daysDiff > 1 {
                let effectiveStart = getEffectiveStartDay(for: currentStreakStartDate, boundaryHour: currentStreakStartBoundaryHour)
                let endDetoxDay = calendar.date(byAdding: .day, value: 1, to: prev) ?? prev
                let length = calculateStreakDaysBetween(effectiveStartDay: effectiveStart, endDetoxDay: endDetoxDay)
                streaks.append(StreakHistoryItem(length: length, duration: nil, startDate: currentStreakStartDate, endDate: endDetoxDay, reason: "Пропущен чек-ин", notes: nil))
                currentStreakStartDate = Date()
                currentStreakStartBoundaryHour = boundaryHour
            }
        }
        
        let activeStartDate = profile.streakStartDate ?? profile.creationDate
        let length = calculateStreakDays(from: activeStartDate, creationDate: profile.creationDate, currentBoundaryHour: boundaryHour, startBoundaryHour: profile.streakStartBoundaryHour)
        let duration = Date().timeIntervalSince(activeStartDate)
        if duration >= 60 {
            streaks.append(StreakHistoryItem(length: length, duration: duration, startDate: activeStartDate, endDate: nil, reason: "Активный стрик", notes: nil))
        }
        
        return (streaks.reversed(), relapses.reversed())
    }

    static func recalculateStreak(logs: [DetoxLog], boundaryHour: Int, profile: DetoxProfile?) {
        guard let profile = profile else { return }
        let logsByDay = getLogsByDay(logs: logs, boundaryHour: boundaryHour)
        let sortedDays = logsByDay.keys.sorted()
        let calendar = Calendar.current
        
        var longestStreak = 0
        var currentStreakStartDate = profile.creationDate
        var currentStreakStartBoundaryHour = boundaryHour
        var previousDay: Date? = nil
        
        for day in sortedDays {
            guard let log = logsByDay[day] else { continue }
            
            let isMinor = !log.isClean && log.relapseDuration == "пару минут"
            let isCleanDay = log.isClean || log.isRescued || isMinor
            
            if let prev = previousDay {
                let daysDiff = calendar.dateComponents([.day], from: prev, to: day).day ?? 0
                if daysDiff > 1 {
                    // Gap detected, streak broken
                    let effectiveStart = getEffectiveStartDay(for: currentStreakStartDate, boundaryHour: currentStreakStartBoundaryHour)
                    let endDetoxDay = calendar.date(byAdding: .day, value: 1, to: prev) ?? prev
                    let length = calculateStreakDaysBetween(effectiveStartDay: effectiveStart, endDetoxDay: endDetoxDay)
                    longestStreak = max(longestStreak, length)
                    
                    currentStreakStartDate = log.date
                    currentStreakStartBoundaryHour = boundaryHour
                }
            } else {
                // Check gap from creation date to first log
                let creationDetoxDay = detoxDay(for: profile.creationDate, boundaryHour: boundaryHour)
                let daysDiff = calendar.dateComponents([.day], from: creationDetoxDay, to: day).day ?? 0
                if daysDiff > 1 {
                    currentStreakStartDate = log.endDate ?? log.date
                    currentStreakStartBoundaryHour = boundaryHour
                }
            }
            
            if !isCleanDay {
                let effectiveStart = getEffectiveStartDay(for: currentStreakStartDate, boundaryHour: currentStreakStartBoundaryHour)
                let length = calculateStreakDaysBetween(effectiveStartDay: effectiveStart, endDetoxDay: day)
                longestStreak = max(longestStreak, length)
                
                let relapseEnd = log.endDate ?? log.date
                currentStreakStartDate = relapseEnd
                currentStreakStartBoundaryHour = boundaryHour
            }
            
            previousDay = day
        }
        
        // Check gap from last log (or creation date) to TODAY
        let todayDetoxDay = detoxDay(for: Date(), boundaryHour: boundaryHour)
        if let prev = previousDay {
            let daysDiff = calendar.dateComponents([.day], from: prev, to: todayDetoxDay).day ?? 0
            if daysDiff > 1 {
                let effectiveStart = getEffectiveStartDay(for: currentStreakStartDate, boundaryHour: currentStreakStartBoundaryHour)
                let endDetoxDay = calendar.date(byAdding: .day, value: 1, to: prev) ?? prev
                let length = calculateStreakDaysBetween(effectiveStartDay: effectiveStart, endDetoxDay: endDetoxDay)
                longestStreak = max(longestStreak, length)
                
                currentStreakStartDate = Date()
                currentStreakStartBoundaryHour = boundaryHour
            }
        } else {
            let creationDetoxDay = detoxDay(for: profile.creationDate, boundaryHour: boundaryHour)
            let daysDiff = calendar.dateComponents([.day], from: creationDetoxDay, to: todayDetoxDay).day ?? 0
            if daysDiff > 1 {
                currentStreakStartDate = Date()
                currentStreakStartBoundaryHour = boundaryHour
            }
        }
        
        profile.streakStartDate = currentStreakStartDate
        profile.streakStartBoundaryHour = currentStreakStartBoundaryHour
        
        let currentStreak = calculateStreakDays(from: currentStreakStartDate, creationDate: profile.creationDate, currentBoundaryHour: boundaryHour, startBoundaryHour: currentStreakStartBoundaryHour)
        longestStreak = max(longestStreak, currentStreak) // ensure current streak counts towards longest
        
        profile.currentStreakDays = currentStreak
        profile.longestStreakDays = longestStreak
    }
}
