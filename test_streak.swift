import Foundation

// Mock objects
struct DetoxLog {
    var date: Date
    var isClean: Bool
    var failReason: String?
    var failNotes: String?
    var isRescued: Bool
}

class PastStreak: CustomStringConvertible {
    var startDate: Date
    var endDate: Date
    var failReason: String?
    
    init(startDate: Date, endDate: Date, failReason: String?) {
        self.startDate = startDate
        self.endDate = endDate
        self.failReason = failReason
    }
    
    var description: String {
        return "Streak: \(startDate) to \(endDate) (Reason: \(failReason ?? "nil"))"
    }
}

class Context {
    var streaks: [PastStreak] = []
    func insert(_ streak: PastStreak) {
        streaks.append(streak)
    }
}

func detoxDay(for date: Date) -> Date {
    return Calendar.current.startOfDay(for: date)
}

func rebuild(logs: [DetoxLog], context: Context) {
    let calendar = Calendar.current
    var logsByDay: [Date: DetoxLog] = [:]
    for log in logs {
        let day = detoxDay(for: log.date)
        if let existing = logsByDay[day] {
            if !existing.isClean && log.isClean { logsByDay[day] = log }
            else if existing.date < log.date { logsByDay[day] = log }
        } else {
            logsByDay[day] = log
        }
    }
    
    let sortedDays = logsByDay.keys.sorted()
    var prevDay: Date? = nil
    var currentStreakStartDate: Date? = nil
    var currentStreakEndDate: Date? = nil
    var penaltyDay: Date? = nil
    
    for day in sortedDays {
        guard let log = logsByDay[day] else { continue }
        
        if log.isClean {
            if day == penaltyDay {
                prevDay = day
            } else {
                if let prev = prevDay {
                    let diff = calendar.dateComponents([.day], from: prev, to: day).day ?? 0
                    if diff > 1 {
                        if let start = currentStreakStartDate, let end = currentStreakEndDate {
                            context.insert(PastStreak(startDate: start, endDate: end, failReason: "Пропущенные дни"))
                        }
                        currentStreakStartDate = log.date
                    }
                } else {
                    if currentStreakStartDate == nil {
                        currentStreakStartDate = log.date
                    }
                }
                prevDay = day
                currentStreakEndDate = log.date
            }
        } else if log.isRescued {
            prevDay = day
            currentStreakEndDate = log.date
        } else {
            // Relapse
            if let start = currentStreakStartDate {
                context.insert(PastStreak(startDate: start, endDate: log.date, failReason: log.failReason))
            }
            currentStreakStartDate = log.date
            prevDay = nil
            currentStreakEndDate = nil
            penaltyDay = nil
        }
    }
}

var logs: [DetoxLog] = []
let calendar = Calendar.current
let now = Date()

// Generate exactly what the user has
// May 19 to May 24: Clean
for i in (25...30).reversed() {
    logs.append(DetoxLog(date: calendar.date(byAdding: .day, value: -i, to: now)!, isClean: true, failReason: nil, failNotes: nil, isRescued: false))
}
// May 25 (Day -24): Relapse
logs.append(DetoxLog(date: calendar.date(byAdding: .day, value: -24, to: now)!, isClean: false, failReason: "Скука", failNotes: nil, isRescued: false))

// May 26 to June 3: Clean
for i in (15...23).reversed() {
    logs.append(DetoxLog(date: calendar.date(byAdding: .day, value: -i, to: now)!, isClean: true, failReason: nil, failNotes: nil, isRescued: false))
}
// June 4 (Day -14): Rescued
logs.append(DetoxLog(date: calendar.date(byAdding: .day, value: -14, to: now)!, isClean: false, failReason: "Тревога", failNotes: nil, isRescued: true))

// June 5 to June 13: Clean
for i in (5...13).reversed() {
    logs.append(DetoxLog(date: calendar.date(byAdding: .day, value: -i, to: now)!, isClean: true, failReason: nil, failNotes: nil, isRescued: false))
}
// June 14 (Day -4): Relapse
logs.append(DetoxLog(date: calendar.date(byAdding: .day, value: -4, to: now)!, isClean: false, failReason: "Автопилот", failNotes: nil, isRescued: false))

// June 15 (Day -3): Relapse (Manual)
logs.append(DetoxLog(date: calendar.date(byAdding: .day, value: -3, to: now)!, isClean: false, failReason: "Один раз", failNotes: nil, isRescued: false))

// June 16, 17: Clean
logs.append(DetoxLog(date: calendar.date(byAdding: .day, value: -2, to: now)!, isClean: true, failReason: nil, failNotes: nil, isRescued: false))
logs.append(DetoxLog(date: calendar.date(byAdding: .day, value: -1, to: now)!, isClean: true, failReason: nil, failNotes: nil, isRescued: false))

// June 18: Partial Relapse
logs.append(DetoxLog(date: now, isClean: false, failReason: "Сброс", failNotes: nil, isRescued: false))

let context = Context()
rebuild(logs: logs, context: context)
for streak in context.streaks {
    print(streak)
}
