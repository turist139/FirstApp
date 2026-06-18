import SwiftUI
import SwiftData

struct CheckInView: View {
    var targetDate: Date = Date()
    var targetLogId: UUID? = nil
    var forceNewLog: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var progressQuery: [UserProgress]
    @Query(sort: \DetoxLog.date, order: .forward) private var logs: [DetoxLog]
    
    @AppStorage("detoxDayBoundaryHour", store: .shared) private var detoxDayBoundaryHour: Int = 0
    
    // Core check-in state
    @State private var silenceTolerance: Int = 3
    @State private var didRelapse: Bool = false
    @State private var relapseDuration: String = "пару минут"
    @State private var failReason: String = "Скука"
    @State private var customFailReason: String = ""
    @State private var failNotes: String = ""
    @State private var hasExistingLog: Bool = false
    
    var progress: UserProgress {
        progressQuery.first ?? UserProgress()
    }
    
    let durations = ["пару минут", "до двух часов", "день"]
    let reasons = ["\"один раз\"", "Усталость", "Тревога", "Автопилот", "Скука", "Голод", "Другое"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    // 1. Header description
                    VStack(spacing: 6) {
                        Text(formatTargetDate(targetDate))
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
            logToEdit = logs.first { $0.id == id }
        } else {
            logToEdit = logs.last { DetoxDateHelper.isDateSameDetoxDay($0.date, targetDate, boundaryHour: detoxDayBoundaryHour) }
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
        }
    }
    
    private func saveCheckIn() {
        let finalReason = didRelapse ? (failReason == "Другое" ? customFailReason : failReason) : nil
        let finalDuration = didRelapse ? relapseDuration : nil
        
        let logToEdit: DetoxLog?
        if forceNewLog {
            logToEdit = nil
        } else if let id = targetLogId {
            logToEdit = logs.first { $0.id == id }
        } else {
            logToEdit = logs.last { DetoxDateHelper.isDateSameDetoxDay($0.date, targetDate, boundaryHour: detoxDayBoundaryHour) }
        }
        
        let log: DetoxLog
        if let existing = logToEdit {
            log = existing
            log.isClean = !didRelapse
            log.silenceTolerance = silenceTolerance
            log.relapseDuration = finalDuration
            log.failReason = finalReason
            log.failNotes = failNotes
            log.isRescued = false
        } else {
            log = DetoxLog(
                date: targetDate,
                isClean: !didRelapse,
                failReason: finalReason,
                failNotes: failNotes,
                isRescued: false,
                silenceTolerance: silenceTolerance,
                relapseDuration: finalDuration
            )
            modelContext.insert(log)
        }
        
        // Update user progress lastCheckInDate if targetDate is today or newer
        let todayDetoxDay = DetoxDateHelper.detoxDay(for: Date(), boundaryHour: detoxDayBoundaryHour)
        let targetDetoxDay = DetoxDateHelper.detoxDay(for: targetDate, boundaryHour: detoxDayBoundaryHour)
        if targetDetoxDay >= todayDetoxDay {
            progress.lastCheckInDate = targetDate
            progress.lastActiveDate = targetDate
            progress.streakSavedToday = false
        }
        
        var allLogs = logs
        if !allLogs.contains(where: { $0.id == log.id }) {
            allLogs.append(log)
        }
        DetoxDateHelper.recalculateStreak(logs: allLogs, boundaryHour: detoxDayBoundaryHour, progress: progress)
        PastStreak.rebuildPastStreaks(logs: allLogs, context: modelContext)
        
        // Unlock palettes based on new streak
        unlockThemesForCurrentStreak()
        
        // Reschedule notifications
        NotificationManager.shared.scheduleReminders(lastCheckInDate: progress.lastCheckInDate ?? Date())
        
        try? modelContext.save()
        dismiss()
    }
    
    private func unlockThemesForCurrentStreak() {
        let streak = progress.currentStreakDays
        
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
            logToEdit = logs.first { $0.id == id }
        } else {
            logToEdit = logs.last { DetoxDateHelper.isDateSameDetoxDay($0.date, targetDate, boundaryHour: detoxDayBoundaryHour) }
        }
        
        if let log = logToEdit {
            modelContext.delete(log)
            try? modelContext.save()
            
            // Recalculate streak
            var remainingLogs = logs
            remainingLogs.removeAll { $0.id == log.id }
            DetoxDateHelper.recalculateStreak(logs: remainingLogs, boundaryHour: detoxDayBoundaryHour, progress: progress)
            
            // Unset check-in dates for today if applicable
            let todayDetoxDay = DetoxDateHelper.detoxDay(for: Date(), boundaryHour: detoxDayBoundaryHour)
            let targetDetoxDay = DetoxDateHelper.detoxDay(for: targetDate, boundaryHour: detoxDayBoundaryHour)
            if targetDetoxDay >= todayDetoxDay {
                if let lastLog = remainingLogs.filter({ $0.isClean }).last {
                    progress.lastCheckInDate = lastLog.date
                } else {
                    progress.lastCheckInDate = nil
                }
            }
        }
        
        dismiss()
    }
}
