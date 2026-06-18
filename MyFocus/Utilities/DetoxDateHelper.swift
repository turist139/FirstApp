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
    
    static func recalculateStreak(logs: [DetoxLog], boundaryHour: Int, progress: UserProgress) {
        let calendar = Calendar.current
        let todayDetoxDay = detoxDay(for: Date(), boundaryHour: boundaryHour)
        
        // Group logs by their detox day, taking the latest log for each day
        var logsByDay: [Date: DetoxLog] = [:]
        for log in logs {
            let day = detoxDay(for: log.date, boundaryHour: boundaryHour)
            // If we already have a log for this day, prefer clean/rescued or just keep the newer one
            if let existing = logsByDay[day] {
                if !existing.isClean && log.isClean {
                    logsByDay[day] = log
                } else if existing.date < log.date {
                    logsByDay[day] = log
                }
            } else {
                logsByDay[day] = log
            }
        }
        
        let sortedDays = logsByDay.keys.sorted()
        var currentStreak = 0
        var longestStreak = progress.longestStreakDays
        
        var prevDay: Date? = nil
        var penaltyDay: Date? = nil
        
        // Default to nil, will be updated by the loop if there are breaks
        progress.streakStartDate = nil
        
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
                            progress.streakStartDate = DetoxDateHelper.endOfDetoxDay(for: prev, boundaryHour: boundaryHour)
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
                progress.streakStartDate = log.date
                
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
                progress.streakStartDate = DetoxDateHelper.endOfDetoxDay(for: lastActiveDay, boundaryHour: boundaryHour)
            }
        } else {
            currentStreak = 0
        }
        
        progress.currentStreakDays = currentStreak
        progress.longestStreakDays = max(longestStreak, progress.longestStreakDays)
    }
}
