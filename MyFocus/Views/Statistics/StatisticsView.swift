import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DetoxLog.date, order: .forward) private var logs: [DetoxLog]
    @Query private var progressQuery: [UserProgress]
    @Query private var profilesQuery: [DetoxProfile]
    
    var activeProfile: DetoxProfile? {
        let activeId = progress.activeProfileId
        return profilesQuery.first(where: { $0.id == activeId }) ?? profilesQuery.first
    }
    
    var activeLogs: [DetoxLog] {
        guard let profileId = activeProfile?.id else { return [] }
        return logs.filter { $0.profileId == profileId }
    }
    
    @AppStorage("detoxDayBoundaryHour", store: .shared) private var detoxDayBoundaryHour: Int = 0
    
    @State private var selectedDate: Date? = Date()
    @State private var showEditCheckIn: Bool = false
    @State private var editCheckInDate: Date = Date()
    @State private var editCheckInLogId: UUID? = nil
    @State private var showImpulsesHistory: Bool = false
    @State private var showStreaksHistory: Bool = false
    @State private var showProfileDrawer: Bool = false
    @State private var showCreateProfile: Bool = false
    
    enum CalendarMode {
        case last7Days
        case month
    }
    
    @State private var calendarMode: CalendarMode = .month
    
    enum CalendarDisplayMode {
        case status
        case tolerance
    }
    @State private var calendarDisplayMode: CalendarDisplayMode = .status
    @State private var currentMonthDate: Date = Date()
    
    @State private var showDeleteConfirmation = false
    @State private var logToDelete: DetoxLog? = nil
    
    struct PastStreak: Identifiable {
        let id = UUID()
        let length: Int
        let duration: TimeInterval?
        let startDate: Date
        let endDate: Date
        let reason: String
        let notes: String?
    }
    
    var progress: UserProgress {
        progressQuery.first ?? UserProgress()
    }
    
    // MARK: - Computed stats
    
    var totalSosCount: Int {
        activeLogs.reduce(0) { $0 + $1.sosCount }
    }
    
    var failLogs: [DetoxLog] {
        activeLogs.filter { !$0.isClean }
    }
    
    var failReasonsCount: [(reason: String, count: Int, percentage: Double)] {
        let fails = failLogs
        guard !fails.isEmpty else { return [] }
        
        var counts: [String: Int] = [:]
        for log in fails {
            let reason = log.failReason ?? "Другое"
            counts[reason, default: 0] += 1
        }
        
        let total = Double(fails.count)
        return counts.map { (reason: $0.key, count: $0.value, percentage: Double($0.value) / total) }
            .sorted { $0.count > $1.count }
    }
    
    var pastStreaks: [PastStreak] {
        guard !activeLogs.isEmpty else { return [] }
        let sortedLogs = activeLogs.sorted { $0.date < $1.date }
        var streaks: [PastStreak] = []
        var currentStreak: [DetoxLog] = []
        let calendar = Calendar.current
        var lastStreakStartDate = sortedLogs.first!.date
        
        for i in 0..<sortedLogs.count {
            let log = sortedLogs[i]
            
            if log.isClean || log.isRescued {
                if currentStreak.isEmpty {
                    currentStreak.append(log)
                } else {
                    if let lastLog = currentStreak.last {
                        let log1DetoxDay = DetoxDateHelper.detoxDay(for: lastLog.date, boundaryHour: detoxDayBoundaryHour)
                        let log2DetoxDay = DetoxDateHelper.detoxDay(for: log.date, boundaryHour: detoxDayBoundaryHour)
                        let daysDiff = calendar.dateComponents([.day], from: log1DetoxDay, to: log2DetoxDay).day ?? 0
                        if daysDiff <= 1 {
                            currentStreak.append(log)
                        } else {
                            // Streak broken due to check-in gap
                            let length = currentStreak.count
                            let duration = lastLog.date.timeIntervalSince(lastStreakStartDate)
                            if duration >= 60 {
                                streaks.append(PastStreak(length: length, duration: duration, startDate: lastStreakStartDate, endDate: lastLog.date, reason: "Пропущен чек-ин", notes: nil))
                            }
                            currentStreak = [log]
                            lastStreakStartDate = lastLog.date
                        }
                    }
                }
            } else {
                // Relapse without rescue (breaks streak)
                let length = currentStreak.count
                let duration = log.date.timeIntervalSince(lastStreakStartDate)
                let reason = log.failReason ?? "Срыв"
                let notes = log.failNotes
                
                if duration >= 60 {
                    streaks.append(PastStreak(length: length, duration: duration, startDate: lastStreakStartDate, endDate: log.date, reason: reason, notes: notes))
                }
                currentStreak = []
                lastStreakStartDate = log.date
            }
        }
        
        // Exclude the current active streak since it is still running!
        return streaks.reversed() // Show newest first
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    
                    // Demo Data Controls
                    demoDataControls
                    
                    // Summary Card (Moved above calendar)
                    summaryStatsCard
                    
                    // Calendar Card
                    calendarCard
                    
                    // Selected Day Details Card
                    selectedDayDetailsCard
                    
                    // Relapse Analysis Card
                    relapseAnalysisCard
                    
                }
                .padding()
            }
            .withAmbientGlow()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .background(Color.clear)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showProfileDrawer = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: activeProfile?.icon ?? "flame.fill")
                            Text(activeProfile?.name ?? "Статистика")
                                .font(.title3.bold())
                            Image(systemName: "chevron.down")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showEditCheckIn) {
                CheckInView(targetDate: editCheckInDate, targetLogId: editCheckInLogId, profile: activeProfile, progress: progress)
            }
            .sheet(isPresented: $showImpulsesHistory) {
                impulsesHistorySheet
            }
            .sheet(isPresented: $showStreaksHistory) {
                streaksHistorySheet
            }
            .alert("Удалить отчет?", isPresented: $showDeleteConfirmation, presenting: logToDelete) { targetLog in
                Button("Удалить", role: .destructive) {
                    modelContext.delete(targetLog)
                    try? modelContext.save()
                    
                    // Recalculate streak!
                    let remainingLogs = activeLogs.filter { $0.id != targetLog.id }
                    if let active = activeProfile {
                        DetoxDateHelper.recalculateStreak(logs: remainingLogs, boundaryHour: detoxDayBoundaryHour, profile: active)
                    }
                    selectedDate = selectedDate // trigger update
                }
                Button("Отмена", role: .cancel) {}
            } message: { targetLog in
                Text("Вы уверены, что хотите удалить отчет за \(formatLongDate(targetLog.date))? Данные будут стерты, а ваш стрик пересчитан.")
            }
        }
        .overlay {
            ProfileDrawerView(
                profiles: Array(profilesQuery),
                activeProfile: activeProfile,
                progress: progress,
                isOpen: $showProfileDrawer,
                showCreateProfile: $showCreateProfile
            )
            .animation(.easeInOut(duration: 0.25), value: showProfileDrawer)
        }
        .sheet(isPresented: $showCreateProfile) {
            CreateProfileView(progress: progress)
        }
        .task(id: activeProfile?.id) {
            if let active = activeProfile {
                DetoxDateHelper.recalculateStreak(logs: activeLogs, boundaryHour: detoxDayBoundaryHour, profile: active)
            }
        }
        .withSOSToolbar()
    }
    
    // MARK: - Subviews
    
    private var demoDataControls: some View {
        Group {
            if activeLogs.isEmpty {
                HStack {
                    Button(action: {
                        DetoxMockDataHelper.generateMockData(context: modelContext, profileId: activeProfile?.id)
                    }) {
                        Label("Загрузить демо-данные", systemImage: "square.and.arrow.down")
                            .font(.caption.bold())
                            .foregroundColor(.cyan)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(Color.cyan.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                            )
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var calendarCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("КАЛЕНДАРЬ ДЕТОКСА")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1)
                
                Spacer()
                
                Picker("Режим", selection: $calendarMode) {
                    Text("7 дней").tag(CalendarMode.last7Days)
                    Text("Месяц").tag(CalendarMode.month)
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }
            
            // Month navigation controls (Only in Month mode)
            if calendarMode == .month {
                HStack {
                    Button(action: {
                        withAnimation {
                            if let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonthDate) {
                                currentMonthDate = prevMonth
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Text(formatMonthYear(currentMonthDate).uppercased())
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    let canGoNext = Calendar.current.compare(currentMonthDate, to: Date(), toGranularity: .month) == .orderedAscending
                    Button(action: {
                        withAnimation {
                            if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonthDate) {
                                currentMonthDate = nextMonth
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(canGoNext ? .white : .white.opacity(0.3))
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canGoNext)
                }
                .padding(.vertical, 5)
            }
            
            // Calendar coloring mode picker
            Picker("Отображение", selection: $calendarDisplayMode) {
                Text("Статус").tag(CalendarDisplayMode.status)
                Text("Толерантность").tag(CalendarDisplayMode.tolerance)
            }
            .pickerStyle(.segmented)
            .padding(.top, 2)
            
            // Legend
            HStack(spacing: 8) {
                if calendarDisplayMode == .status {
                    legendItem(title: "Чист", color: .green)
                    legendItem(title: "Малый срыв", color: .cyan)
                    legendItem(title: "Средний", color: .blue)
                    legendItem(title: "Большой", color: Color(red: 0.05, green: 0.2, blue: 0.5))
                    legendItem(title: "Срыв", color: .red)
                } else {
                    legendItem(title: "1 (Низкая)", color: Color.purple.opacity(0.36))
                    legendItem(title: "2", color: Color.purple.opacity(0.52))
                    legendItem(title: "3", color: Color.purple.opacity(0.68))
                    legendItem(title: "4", color: Color.purple.opacity(0.84))
                    legendItem(title: "5 (Высокая)", color: Color.purple)
                }
            }
            .font(.system(size: 9))
            .foregroundColor(.white.opacity(0.5))
            
            // Weekday Headers (Only in month mode since days are not aligned to Mon-Sun in last 7 days mode)
            if calendarMode == .month {
                HStack(spacing: 0) {
                    let weekdays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.3))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 4)
            }
            
            // Calendar Grid
            let dates = generateCalendarDates()
            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(dates, id: \.self) { date in
                    Button(action: {
                        selectedDate = date
                    }) {
                        calendarCell(for: date)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 10)
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    private var summaryStatsCard: some View {
        HStack(spacing: 20) {
            // SOS stats
            Button(action: {
                showImpulsesHistory = true
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.title)
                        .foregroundColor(.purple)
                        .shadow(color: .purple.opacity(0.4), radius: 6)
                    
                    Text("\(totalSosCount)")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    
                    Text("Побеждено импульсов")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.03))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            
            // Longest streak stats
            Button(action: {
                showStreaksHistory = true
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.title)
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow.opacity(0.4), radius: 6)
                    
                    let maxHistory = pastStreaks.map { $0.length }.max() ?? 0
                    let actualLongest = max(activeProfile?.longestStreakDays ?? 0, max(maxHistory, activeProfile?.currentStreakDays ?? 0))
                    Text("\(actualLongest) дн")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    
                    Text("Лучший стрик")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.03))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var relapseAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("АНАЛИЗ ТРИГГЕРОВ СРЫВОВ")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.6))
                .tracking(1)
            
            if failLogs.isEmpty {
                Text("Отличный результат! У вас еще не было срывов.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: 14) {
                    ForEach(failReasonsCount, id: \.reason) { item in
                        VStack(spacing: 6) {
                            HStack {
                                Text(item.reason)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("\(item.count) р. (\(Int(item.percentage * 100))%)")
                                    .font(.caption.bold())
                                    .foregroundColor(.orange)
                            }
                            
                            // Custom progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * CGFloat(item.percentage), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Methods
    
    private func legendItem(title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
        }
    }
    
    private func generateCalendarDates() -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        
        if calendarMode == .last7Days {
            return (0..<7).compactMap { dayOffset in
                calendar.date(byAdding: .day, value: -dayOffset, to: now)
            }.reversed()
        }
        
        // Month mode: generate weeks for currentMonthDate
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonthDate)) ?? now
        
        // Find the Monday of the week containing startOfMonth
        let weekday = calendar.component(.weekday, from: startOfMonth) // 1 = Sunday, 2 = Monday, etc.
        let daysToSubtract = (weekday + 5) % 7
        let startMonday = calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfMonth) ?? startOfMonth
        
        // Generate 35 days (5 weeks) or 42 days (6 weeks)
        let endDay5Weeks = calendar.date(byAdding: .day, value: 34, to: startMonday) ?? startMonday
        let needs6Weeks = calendar.component(.month, from: endDay5Weeks) == calendar.component(.month, from: startOfMonth)
        let totalDaysToGenerate = needs6Weeks ? 42 : 35
        
        return (0..<totalDaysToGenerate).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startMonday)
        }
    }
    
    private func calendarCell(for date: Date) -> some View {
        let calendar = Calendar.current
        let dayNumber = calendar.component(.day, from: date)
        
        let currentDetoxDay = DetoxDateHelper.detoxDay(for: Date(), boundaryHour: detoxDayBoundaryHour)
        let isToday = calendar.isDate(currentDetoxDay, inSameDayAs: date)
        let isSelected = selectedDate != nil && calendar.isDate(selectedDate!, inSameDayAs: date)
        
        let logDetoxDay = DetoxDateHelper.detoxDay(for: date, boundaryHour: detoxDayBoundaryHour)
        let isFuture = logDetoxDay > currentDetoxDay
        
        // Find if a log exists for this date matching the detox day
        let dayLogs = activeLogs.filter {
            let logDay = DetoxDateHelper.detoxDay(for: $0.date, boundaryHour: detoxDayBoundaryHour)
            return calendar.isDate(logDay, inSameDayAs: date)
        }
        
        let log: DetoxLog?
        if let relapse = dayLogs.first(where: { !$0.isClean && !$0.isRescued && !$0.isMinorRelapse }) {
            log = relapse
        } else if let rescued = dayLogs.first(where: { !$0.isClean && ($0.isRescued || $0.isMinorRelapse) }) {
            log = rescued
        } else {
            log = dayLogs.first(where: { $0.isClean })
        }
        
        let isSameMonth = calendarMode == .last7Days || calendar.isDate(date, equalTo: currentMonthDate, toGranularity: .month)
        
        var cellColor = Color.white.opacity(0.08)
        var shadowColor = Color.clear
        var textColor = Color.white.opacity(0.4)
        
        if !isFuture, let log = log {
            if calendarDisplayMode == .status {
                textColor = .black
                if log.isClean {
                    cellColor = .green
                    shadowColor = .green.opacity(0.3)
                } else {
                    if log.isRescued || log.isMinorRelapse {
                        if log.isMinorRelapse {
                            cellColor = .cyan
                            shadowColor = .cyan.opacity(0.3)
                        } else if log.relapseDuration == "до двух часов" || log.relapseDuration == "до часа" {
                            cellColor = .blue
                            shadowColor = .blue.opacity(0.3)
                            textColor = .white
                        } else {
                            cellColor = Color(red: 0.05, green: 0.2, blue: 0.5)
                            shadowColor = Color(red: 0.05, green: 0.2, blue: 0.5).opacity(0.3)
                            textColor = .white
                        }
                    } else {
                        cellColor = .red
                        shadowColor = .red.opacity(0.3)
                    }
                }
            } else {
                // Tolerance display mode
                if let tolerance = log.silenceTolerance {
                    textColor = .white
                    let opacity = 0.2 + (Double(tolerance) * 0.16)
                    cellColor = Color.purple.opacity(opacity)
                    shadowColor = Color.purple.opacity(opacity * 0.4)
                } else {
                    cellColor = Color.white.opacity(0.15)
                    textColor = Color.white.opacity(0.7)
                }
            }
        }
        
        if !isSameMonth {
            textColor = Color.white.opacity(0.15)
            if !isSelected {
                cellColor = Color.clear
                shadowColor = .clear
            }
        }
        
        return VStack(spacing: 4) {
            Text("\(dayNumber)")
                .font(.caption.bold())
                .foregroundColor(textColor)
                .frame(width: 28, height: 28)
                .background(cellColor)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.white : (isToday ? Color.green : Color.clear), lineWidth: 2)
                )
                .shadow(color: shadowColor, radius: 4)
            
            // Show weekday letter if 7days mode
            if calendarMode == .last7Days {
                Text(formatWeekday(date: date))
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    private func formatWeekday(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EE"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func formatLongDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func formatMonthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private var selectedDayDetailsCard: some View {
        guard let date = selectedDate else { return AnyView(EmptyView()) }
        
        let calendar = Calendar.current
        let currentDetoxDay = DetoxDateHelper.detoxDay(for: Date(), boundaryHour: detoxDayBoundaryHour)
        let targetDetoxDay = DetoxDateHelper.detoxDay(for: date, boundaryHour: detoxDayBoundaryHour)
        let isFuture = targetDetoxDay > currentDetoxDay
        
        // Find all logs matching the detox day
        let dayLogs = activeLogs.filter {
            let logDay = DetoxDateHelper.detoxDay(for: $0.date, boundaryHour: detoxDayBoundaryHour)
            return calendar.isDate(logDay, inSameDayAs: date)
        }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("ДЕНЬ ДЕТОКСА: \(formatLongDate(date))")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1)
                    
                    Spacer()
                    
                    if !isFuture {
                        Button(action: {
                            editCheckInDate = date
                            editCheckInLogId = nil
                            showEditCheckIn = true
                        }) {
                            Image(systemName: "plus")
                                .font(.subheadline.bold())
                                .foregroundColor(.white.opacity(0.6))
                                .padding(8)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if isFuture {
                    Text("Этот день еще не наступил.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                } else if !dayLogs.isEmpty {
                    VStack(spacing: 16) {
                        ForEach(dayLogs) { log in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text("Статус:")
                                                .foregroundColor(.white.opacity(0.6))
                                            
                                            if log.isClean {
                                                Label {
                                                    Text("Чистый день")
                                                } icon: {
                                                    Image(systemName: "checkmark.seal.fill")
                                                        .foregroundColor(.green)
                                                }
                                                .foregroundColor(.green)
                                                .bold()
                                            } else if log.isRescued || log.isMinorRelapse {
                                                let severity = log.relapseDuration == "пару минут" ? "Малый" : (log.relapseDuration == "до двух часов" || log.relapseDuration == "до часа" ? "Средний" : "Большой")
                                                let color = log.relapseDuration == "пару минут" ? Color.cyan : (log.relapseDuration == "до двух часов" || log.relapseDuration == "до часа" ? Color.blue : Color(red: 0.3, green: 0.6, blue: 1.0))
                                                Label {
                                                    Text("Неполный срыв (\(severity), спасен)")
                                                } icon: {
                                                    Image(systemName: "exclamationmark.triangle.fill")
                                                        .foregroundColor(color)
                                                }
                                                .foregroundColor(color)
                                                .bold()
                                            } else {
                                                Label {
                                                    Text("Срыв")
                                                } icon: {
                                                    Image(systemName: "xmark.octagon.fill")
                                                        .foregroundColor(.red)
                                                }
                                                .foregroundColor(.red)
                                                .bold()
                                            }
                                        }
                                        
                                        // Display the exact time of the log!
                                        Text(formatTime(log.date))
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        editCheckInDate = log.date
                                        editCheckInLogId = log.id
                                        showEditCheckIn = true
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.caption.bold())
                                            .foregroundColor(.white.opacity(0.8))
                                            .padding(6)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: {
                                        self.logToDelete = log
                                        showDeleteConfirmation = true
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.caption.bold())
                                            .foregroundColor(.red.opacity(0.8))
                                            .padding(6)
                                            .background(Color.red.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                if let tolerance = log.silenceTolerance {
                                    HStack {
                                        Text("Толерантность к тишине:")
                                            .foregroundColor(.white.opacity(0.6))
                                        Text("\(tolerance) из 5")
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                if !log.isClean {
                                    if let duration = log.relapseDuration {
                                        HStack {
                                            Text("Длительность срыва:")
                                                .foregroundColor(.white.opacity(0.6))
                                            Text(duration)
                                                .foregroundColor(.white)
                                        }
                                    }
                                    
                                    if let reason = log.failReason {
                                        HStack {
                                            Text("Триггер:")
                                                .foregroundColor(.white.opacity(0.6))
                                            Text(reason)
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                
                                if let notes = log.failNotes, !notes.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Заметки / Рефлексия:")
                                            .foregroundColor(.white.opacity(0.6))
                                        Text(notes)
                                            .font(.footnote)
                                            .foregroundColor(.white.opacity(0.9))
                                            .padding(10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.white.opacity(0.04))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
                            )
                        }
                    }
                    .font(.subheadline)
                } else {
                    Text("Нет данных за этот день. Вы можете добавить отчет вручную, нажав кнопку выше.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .background(Color.white.opacity(0.04))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        )
    }
    
    // MARK: - Detail Sheets
    
    private var impulsesHistorySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    let logsWithSos = activeLogs.filter { $0.sosCount > 0 }.sorted { $0.date > $1.date }
                    
                    if logsWithSos.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "bolt.shield")
                                .font(.system(size: 60))
                                .foregroundColor(.purple.opacity(0.5))
                                .padding(.top, 40)
                            
                            Text("История пуста")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("Когда вы воспользуетесь кнопкой SOS и успешно преодолеете тягу, здесь появится подробная история.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                    } else {
                        ForEach(logsWithSos) { log in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(formatLongDate(log.date))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text("Побеждено: \(log.sosCount)")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.purple)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 10)
                                        .background(Color.purple.opacity(0.15))
                                        .cornerRadius(8)
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                if let times = log.sosTimes, !times.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(times, id: \.self) { time in
                                                HStack(spacing: 4) {
                                                    Image(systemName: "clock")
                                                        .font(.caption2)
                                                    Text(formatTime(time))
                                                        .font(.caption.bold())
                                                }
                                                .foregroundColor(.white)
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 10)
                                                .background(Color.white.opacity(0.06))
                                                .cornerRadius(12)
                                            }
                                        }
                                    }
                                } else {
                                    Text("Количество: \(log.sosCount) (время не записано)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("История импульсов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        showImpulsesHistory = false
                    }
                    .foregroundColor(.white)
                }
            }
            .withAmbientGlow()
        }
    }
    
    private var streaksHistorySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    let completedStreaks = pastStreaks
                    
                    if completedStreaks.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "crown")
                                .font(.system(size: 60))
                                .foregroundColor(.yellow.opacity(0.5))
                                .padding(.top, 40)
                            
                            Text("Нет завершенных стриков")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("Когда ваш текущий стрик прервется, его детальная история сохранится здесь.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                    } else {
                        ForEach(completedStreaks) { streak in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 15) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.orange.opacity(0.15))
                                            .frame(width: 48, height: 48)
                                        
                                        Text(formatStreakDurationValue(for: streak))
                                            .font(.headline)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Период чистого разума")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white)
                                        
                                        Text("\(formatShortDate(streak.startDate)) — \(formatShortDate(streak.endDate))")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    
                                    Spacer()
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .top) {
                                        Text("Причина окончания:")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.5))
                                            .frame(width: 130, alignment: .leading)
                                        
                                        Text(streak.reason)
                                            .font(.caption.bold())
                                            .foregroundColor(.red.opacity(0.8))
                                    }
                                    
                                    if let notes = streak.notes, !notes.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Рефлексия срыва:")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.5))
                                            
                                            Text(notes)
                                                .font(.footnote)
                                                .foregroundColor(.white.opacity(0.8))
                                                .padding(10)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.white.opacity(0.04))
                                                .cornerRadius(8)
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("История стриков")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        showStreaksHistory = false
                    }
                    .foregroundColor(.white)
                }
            }
            .withAmbientGlow()
        }
    }
    
    private func formatStreakDurationValue(for streak: PastStreak) -> String {
        guard let duration = streak.duration, streak.length == 0 else {
            return "\(streak.length)д"
        }
        let hours = Int(duration) / 3600
        if hours > 0 {
            return "\(hours)ч"
        }
        let minutes = (Int(duration) % 3600) / 60
        return "\(minutes)м"
    }
}
