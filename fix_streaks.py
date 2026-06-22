with open("MyFocus/Models/PastStreak.swift", "r") as f:
    content = f.read()

bad_grouping = """        // Group logs by day using severity priority: Full relapse (2) > Rescued relapse (1) > Clean day (0)
        var logsByDay: [Date: DetoxLog] = [:]
        for log in logs {
            let day = DetoxDateHelper.detoxDay(for: log.date, boundaryHour: boundaryHour)
            
            let isMinor = !log.isClean && log.relapseDuration == "пару минут"
            let currentSeverity = !log.isClean ? (log.isRescued || isMinor ? 1 : 2) : 0
            
            if let existing = logsByDay[day] {
                let existingIsMinor = !existing.isClean && existing.relapseDuration == "пару минут"
                let existingSeverity = !existing.isClean ? (existing.isRescued || existingIsMinor ? 1 : 2) : 0
                
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
        }"""

good_grouping = "        let logsByDay = DetoxDateHelper.getLogsByDay(logs: logs, boundaryHour: boundaryHour)"

content = content.replace(bad_grouping, good_grouping)

# Fix relapse end date
relapse_logic = """                // Relapse
                if let start = currentStreakStartDate {
                    let endDate = log.date
                    let reason = log.failReason ?? "Срыв"
                    let notes = log.failNotes
                    context.insert(PastStreak(startDate: start, endDate: endDate, failReason: reason, failNotes: notes, profileId: profileId))
                }
                
                currentStreakStartDate = log.date
                prevDay = nil
                currentStreakEndDate = nil
                
                let endOfRelapseDay = DetoxDateHelper.endOfDetoxDay(for: log.date, boundaryHour: boundaryHour)
                let hoursLeft = endOfRelapseDay.timeIntervalSince(log.date) / 3600.0"""

new_relapse_logic = """                // Relapse
                if let start = currentStreakStartDate {
                    let endDate = log.date
                    let reason = log.failReason ?? "Срыв"
                    let notes = log.failNotes
                    context.insert(PastStreak(startDate: start, endDate: endDate, failReason: reason, failNotes: notes, profileId: profileId))
                }
                
                let relapseEnd = log.endDate ?? log.date
                currentStreakStartDate = relapseEnd
                prevDay = nil
                currentStreakEndDate = nil
                
                let endOfRelapseDay = DetoxDateHelper.endOfDetoxDay(for: relapseEnd, boundaryHour: boundaryHour)
                let hoursLeft = endOfRelapseDay.timeIntervalSince(relapseEnd) / 3600.0"""

content = content.replace(relapse_logic, new_relapse_logic)

with open("MyFocus/Models/PastStreak.swift", "w") as f:
    f.write(content)
