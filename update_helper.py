import re

with open("MyFocus/Utilities/DetoxDateHelper.swift", "r") as f:
    content = f.read()

new_logic = """    static func getSeverity(for log: DetoxLog) -> Int {
        if log.isClean { return 0 }
        let isMinor = log.relapseDuration == "пару минут"
        if log.isRescued || isMinor { return 1 }
        let tolerancePenalty = (5 - (log.silenceTolerance ?? 3))
        return 2 + tolerancePenalty
    }

    static func getLogsByDay(logs: [DetoxLog], boundaryHour: Int) -> [Date: DetoxLog] {
        var logsByDay: [Date: DetoxLog] = [:]
        let calendar = Calendar.current
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
                currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
            }
        }
        return logsByDay
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
            
            let isCleanDay = getSeverity(for: log) == 0 || getSeverity(for: log) == 1
            
            if let prev = previousDay {
                let daysDiff = calendar.dateComponents([.day], from: prev, to: day).day ?? 0
                if daysDiff > 1 {
                    // Gap detected, streak broken
                    let effectiveStart = getEffectiveStartDay(for: currentStreakStartDate, boundaryHour: currentStreakStartBoundaryHour)
                    let endDetoxDay = calendar.date(byAdding: .day, value: 1, to: prev) ?? prev
                    let length = calculateStreakDaysBetween(effectiveStartDay: effectiveStart, endDetoxDay: endDetoxDay)
                    longestStreak = max(longestStreak, length)
                    
                    currentStreakStartDate = log.endDate ?? log.date
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
                
                currentStreakStartDate = log.endDate ?? log.date
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
        
        profile.longestStreakDays = longestStreak
        profile.currentStreakDays = currentStreak
    }

    static func generateHistory(logs: [DetoxLog], profile: DetoxProfile?, boundaryHour: Int) -> (streaks: [PastStreak], relapses: [PastRelapse]) {
        guard let profile = profile else { return ([], []) }
        
        let logsByDay = getLogsByDay(logs: logs, boundaryHour: boundaryHour)
        let sortedDays = logsByDay.keys.sorted()
        let calendar = Calendar.current
        
        var streaks: [PastStreak] = []
        var relapses: [PastRelapse] = []
        
        var currentStreakStartDate = profile.creationDate
        var currentStreakStartBoundaryHour = boundaryHour
        var previousDay: Date? = nil
        
        for day in sortedDays {
            guard let log = logsByDay[day] else { continue }
            
            let isCleanDay = getSeverity(for: log) == 0 || getSeverity(for: log) == 1
            
            if let prev = previousDay {
                let daysDiff = calendar.dateComponents([.day], from: prev, to: day).day ?? 0
                if daysDiff > 1 {
                    // Gap detected, streak broken
                    let effectiveStart = getEffectiveStartDay(for: currentStreakStartDate, boundaryHour: currentStreakStartBoundaryHour)
                    let endDetoxDay = calendar.date(byAdding: .day, value: 1, to: prev) ?? prev
                    let length = calculateStreakDaysBetween(effectiveStartDay: effectiveStart, endDetoxDay: endDetoxDay)
                    let duration = endDetoxDay.timeIntervalSince(currentStreakStartDate)
                    if duration >= 60 {
                        streaks.append(PastStreak(length: length, duration: duration, startDate: currentStreakStartDate, endDate: endDetoxDay, reason: "Пропущен чек-ин", notes: nil))
                    }
                    currentStreakStartDate = log.endDate ?? log.date
                    currentStreakStartBoundaryHour = boundaryHour
                }
            } else {
                let creationDetoxDay = detoxDay(for: profile.creationDate, boundaryHour: boundaryHour)
                let daysDiff = calendar.dateComponents([.day], from: creationDetoxDay, to: day).day ?? 0
                if daysDiff > 1 {
                    let effectiveStart = getEffectiveStartDay(for: currentStreakStartDate, boundaryHour: currentStreakStartBoundaryHour)
                    let endDetoxDay = calendar.date(byAdding: .day, value: 1, to: creationDetoxDay) ?? creationDetoxDay
                    let length = calculateStreakDaysBetween(effectiveStartDay: effectiveStart, endDetoxDay: endDetoxDay)
                    let duration = endDetoxDay.timeIntervalSince(currentStreakStartDate)
                    if duration >= 60 {
                        streaks.append(PastStreak(length: length, duration: duration, startDate: currentStreakStartDate, endDate: endDetoxDay, reason: "Пропущен чек-ин", notes: nil))
                    }
                    currentStreakStartDate = log.endDate ?? log.date
                    currentStreakStartBoundaryHour = boundaryHour
                }
            }
            
            if !isCleanDay {
                let effectiveStart = getEffectiveStartDay(for: currentStreakStartDate, boundaryHour: currentStreakStartBoundaryHour)
                let length = calculateStreakDaysBetween(effectiveStartDay: effectiveStart, endDetoxDay: day)
                let duration = log.date.timeIntervalSince(currentStreakStartDate)
                if duration >= 60 {
                    streaks.append(PastStreak(length: length, duration: duration, startDate: currentStreakStartDate, endDate: log.date, reason: log.failReason ?? "Срыв", notes: log.failNotes))
                }
                
                // Add to relapses history
                let relapseEnd = log.endDate ?? log.date
                let relapseDuration = relapseEnd.timeIntervalSince(log.date)
                relapses.append(PastRelapse(startDate: log.date, endDate: log.endDate, duration: relapseDuration, reason: log.failReason ?? "Срыв", notes: log.failNotes))
                
                currentStreakStartDate = log.endDate ?? log.date
                currentStreakStartBoundaryHour = boundaryHour
            }
            
            previousDay = day
        }
        
        let activeStartDate = profile.streakStartDate ?? profile.creationDate
        let length = calculateStreakDays(from: activeStartDate, creationDate: profile.creationDate, currentBoundaryHour: boundaryHour, startBoundaryHour: profile.streakStartBoundaryHour)
        let duration = Date().timeIntervalSince(activeStartDate)
        if duration >= 60 {
            streaks.append(PastStreak(length: length, duration: duration, startDate: activeStartDate, endDate: nil, reason: "Активный стрик", notes: nil))
        }
        
        return (streaks.reversed(), relapses.reversed())
    }
"""

start_str = "    static func recalculateStreak(logs: [DetoxLog], boundaryHour: Int, profile: DetoxProfile?) {"
end_str = "        profile.longestStreakDays = longestStreak\n        profile.currentStreakDays = currentStreak\n    }"

start_idx = content.find(start_str)
end_idx = content.find(end_str) + len(end_str)

new_content = content[:start_idx] + new_logic + content[end_idx:]

with open("MyFocus/Utilities/DetoxDateHelper.swift", "w") as f:
    f.write(new_content)
