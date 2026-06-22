with open("MyFocus/Views/Statistics/StatisticsView.swift", "r") as f:
    content = f.read()

bad_closure_1 = """        let dayLogs = activeLogs.filter { log in
            let logStartDay = calendar.startOfDay(for: DetoxDateHelper.detoxDay(for: log.date, boundaryHour: detoxDayBoundaryHour))
            let logEndDay = calendar.startOfDay(for: log.endDate != nil ? DetoxDateHelper.detoxDay(for: log.endDate!, boundaryHour: detoxDayBoundaryHour) : log.date)
            return cellDayStart >= logStartDay && cellDayStart <= logEndDay
        }"""

good_closure_1 = """        let dayLogs: [DetoxLog] = activeLogs.filter { (log: DetoxLog) -> Bool in
            let logStartDay: Date = calendar.startOfDay(for: DetoxDateHelper.detoxDay(for: log.date, boundaryHour: detoxDayBoundaryHour))
            let fallbackDate: Date = log.endDate ?? log.date
            let logEndDay: Date = calendar.startOfDay(for: DetoxDateHelper.detoxDay(for: fallbackDate, boundaryHour: detoxDayBoundaryHour))
            return cellDayStart >= logStartDay && cellDayStart <= logEndDay
        }"""

content = content.replace(bad_closure_1, good_closure_1)

with open("MyFocus/Views/Statistics/StatisticsView.swift", "w") as f:
    f.write(content)
