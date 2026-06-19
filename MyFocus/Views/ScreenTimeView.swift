import SwiftUI
import SwiftData
import AVFoundation
import Combine

struct ScreenTimeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var progressQuery: [UserProgress]
    @Query(sort: \DetoxLog.date, order: .forward) private var logs: [DetoxLog]
    @Query private var profilesQuery: [DetoxProfile]
    
    var activeProfile: DetoxProfile? {
        let activeId = progress.activeProfileId
        return profilesQuery.first(where: { $0.id == activeId }) ?? profilesQuery.first
    }
    
    var activeLogs: [DetoxLog] {
        guard let profileId = activeProfile?.id else { return [] }
        return logs.filter { $0.profileId == profileId }
    }
    
    var todayLog: DetoxLog? {
        activeLogs.first { DetoxDateHelper.isDateSameDetoxDay($0.date, Date(), boundaryHour: currentBoundaryHour) }
    }
    
    @AppStorage("customMantra") private var customMantra: String = "продержись всего сегодняшний день"
    @State private var showSOS = false
    @State private var showRecovery = false
    @State private var showHabitSettings = false
    @State private var showCheckInSheet = false
    @State private var showCreateProfile = false
    @State private var showProfileDrawer = false
    @State private var newHabitName = ""
    @State private var countdownString = "00:00:00"
    @State private var showDeleteConfirmation = false
    @State private var habitToDelete: String? = nil

    
    @AppStorage("activePalette", store: .shared) private var activePalette: String = "default"
    @AppStorage("detoxDayBoundaryHour", store: .shared) private var detoxDayBoundaryHour: Int = 0
    
    @AppStorage("todayBoundaryHourOverride", store: .shared) private var todayBoundaryHourOverride: Int = -1
    @AppStorage("todayBoundaryOverrideDate", store: .shared) private var todayBoundaryOverrideDate: String = ""
    @State private var showTodayBoundaryPicker = false
    
    // Timer to update the countdown every second
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var progress: UserProgress {
        if let existing = progressQuery.first {
            return existing
        } else {
            let newProgress = UserProgress()
            modelContext.insert(newProgress)
            return newProgress
        }
    }
    
    var currentBoundaryHour: Int {
        if todayBoundaryHourOverride >= 0 {
            let defaultDetoxDay = DetoxDateHelper.detoxDay(for: Date(), boundaryHour: detoxDayBoundaryHour)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let currentDateString = formatter.string(from: defaultDetoxDay)
            
            if currentDateString == todayBoundaryOverrideDate {
                return todayBoundaryHourOverride
            }
        }
        return detoxDayBoundaryHour
    }
    
    var themeColor: Color {
        PaletteManager.shared.paletteColors[activePalette]?.first ?? .green
    }
    
    var themeColors: [Color] {
        PaletteManager.shared.paletteColors[activePalette] ?? [.green]
    }
    
    var hasCheckedInToday: Bool {
        guard let lastCheck = activeProfile?.lastCheckInDate else { return false }
        return DetoxDateHelper.isDateSameDetoxDay(lastCheck, Date(), boundaryHour: currentBoundaryHour)
    }
    
    var isStreakBroken: Bool {
        guard let lastCheck = activeProfile?.lastCheckInDate else { return false }
        let currentDetoxDay = DetoxDateHelper.detoxDay(for: Date(), boundaryHour: currentBoundaryHour)
        let lastCheckDetoxDay = DetoxDateHelper.detoxDay(for: lastCheck, boundaryHour: currentBoundaryHour)
        
        let calendar = Calendar.current
        let diff = calendar.dateComponents([.day], from: lastCheckDetoxDay, to: currentDetoxDay).day ?? 0
        return diff > 1
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    
                    // 1. Countdown & Status Card (Streak days is primary)
                    countdownCard

                    // 2. Badges (Жетоны) Section (Only last unlocked)
                    badgesSection
                    
                    // 3. Daily Check-in Buttons
                    checkInSection
                    
                    // 4. Habits (Anti-Goals) List (moved to the end of the page)
                    habitsSection
                    
                    // 5. Relapse Button
                    Button(action: {
                        showRecovery = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Я сорвался...")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0.5, green: 0.0, blue: 0.0)) // Dark red
                                .shadow(color: Color.red.opacity(0.3), radius: 10, y: 5)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                    
                }
                .padding()
            }
            .withAmbientGlow()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showProfileDrawer = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: activeProfile?.icon ?? "flame.fill")
                            Text(activeProfile?.name ?? "Трекинг")
                                .font(.title3.bold())
                            Image(systemName: "chevron.down")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showRecovery) {
                StreakRecoveryView()
            }
            .sheet(isPresented: $showHabitSettings) {
                habitSettingsSheet
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showCheckInSheet) {
                CheckInView(profile: activeProfile, progress: progress)
            }
            .sheet(isPresented: $showCreateProfile) {
                CreateProfileView(progress: progress)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showTodayBoundaryPicker) {
                todayBoundaryPickerSheet
            }
            .onAppear {
                NotificationManager.shared.requestPermission()
                updateCountdown()
                checkRecoveryStatus()
                burnPaletteIfExpired()
            }
            .onReceive(timer) { _ in
                updateCountdown()
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
        .withSOSToolbar()
    }
    // MARK: - Subviews
    
    private var activeHours: Int {
        return DetoxDateHelper.calculateActiveHours(from: activeProfile?.streakStartDate, creationDate: activeProfile?.creationDate ?? Date())
    }
    
    private var realStreakDays: Int {
        return DetoxDateHelper.calculateStreakDays(from: activeProfile?.streakStartDate, creationDate: activeProfile?.creationDate ?? Date(), boundaryHour: currentBoundaryHour)
    }
    
    private func hoursString(for hours: Int) -> String {
        let mod10 = hours % 10
        let mod100 = hours % 100
        if mod100 >= 11 && mod100 <= 14 {
            return "часов детокса"
        } else if mod10 == 1 {
            return "час детокса"
        } else if mod10 >= 2 && mod10 <= 4 {
            return "часа детокса"
        } else {
            return "часов детокса"
        }
    }
    
    private var countdownCard: some View {
        VStack(spacing: 10) {
            if realStreakDays < 1 {
                HStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(themeColor)
                    Text("\(activeHours)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(themeColor)
                }
                .shadow(color: themeColor.opacity(0.4), radius: 12)
                
                Text(hoursString(for: activeHours).uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(2)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(themeColor)
                    Text("\(realStreakDays)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(themeColor)
                }
                .shadow(color: themeColor.opacity(0.4), radius: 12)
                
                Text("дней детокса".uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(2)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 8)
            
            Text(countdownString)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(themeColor)
            
            let completedSosToday = todayLog?.sosCount ?? 0 > 0
            HStack(spacing: 6) {
                Text(hasCheckedInToday ? "Следующий день начнется в \(DetoxDateHelper.formatBoundaryHour(currentBoundaryHour))" : (completedSosToday ? "\(customMantra) (конец в \(DetoxDateHelper.formatBoundaryHour(currentBoundaryHour)))" : "Осталось сегодня (конец в \(DetoxDateHelper.formatBoundaryHour(currentBoundaryHour)))"))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
                
                Button(action: {
                    showTodayBoundaryPicker = true
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(5)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.white.opacity(0.05))
                .padding(.vertical, 4)
            
            milestoneProgressBar
        }
        .padding(.vertical, 24)
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    

    
    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ЧТО МЫ ИЗБЕГАЕМ:")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1)
                
                Spacer()
                
                Button(action: {
                    showHabitSettings.toggle()
                }) {
                    Image(systemName: "pencil")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.6))
                        .padding(6)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            if (activeProfile?.detoxHabits ?? []).isEmpty {
                Text("Список пуст. Нажмите карандаш справа вверху, чтобы добавить цели.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.vertical, 5)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(activeProfile?.detoxHabits ?? [], id: \.self) { habit in
                        HStack(spacing: 6) {
                            Image(systemName: "nosign")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text(habit)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(20)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
    }
    
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ПОСЛЕДНИЙ ДОСТИГНУТЫЙ ЖЕТОН")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.5))
                .tracking(1)
            
            let streak = realStreakDays
            
            if streak == 0 {
                HStack(spacing: 15) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 54, height: 54)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        
                        Image(systemName: "medal")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.2))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Нет жетонов")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text("Начните детокс сегодня!")
                            .font(.caption)
                              .foregroundColor(.white.opacity(0.3))
                    }
                    Spacer()
                }
                .padding()
                .background(Color.white.opacity(0.03))
                .cornerRadius(16)
            } else {
                let badgeName = streak >= 365 ? "Алмазный год" : (streak >= 100 ? "Изумрудный век" : (streak >= 30 ? "Мастер детокса" : (streak >= 15 ? "Победитель" : (streak >= 7 ? "Неделя силы" : (streak >= 3 ? "Чистый разум" : "Первый шаг")))))
                let badgeSubText = streak >= 365 ? "Целый год триумфа" : (streak >= 100 ? "Вековая стойкость" : (streak >= 30 ? "Золотой стандарт" : (streak >= 15 ? "Власть над импульсом" : (streak >= 7 ? "Новая привычка" : (streak >= 3 ? "Мысли проясняются" : "Свобода началась")))))
                let badgeIcon = streak >= 365 ? "suit.diamond.fill" : (streak >= 100 ? "crown.fill" : (streak >= 30 ? "trophy.fill" : (streak >= 15 ? "flame.fill" : (streak >= 7 ? "shield.fill" : (streak >= 3 ? "sparkles" : "medal.fill")))))
                let badgeDays = streak >= 365 ? 365 : (streak >= 100 ? 100 : (streak >= 30 ? 30 : (streak >= 15 ? 15 : (streak >= 7 ? 7 : (streak >= 3 ? 3 : 1)))))
                
                HStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(themeColor.opacity(0.15))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle()
                                    .stroke(themeColor, lineWidth: 2)
                            )
                            .shadow(color: themeColor.opacity(0.4), radius: 8)
                        
                        Image(systemName: badgeIcon)
                            .font(.title3)
                            .foregroundColor(themeColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(badgeName)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("\(badgeDays) дн.")
                                .font(.caption2.bold())
                                .foregroundColor(themeColor)
                                .padding(.vertical, 2)
                                .padding(.horizontal, 6)
                                .background(themeColor.opacity(0.15))
                                .cornerRadius(6)
                        }
                        
                        Text(badgeSubText)
                            .font(.subheadline)
                            .foregroundColor(themeColor.opacity(0.8))
                    }
                    Spacer()
                }
                  .padding()
                  .background(Color.white.opacity(0.03))
                  .cornerRadius(16)
              }
          }
          .padding()
          .background(Color.white.opacity(0.03))
          .cornerRadius(16)
      }
    
    private var checkInSection: some View {
        VStack(spacing: 15) {
            if hasCheckedInToday {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 32))
                            .foregroundColor(themeColor)
                            .shadow(color: themeColor.opacity(0.3), radius: 8)
                        
                        Text("Чек-ин выполнен!")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Ваш стрик сохранен: \(realStreakDays) дн. Отличная работа!")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showCheckInSheet = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.body.bold())
                            .foregroundColor(.white.opacity(0.6))
                            .padding(10)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
            } else {
                Button(action: {
                    showCheckInSheet = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.title3)
                        Text("Пройти чек-ин за сегодня")
                            .font(.headline)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(themeColor)
                    .cornerRadius(16)
                    .shadow(color: themeColor.opacity(0.3), radius: 8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var habitSettingsSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Редактирование целей")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.top)
                
                HStack {
                    TextField("Новая вредная привычка...", text: $newHabitName)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    Button(action: addHabit) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .disabled(newHabitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                
                List {
                    ForEach(activeProfile?.detoxHabits ?? [], id: \.self) { habit in
                        HStack {
                            Text(habit)
                                .foregroundColor(.white)
                                .font(.body)
                            Spacer()
                            Button(action: {
                                habitToDelete = habit
                                showDeleteConfirmation = true
                            }) {
                                Image(systemName: "trash")
                                    .font(.title3)
                                    .foregroundColor(.red.opacity(0.9))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onDelete { indexSet in
                        if let index = indexSet.first, let habits = activeProfile?.detoxHabits {
                            habitToDelete = habits[index]
                            showDeleteConfirmation = true
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listStyle(.plain)
            }
            .withAmbientGlow()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        showHabitSettings = false
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Удалить цель?", isPresented: $showDeleteConfirmation, presenting: habitToDelete) { habit in
                Button("Удалить", role: .destructive) {
                    removeHabit(habit)
                }
                Button("Отмена", role: .cancel) {}
            } message: { habit in
                Text("Вы уверены, что хотите удалить цель «\(habit)»?")
            }

        }
    }
    
    // MARK: - Helper Views
    

    
    // MARK: - Actions & Logic
    
    private func updateCountdown() {
        let now = Date()
        var targetEnd = DetoxDateHelper.endOfDetoxDay(for: now, boundaryHour: currentBoundaryHour)
        
        if activeProfile?.currentStreakDays ?? 0 == 0, let start = activeProfile?.streakStartDate {
            let firstEnd = DetoxDateHelper.endOfDetoxDay(for: start, boundaryHour: currentBoundaryHour)
            let hoursBetweenStartAndFirstEnd = firstEnd.timeIntervalSince(start) / 3600.0
            if hoursBetweenStartAndFirstEnd > 0 && hoursBetweenStartAndFirstEnd < 6.0 {
                // Relapse was < 6 hours before boundary, Day 1 target is the NEXT day's boundary
                let day1Boundary = Calendar.current.date(byAdding: .day, value: 1, to: firstEnd) ?? targetEnd
                if now < day1Boundary {
                    targetEnd = day1Boundary
                }
            }
        }
        
        let diff = targetEnd.timeIntervalSince(now)
        
        if diff > 0 {
            let hours = Int(diff) / 3600
            let minutes = (Int(diff) % 3600) / 60
            let seconds = Int(diff) % 60
            countdownString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            countdownString = "00:00:00"
            if todayBoundaryHourOverride >= 0 {
                todayBoundaryHourOverride = -1
                todayBoundaryOverrideDate = ""
            }
        }
    }
    
    private var milestoneProgressBar: some View {
        let streak = realStreakDays
        let milestones = [1, 3, 7, 15, 30]
        
        let next: Int
        let prog: Double
        
        if let firstNext = milestones.first(where: { $0 > streak }) {
            next = firstNext
            prog = Double(streak) / Double(next)
        } else {
            next = 30
            prog = 1.0
        }
        
        return VStack(spacing: 8) {
            HStack {
                Text("0 дн.")
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                if streak >= 30 {
                    Text("Максимальный milestone достигнут! 🎉")
                        .font(.caption2.bold())
                        .foregroundColor(.yellow)
                } else {
                    let daysLeft = next - streak
                    Text("До следующего жетона: \(daysLeft) \(daysLeft.pluralRu(one: "день", few: "дня", many: "дней"))")
                        .font(.caption2.bold())
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Text("\(next) дн.")
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.5))
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: themeColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(prog), height: 8)
                        .shadow(color: themeColor.opacity(0.4), radius: 4)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    private func checkRecoveryStatus() {
        // Automatically check if yesterday check-in was missed (broken streak)
        if isStreakBroken && (activeProfile?.currentStreakDays ?? 0) > 0 && !(activeProfile?.streakSavedToday ?? false) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showRecovery = true
            }
        }
    }
    
    private func claimCleanDay() {
        withAnimation {
            activeProfile?.lastCheckInDate = Date()
            progress.lastActiveDate = Date()
            activeProfile?.currentStreakDays += 1
            activeProfile?.streakSavedToday = false // Reset saved today for next day
            
            if (activeProfile?.currentStreakDays ?? 0) > (activeProfile?.longestStreakDays ?? 0) {
                activeProfile?.longestStreakDays = activeProfile?.currentStreakDays ?? 0
            }
            
            // Log clean day in SwiftData
            let log = DetoxLog(date: Date(), isClean: true, profileId: activeProfile?.id)
            modelContext.insert(log)
            
            // Check theme unlocking based on new requirements:
            // 1 day: Sunset (palette_2)
            // 3 days: Forest (palette_3)
            // 7 days: Space (palette_4)
            // 15 days: Fire (palette_5)
            // 30 days: Gold (palette_gold)
            unlockThemesForCurrentStreak()
            
            // Re-schedule notifications
            NotificationManager.shared.scheduleReminders(lastCheckInDate: Date())
            
            playCheckInSound()
        }
    }
    
    private func unlockThemesForCurrentStreak() {
        let streak = realStreakDays
        
        func unlock(_ id: String) {
            if !progress.unlockedPaletteIDs.contains(id) {
                progress.unlockedPaletteIDs.append(id)
            }
        }
        
        if streak >= 1 { unlock("palette_2") }
        if streak >= 3 { unlock("palette_3") }
        if streak >= 7 { unlock("palette_4") }
        if streak >= 15 { unlock("palette_5") }
        if streak >= 30 { unlock("palette_gold") }
        if streak >= 100 { unlock("palette_100") }
        if streak >= 365 { unlock("palette_365") }
    }
    
    private func addHabit() {
        let name = newHabitName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if !(activeProfile?.detoxHabits.contains(name) ?? false) {
            activeProfile?.detoxHabits.append(name)
        }
        newHabitName = ""
    }
    
    private func removeHabit(_ name: String) {
        activeProfile?.detoxHabits.removeAll { $0 == name }
    }
    
    private func playCheckInSound() {
        #if targetEnvironment(macCatalyst)
        if let url = URL(string: "file:///System/Library/Sounds/Ping.aiff") {
            var soundId: SystemSoundID = 0
            AudioServicesCreateSystemSoundID(url as CFURL, &soundId)
            AudioServicesPlaySystemSound(soundId)
        }
        #else
        AudioServicesPlaySystemSound(1025) // Check success sound
        #endif
    }
    
    private func burnPaletteIfExpired() {
        let streak = realStreakDays
        if !PaletteManager.shared.isPaletteUnlocked(id: activePalette, currentStreak: streak) {
            withAnimation {
                activePalette = "default"
            }
        }
    }
    
    private var todayBoundaryPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 25) {
                Text("Изменить конец сегодняшнего дня")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top)
                
                Text("Выберите время, в которое для вас закончится текущий день детокса. Это изменение применится ТОЛЬКО на сегодня.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                let currentSelection = Binding<Int>(
                    get: { currentBoundaryHour },
                    set: { newHour in
                        let defaultDetoxDay = DetoxDateHelper.detoxDay(for: Date(), boundaryHour: detoxDayBoundaryHour)
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        todayBoundaryOverrideDate = formatter.string(from: defaultDetoxDay)
                        todayBoundaryHourOverride = newHour
                        updateCountdown()
                    }
                )
                
                Picker("Время окончания", selection: currentSelection) {
                    Group {
                        Text("18:00 (6:00 PM)").tag(18)
                        Text("19:00 (7:00 PM)").tag(19)
                        Text("20:00 (8:00 PM)").tag(20)
                        Text("21:00 (9:00 PM)").tag(21)
                        Text("22:00 (10:00 PM)").tag(22)
                        Text("23:00 (11:00 PM)").tag(23)
                        Text("00:00 (Полночь)").tag(0)
                    }
                    Group {
                        Text("01:00 AM").tag(1)
                        Text("02:00 AM").tag(2)
                        Text("03:00 AM").tag(3)
                        Text("04:00 AM").tag(4)
                        Text("05:00 AM").tag(5)
                        Text("06:00 AM").tag(6)
                    }
                }
                .pickerStyle(.wheel)
                .colorScheme(.dark)
                .frame(height: 150)
                
                Spacer()
                
                Button(action: {
                    showTodayBoundaryPicker = false
                }) {
                    Text("Готово")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeColor)
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .withAmbientGlow()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if todayBoundaryHourOverride >= 0 {
                        Button("Сбросить") {
                            todayBoundaryHourOverride = -1
                            todayBoundaryOverrideDate = ""
                            updateCountdown()
                            showTodayBoundaryPicker = false
                        }
                        .foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Отмена") {
                        showTodayBoundaryPicker = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - FlowLayout Helper
/// A helper view to arrange habit capsules in wrapped rows
struct FlowLayout: View {
    let spacing: CGFloat
    let alignment: HorizontalAlignment = .leading
    let content: () -> [AnyView]
    
    init<Content: View>(spacing: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = {
            if let group = content() as? TupleView<Any> {
                // If it is tuple, we convert to list
                return []
            }
            return [AnyView(content())]
        }
    }
    
    // Simpler fallback constructor for arrays
    init(spacing: CGFloat, views: [AnyView]) {
        self.spacing = spacing
        self.content = { views }
    }
    
    // We override content to support building arrays of elements
    init<Data: RandomAccessCollection, V: View>(
        spacing: CGFloat,
        @ViewBuilder content: @escaping () -> ForEach<Data, Data.Element, V>
    ) {
        self.spacing = spacing
        self.content = {
            let forEach = content()
            return forEach.data.map { element in
                AnyView(forEach.content(element))
            }
        }
    }
    
    @State private var totalHeight = CGFloat.zero
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)
    }
    
    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        let views = content()
        
        return ZStack(alignment: .topLeading) {
            ForEach(0..<views.count, id: \.self) { index in
                views[index]
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > g.size.width) {
                            width = 0
                            height -= d.height + spacing
                        }
                        let result = width
                        if index == views.count - 1 {
                            width = 0 // last item
                        } else {
                            width -= d.width + spacing
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if index == views.count - 1 {
                            height = 0 // last item
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
    }
    
    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}

extension Int {
    func pluralRu(one: String, few: String, many: String) -> String {
        let mod10 = self % 10
        let mod100 = self % 100
        if mod100 >= 11 && mod100 <= 19 {
            return many
        }
        if mod10 == 1 {
            return one
        }
        if mod10 >= 2 && mod10 <= 4 {
            return few
        }
        return many
    }
}
