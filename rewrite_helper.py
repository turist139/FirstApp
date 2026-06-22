import os

with open("MyFocus/Utilities/DetoxDateHelper.swift", "r") as f:
    content = f.read()

# Add structs
structs = """
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
"""
content = content.replace("struct DetoxDateHelper {", "struct DetoxDateHelper {" + structs)

# Add getLogsByDay and generateHistory
new_methods = """
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
"""

content = content.replace("static func recalculateStreak(logs: [DetoxLog], boundaryHour: Int, profile: DetoxProfile?) {", new_methods + "\n    static func recalculateStreak(logs: [DetoxLog], boundaryHour: Int, profile: DetoxProfile?) {")

# Modify recalculateStreak to use getLogsByDay
old_recalc_start = """        guard let profile = profile else { return }
        
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
        
        let sortedDays = logsByDay.keys.sorted()"""

new_recalc_start = """        guard let profile = profile else { return }
        let logsByDay = getLogsByDay(logs: logs, boundaryHour: boundaryHour)
        let sortedDays = logsByDay.keys.sorted()"""

content = content.replace(old_recalc_start, new_recalc_start)

with open("MyFocus/Utilities/DetoxDateHelper.swift", "w") as f:
    f.write(content)
