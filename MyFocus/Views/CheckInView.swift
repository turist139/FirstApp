import SwiftUI
import SwiftData

struct CheckInView: View {
    var targetDate: Date = Date()
    var targetLogId: UUID? = nil
    var forceNewLog: Bool = false
    var profile: DetoxProfile?
    var progress: UserProgress
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DetoxLog.date, order: .forward) private var logs: [DetoxLog]
    
    var activeLogs: [DetoxLog] {
        guard let profileId = profile?.id else { return [] }
        return logs.filter { $0.profileId == profileId }
    }
    
    @AppStorage("detoxDayBoundaryHour", store: .shared) private var detoxDayBoundaryHour: Int = 0
    
    // Core check-in state
    @State private var silenceTolerance: Int = 3
    @State private var didRelapse: Bool = false
    @State private var relapseDuration: String = "пару минут"
    @State private var failReason: String = "Скука"
    @State private var customFailReason: String = ""
    @State private var failNotes: String = ""
    @State private var hasExistingLog: Bool = false
    @State private var currentTargetDate: Date = Date()
    @State private var specifyRelapseTime: Bool = false
    @State private var relapseTime: Date = Date()
    
    let durations = ["пару минут", "до двух часов", "день"]
    let reasons = ["\"один раз\"", "Усталость", "Тревога", "Автопилот", "Скука", "Голод", "Другое"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    // 1. Header description
                    VStack(spacing: 6) {
                        Text(formatTargetDate(currentTargetDate))
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text("Честный отчет о дне помогает поддерживать осознанность.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 10)
                    
                    // 2. Silence Tolerance Card (Толерантность к тишине)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("ТОЛЕРАНТНОСТЬ К ТИШИНЕ")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.5)
                        
                        Text("Насколько комфортно вам было наедине со своими мыслями (1 - тяжело, 5 - отлично)?")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { num in
                                Button(action: {
                                    withAnimation {
                                        silenceTolerance = num
                                    }
                                }) {
                                    Text("\(num)")
                                        .font(.headline)
                                        .foregroundColor(silenceTolerance == num ? .black : .white)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle()
                                                .fill(silenceTolerance == num ? Color.green : Color.white.opacity(0.08))
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.15), lineWidth: silenceTolerance == num ? 0 : 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    
                    // 3. Relapse Status Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("СТАТУС ДЕТОКСА")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.5)
                        
                        Text("Вы нарушили в этот день свои лимиты (сорвались)?")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                withAnimation {
                                    didRelapse = false
                                }
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Нет, я чист")
                                }
                                .font(.headline)
                                .foregroundColor(didRelapse ? .white : .black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(didRelapse ? Color.white.opacity(0.1) : Color.green)
                                .cornerRadius(14)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                withAnimation {
                                    didRelapse = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text("Да, я сорвался")
                                }
                                .font(.headline)
                                .foregroundColor(didRelapse ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(didRelapse ? Color.orange : Color.white.opacity(0.1))
                                .cornerRadius(14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    
                    // 4. Conditional Relapse Fields
                    if didRelapse {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("ДЕТАЛИ СРЫВА")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(1.5)
                            
                            // Relapse duration selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Насколько долго вы сорвались?")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Picker("Длительность", selection: $relapseDuration) {
                                    ForEach(durations, id: \.self) { dur in
                                        Text(dur).tag(dur)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .colorScheme(.dark)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            // Relapse time selection
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("Указать точное время срыва", isOn: $specifyRelapseTime)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .tint(.green)
                                
                                if specifyRelapseTime {
                                    DatePicker(
                                        "Время срыва",
                                        selection: $relapseTime,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .colorScheme(.dark)
                                    .datePickerStyle(.compact)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            // Relapse Reason
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Что послужило триггером?")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(reasons, id: \.self) { reason in
                                            Button(action: {
                                                withAnimation {
                                                    failReason = reason
                                                }
                                            }) {
                                                Text(reason)
                                                    .font(.subheadline)
                                                    .foregroundColor(failReason == reason ? .black : .white)
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 14)
                                                    .background(failReason == reason ? Color.white : Color.white.opacity(0.08))
                                                    .cornerRadius(18)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            
                            if failReason == "Другое" {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Свой триггер")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    TextField("Укажите свою причину...", text: $customFailReason)
                                        .padding()
                                        .background(Color.white.opacity(0.06))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            }
                            
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                        .transition(.slide.combined(with: .opacity))
                    }
                    
                    // 5. Notes Card (Always visible)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("РЕФЛЕКСИЯ / ЗАМЕТКИ")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.5)
                        
                        Text("Запишите ваши мысли, наблюдения или уроки за день.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        TextField("Напишите заметку...", text: $failNotes)
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    
                    if hasExistingLog {
                        Button(action: {
                            resetCheckIn()
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                Text("Обнулить сегодняшний день")
                            }
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 10)
                    }
                }
                .padding()
                .padding(.bottom, 40)
            }
            .withAmbientGlow()
            .navigationTitle("Отчет за день")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        saveCheckIn()
                    }
                    .foregroundColor(.green)
                    .font(.headline)
                }
            }
            .onAppear {
                let calendar = Calendar.current
                if calendar.component(.hour, from: targetDate) == 0 &&
                   calendar.component(.minute, from: targetDate) == 0 &&
                   calendar.component(.second, from: targetDate) == 0 {
                    if let adjusted = calendar.date(byAdding: .hour, value: detoxDayBoundaryHour + 12, to: targetDate) {
                        currentTargetDate = adjusted
                    } else {
                        currentTargetDate = targetDate
                    }
                } else {
                    currentTargetDate = targetDate
                }
                relapseTime = currentTargetDate
                loadExistingCheckIn()
            }
        }
    }
    
    private func formatTargetDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func loadExistingCheckIn() {
        if forceNewLog { return }
        let logToEdit: DetoxLog?
        if let id = targetLogId {
            logToEdit = activeLogs.first { $0.id == id }
        } else {
            logToEdit = activeLogs.last { DetoxDateHelper.isDateSameDetoxDay($0.date, currentTargetDate, boundaryHour: detoxDayBoundaryHour) }
        }
        
        if let log = logToEdit {
            hasExistingLog = true
            silenceTolerance = log.silenceTolerance ?? 3
            didRelapse = !log.isClean
            relapseDuration = log.relapseDuration ?? "пару минут"
            failNotes = log.failNotes ?? ""
            
            let loadedReason = log.failReason ?? "Скука"
            if reasons.contains(loadedReason) {
                failReason = loadedReason
            } else {
                failReason = "Другое"
                customFailReason = loadedReason
            }
            
            if !log.isClean {
                let logTime = log.date
                let endOfDay = DetoxDateHelper.endOfDetoxDay(for: logTime, boundaryHour: detoxDayBoundaryHour)
                let diff = endOfDay.timeIntervalSince(logTime)
                if abs(diff - 1.0) < 5.0 {
                    specifyRelapseTime = false
                } else {
                    specifyRelapseTime = true
                    relapseTime = logTime
                }
            }
        }
    }
    
    private func getFinalLogDate() -> Date {
        let calendar = Calendar.current
        if didRelapse {
            if specifyRelapseTime {
                let dateComponents = calendar.dateComponents([.year, .month, .day], from: currentTargetDate)
                let timeComponents = calendar.dateComponents([.hour, .minute], from: relapseTime)
                
                var mergedComponents = DateComponents()
                mergedComponents.year = dateComponents.year
                mergedComponents.month = dateComponents.month
                mergedComponents.day = dateComponents.day
                mergedComponents.hour = timeComponents.hour
                mergedComponents.minute = timeComponents.minute
                mergedComponents.second = 0
                
                return calendar.date(from: mergedComponents) ?? currentTargetDate
            } else {
                let endOfDay = DetoxDateHelper.endOfDetoxDay(for: currentTargetDate, boundaryHour: detoxDayBoundaryHour)
                return calendar.date(byAdding: .second, value: -1, to: endOfDay) ?? currentTargetDate
            }
        } else {
            return currentTargetDate
        }
    }
    
    private func saveCheckIn() {
        let finalReason = didRelapse ? (failReason == "Другое" ? customFailReason : failReason) : nil
        let finalDuration = didRelapse ? relapseDuration : nil
        
        let logToEdit: DetoxLog?
        if forceNewLog {
            logToEdit = nil
        } else if let id = targetLogId {
            logToEdit = activeLogs.first { $0.id == id }
        } else {
            logToEdit = activeLogs.last { DetoxDateHelper.isDateSameDetoxDay($0.date, currentTargetDate, boundaryHour: detoxDayBoundaryHour) }
        }
        
        let log: DetoxLog
        let finalDate = getFinalLogDate()
        
        if let existing = logToEdit {
            log = existing
            log.isClean = !didRelapse
            log.date = finalDate
            log.silenceTolerance = silenceTolerance
            log.relapseDuration = finalDuration
            log.failReason = finalReason
            log.failNotes = failNotes
            log.isRescued = false
        } else {
            log = DetoxLog(
                date: finalDate,
                isClean: !didRelapse,
                failReason: finalReason,
                failNotes: failNotes,
                isRescued: false,
                silenceTolerance: silenceTolerance,
                relapseDuration: finalDuration,
                profileId: profile?.id
            )
            modelContext.insert(log)
        }
        
        // Update user progress lastCheckInDate if targetDate is today or newer
        let todayDetoxDay = DetoxDateHelper.detoxDay(for: Date(), boundaryHour: detoxDayBoundaryHour)
        let targetDetoxDay = DetoxDateHelper.detoxDay(for: finalDate, boundaryHour: detoxDayBoundaryHour)
        if targetDetoxDay >= todayDetoxDay {
            profile?.lastCheckInDate = finalDate
            progress.lastActiveDate = finalDate
            profile?.streakSavedToday = false
        }
        
        var allLogs = activeLogs
        if !allLogs.contains(where: { $0.id == log.id }) {
            allLogs.append(log)
        }
        DetoxDateHelper.recalculateStreak(logs: allLogs, boundaryHour: detoxDayBoundaryHour, profile: profile)
        PastStreak.rebuildPastStreaks(logs: allLogs, context: modelContext, profileId: profile?.id)
        
        // Unlock palettes based on new streak
        unlockThemesForCurrentStreak()
        
        // Reschedule notifications
        NotificationManager.shared.scheduleReminders(lastCheckInDate: profile?.lastCheckInDate ?? Date())
        
        try? modelContext.save()
        dismiss()
    }
    
    private func unlockThemesForCurrentStreak() {
        let streak = profile?.currentStreakDays ?? 0
        
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
    
    private func resetCheckIn() {
        let logToEdit: DetoxLog?
        if forceNewLog {
            logToEdit = nil
        } else if let id = targetLogId {
            logToEdit = activeLogs.first { $0.id == id }
        } else {
            logToEdit = activeLogs.last { DetoxDateHelper.isDateSameDetoxDay($0.date, currentTargetDate, boundaryHour: detoxDayBoundaryHour) }
        }
        
        if let log = logToEdit {
            modelContext.delete(log)
            try? modelContext.save()
            
            // Recalculate streak
            var remainingLogs = activeLogs
            remainingLogs.removeAll { $0.id == log.id }
            DetoxDateHelper.recalculateStreak(logs: remainingLogs, boundaryHour: detoxDayBoundaryHour, profile: profile)
            
            // Unset check-in dates for today if applicable
            let todayDetoxDay = DetoxDateHelper.detoxDay(for: Date(), boundaryHour: detoxDayBoundaryHour)
            let targetDetoxDay = DetoxDateHelper.detoxDay(for: currentTargetDate, boundaryHour: detoxDayBoundaryHour)
            if targetDetoxDay >= todayDetoxDay {
                if let lastLog = remainingLogs.filter({ $0.isClean }).last {
                    profile?.lastCheckInDate = lastLog.date
                } else {
                    profile?.lastCheckInDate = nil
                }
            }
        }
        
        dismiss()
    }
}
