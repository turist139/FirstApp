with open("MyFocus/Views/Statistics/StatisticsView.swift", "r") as f:
    content = f.read()

content = content.replace("    private var selectedDayDetailsCard: some View {", """    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func formatShortDateAndTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private var selectedDayDetailsCard: some View {""")

with open("MyFocus/Views/Statistics/StatisticsView.swift", "w") as f:
    f.write(content)
