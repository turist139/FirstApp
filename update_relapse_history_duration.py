with open("MyFocus/Views/Statistics/StatisticsView.swift", "r") as f:
    content = f.read()

bad_duration = """                                if let duration = log.relapseDuration {
                                    Text(duration)"""

good_duration = """                                if let duration = formattedRelapseDuration(for: log) {
                                    Text(duration)"""

content = content.replace(bad_duration, good_duration)

helper_method = """    private func formatShortDateAndTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter.string(from: date)
    }"""

new_helper_method = """    private func formatShortDateAndTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter.string(from: date)
    }
    
    private func formattedRelapseDuration(for log: DetoxLog) -> String? {
        if let endDate = log.endDate, endDate > log.date {
            let diff = endDate.timeIntervalSince(log.date)
            let days = Int(diff / 86400)
            let hours = Int((diff.truncatingRemainder(dividingBy: 86400)) / 3600)
            let minutes = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
            
            var components: [String] = []
            if days > 0 { components.append("\\(days) дн") }
            if hours > 0 { components.append("\\(hours) ч") }
            if minutes > 0 { components.append("\\(minutes) мин") }
            if components.isEmpty { components.append("Меньше минуты") }
            return components.joined(separator: " ")
        } else {
            return log.relapseDuration
        }
    }"""

content = content.replace(helper_method, new_helper_method)

with open("MyFocus/Views/Statistics/StatisticsView.swift", "w") as f:
    f.write(content)
