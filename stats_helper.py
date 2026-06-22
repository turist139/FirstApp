import re

with open("MyFocus/Views/Statistics/StatisticsView.swift", "r") as f:
    content = f.read()

# 1. Remove struct PastStreak
content = re.sub(r'    struct PastStreak: Identifiable \{[^\}]+\}\n', '', content)

# 2. Add history computation
new_history = """    var history: (streaks: [StreakHistoryItem], relapses: [RelapseHistoryItem]) {
        DetoxDateHelper.generateHistory(logs: activeLogs, profile: activeProfile, boundaryHour: detoxDayBoundaryHour)
    }
    
    var pastStreaks: [StreakHistoryItem] {
        history.streaks
    }
    
    var pastRelapses: [RelapseHistoryItem] {
        history.relapses
    }"""

# Replace the giant pastStreaks block
pattern = r'    var pastStreaks: \[PastStreak\] \{.*?\n    \}\n'
content = re.sub(pattern, new_history + '\n', content, flags=re.DOTALL)

# 3. Update dayLogs logic inside calendarCell
daylogs_pattern = r'        let dayLogs = activeLogs.filter \{\n            let logDay = DetoxDateHelper.detoxDay\(for: \$0.date, boundaryHour: detoxDayBoundaryHour\)\n            return calendar.isDate\(logDay, inSameDayAs: date\)\n        \}'
new_daylogs = """        let targetDetoxDay = DetoxDateHelper.detoxDay(for: date, boundaryHour: detoxDayBoundaryHour)
        let dayLogs = activeLogs.filter { log in
            let logStartDay = DetoxDateHelper.detoxDay(for: log.date, boundaryHour: detoxDayBoundaryHour)
            let logEndDay = DetoxDateHelper.detoxDay(for: log.endDate ?? log.date, boundaryHour: detoxDayBoundaryHour)
            return targetDetoxDay >= logStartDay && targetDetoxDay <= logEndDay
        }"""
content = content.replace(daylogs_pattern, new_daylogs)

# 4. formatStreakDurationValue should take StreakHistoryItem
content = content.replace("func formatStreakDurationValue(for streak: PastStreak)", "func formatStreakDurationValue(for streak: StreakHistoryItem)")

with open("MyFocus/Views/Statistics/StatisticsView.swift", "w") as f:
    f.write(content)
