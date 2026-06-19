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
    
    static func recalculateStreak(logs: [DetoxLog], boundaryHour: Int, profile: DetoxProfile?) {
        guard let profile = profile else { return }
        let calendar = Calendar.current
        let todayDetoxDay = detoxDay(for: Date(), boundaryHour: boundaryHour)
        
        // Group logs by their detox day, taking the worst-status log for each day
        var logsByDay: [Date: DetoxLog] = [:]
        for log in logs {
            let day = detoxDay(for: log.date, boundaryHour: boundaryHour)
            if let existing = logsByDay[day] {
                // Priority: Full relapse (2) > Rescued relapse (1) > Clean day (0)
                let existingSeverity = !existing.isClean ? (existing.isRescued ? 1 : 2) : 0
                let currentSeverity = !log.isClean ? (log.isRescued ? 1 : 2) : 0
                
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
            
            if log.isClean {
                if day == penaltyDay {
                    // Penalty day doesn't increment the streak, but preserves continuity
                    prevDay = day
                } else {
                    if let prev = prevDay {
                        let diff = calendar.dateComponents([.day], from: prev, to: day).day ?? 0
                        if diff <= 1 {
                            currentStreak += 1
                        } else {
                            currentStreak = 1
                            profile.streakStartDate = DetoxDateHelper.endOfDetoxDay(for: prev, boundaryHour: boundaryHour)
                        }
                    } else {
                        currentStreak = 1
                    }
                    prevDay = day
                }
            } else if log.isRescued {
                // Rescued day: streak is preserved from the previous clean day, but doesn't increment today
                // We set prevDay to today so that the next clean day knows it is continuous
                prevDay = day
            } else {
                // Relapse without rescue: streak breaks
                currentStreak = 0
                prevDay = nil
                profile.streakStartDate = log.date
                
                let endOfRelapseDay = DetoxDateHelper.endOfDetoxDay(for: log.date, boundaryHour: boundaryHour)
                let hoursLeft = endOfRelapseDay.timeIntervalSince(log.date) / 3600.0
                if hoursLeft > 0 && hoursLeft < 6.0 {
                    // Next day is penalized
                    penaltyDay = calendar.date(byAdding: .day, value: 1, to: day)
                } else {
                    penaltyDay = nil
                }
            }
            
            if currentStreak > longestStreak {
                longestStreak = currentStreak
            }
        }
        
        // Check if the streak has expired
        if let lastActiveDay = prevDay {
            let diff = calendar.dateComponents([.day], from: lastActiveDay, to: todayDetoxDay).day ?? 0
            if diff > 1 {
                currentStreak = 0
                profile.streakStartDate = DetoxDateHelper.endOfDetoxDay(for: lastActiveDay, boundaryHour: boundaryHour)
            }
        } else {
            currentStreak = 0
        }
        
        profile.currentStreakDays = currentStreak
        profile.longestStreakDays = longestStreak
    }
}
