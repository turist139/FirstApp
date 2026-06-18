import Foundation
import SwiftData

@Model
final class PastStreak {
    var id: UUID
    var startDate: Date
    var endDate: Date
    var failReason: String?
    var failNotes: String?
    
    var durationInHours: Int {
        let diff = Calendar.current.dateComponents([.hour], from: startDate, to: endDate).hour ?? 0
        return max(0, diff)
    }
    
    var durationInMinutes: Int {
        let diff = Calendar.current.dateComponents([.minute], from: startDate, to: endDate).minute ?? 0
        return max(0, diff)
    }
    
    init(id: UUID = UUID(), startDate: Date, endDate: Date, failReason: String? = nil, failNotes: String? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.failReason = failReason
        self.failNotes = failNotes
    }
}

extension PastStreak {
    @MainActor
    static func rebuildPastStreaks(logs: [DetoxLog], context: ModelContext) {
        let fetch = FetchDescriptor<PastStreak>()
        if let existing = try? context.fetch(fetch) {
            for streak in existing {
                context.delete(streak)
            }
        }
        
        let boundaryHour = UserDefaults.standard.integer(forKey: "detoxDayBoundaryHour")
        let calendar = Calendar.current
        
        let sortedLogs = logs.sorted { $0.date < $1.date }
        
        var prevDay: Date? = nil
        var currentStreakStartDate: Date? = nil
        var currentStreakEndDate: Date? = nil
        var penaltyDay: Date? = nil
        
        for log in sortedLogs {
            let day = DetoxDateHelper.detoxDay(for: log.date, boundaryHour: boundaryHour)
            
            if let prev = prevDay {
                let diff = calendar.dateComponents([.day], from: prev, to: day).day ?? 0
                if diff > 1 {
                    // Streak broken by gap
                    if let start = currentStreakStartDate, let end = currentStreakEndDate {
                        let endOfPrevDay = DetoxDateHelper.endOfDetoxDay(for: end, boundaryHour: boundaryHour)
                        context.insert(PastStreak(startDate: start, endDate: endOfPrevDay, failReason: "Пропущенные дни", failNotes: "Стрик прерван из-за пропущенных чекинов"))
                    }
                    currentStreakStartDate = log.date
                }
            }
            
            if log.isClean {
                if day == penaltyDay {
                    prevDay = day
                } else {
                    if currentStreakStartDate == nil {
                        currentStreakStartDate = log.date
                    }
                }
                prevDay = day
                currentStreakEndDate = log.date
            } else if log.isRescued {
                prevDay = day
                currentStreakEndDate = log.date
            } else {
                // Relapse
                if let start = currentStreakStartDate {
                    let endDate = log.date
                    let reason = log.failReason ?? "Срыв"
                    let notes = log.failNotes
                    context.insert(PastStreak(startDate: start, endDate: endDate, failReason: reason, failNotes: notes))
                }
                
                currentStreakStartDate = log.date
                prevDay = nil
                currentStreakEndDate = nil
                
                let endOfRelapseDay = DetoxDateHelper.endOfDetoxDay(for: log.date, boundaryHour: boundaryHour)
                let hoursLeft = endOfRelapseDay.timeIntervalSince(log.date) / 3600.0
                if hoursLeft > 0 && hoursLeft < 6.0 {
                    penaltyDay = calendar.date(byAdding: .day, value: 1, to: day)
                } else {
                    penaltyDay = nil
                }
            }
        }
        
        let todayDetoxDay = DetoxDateHelper.detoxDay(for: Date(), boundaryHour: boundaryHour)
        if let lastActiveDay = prevDay {
            let diff = calendar.dateComponents([.day], from: lastActiveDay, to: todayDetoxDay).day ?? 0
            if diff > 1 {
                if let start = currentStreakStartDate, let end = currentStreakEndDate {
                    let endOfPrevDay = DetoxDateHelper.endOfDetoxDay(for: end, boundaryHour: boundaryHour)
                    context.insert(PastStreak(startDate: start, endDate: endOfPrevDay, failReason: "Пропущенные дни", failNotes: "Стрик прерван из-за пропущенных чекинов"))
                }
            }
        }
        
        // Add some mock data if they don't have old logs, for demonstration
        let firstDay = sortedLogs.first.map({ DetoxDateHelper.detoxDay(for: $0.date, boundaryHour: boundaryHour) })
        if firstDay == nil || firstDay! > calendar.date(byAdding: .day, value: -10, to: Date())! {
            let now = Date()
                if let s2Start = calendar.date(byAdding: .day, value: -8, to: now),
                   let s2End = calendar.date(byAdding: .hour, value: 14, to: calendar.date(byAdding: .day, value: -5, to: now)!) {
                    context.insert(PastStreak(startDate: s2Start, endDate: s2End, failReason: "Скука", failNotes: "Сорвался вечером от скуки. (Мок-данные)"))
                }
                if let s3Start = calendar.date(byAdding: .day, value: -14, to: now),
                   let s3End = calendar.date(byAdding: .hour, value: 12, to: calendar.date(byAdding: .day, value: -10, to: now)!) {
                    context.insert(PastStreak(startDate: s3Start, endDate: s3End, failReason: "Стресс", failNotes: "Тяжелый рабочий день. (Мок-данные)"))
                }
        }
        
        try? context.save()
    }
}
