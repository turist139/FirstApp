import SwiftUI
import SwiftData

struct StreakRecoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var progressQuery: [UserProgress]
    @Query(sort: \DetoxLog.date, order: .forward) private var logs: [DetoxLog]
    @Query private var profilesQuery: [DetoxProfile]
    
    @AppStorage("detoxDayBoundaryHour", store: .shared) private var detoxDayBoundaryHour: Int = 0
    
    var progress: UserProgress {
        progressQuery.first ?? UserProgress()
    }
    
    var activeProfile: DetoxProfile? {
        let activeId = progress.activeProfileId
        return profilesQuery.first(where: { $0.id == activeId }) ?? profilesQuery.first
    }
    
    var activeLogs: [DetoxLog] {
        guard let profileId = activeProfile?.id else { return [] }
        return logs.filter { $0.profileId == profileId }
    }
    
    @State private var selectedReason: String = ""
    @State private var customFailReason: String = ""
    @State private var customReflection: String = ""
    
    let reasons = ["\"Один раз\"", "Усталость", "Тревога", "Автопилот", "Скука", "Голод", "Другое"]
    
    var body: some View {
        VStack(spacing: 25) {
            Text("Сброс стрика")
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.top, 40)
            
            Text("Что послужило триггером в этот раз?")
                .foregroundColor(.white.opacity(0.8))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
            
            // Flow list of reasons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(reasons, id: \.self) { reason in
                        Button(action: {
                            withAnimation {
                                selectedReason = reason
                            }
                        }) {
                            Text(reason)
                                .font(.subheadline)
                                .foregroundColor(selectedReason == reason ? .black : .white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 18)
                                .background(selectedReason == reason ? Color.white : Color.white.opacity(0.1))
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.2), lineWidth: selectedReason == reason ? 0 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 30)
            }
            .frame(height: 50)
            
            if selectedReason == "Другое" {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Свой триггер")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.headline)
                    
                    TextField("Укажите свою причину...", text: $customFailReason)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 30)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Что вы можете сделать по-другому?")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.headline)
                
                TextField("Например: уберу телефон в другую комнату...", text: $customReflection)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 30)
            
            Spacer()
            
            let isSaveDisabled = selectedReason.isEmpty || (selectedReason == "Другое" && customFailReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            Button(action: {
                saveRelapseAndReset()
            }) {
                Text("Начать заново")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isSaveDisabled ? Color.gray : Color.red)
                    .cornerRadius(16)
                    .shadow(color: isSaveDisabled ? .clear : .red.opacity(0.4), radius: 8)
            }
            .buttonStyle(.plain)
            .disabled(isSaveDisabled)
            .padding(.horizontal, 30)
            
            Button(action: {
                dismiss()
            }) {
                Text("Отмена")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
                    .padding()
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .withAmbientGlow()
    }
    
    private func saveRelapseAndReset() {
        withAnimation {
            let finalReason = selectedReason == "Другое" ? customFailReason : selectedReason
            let now = Date()
            
            let profileId = activeProfile?.id
            
            // Create a PastStreak if duration was non-zero
            let startDate = activeProfile?.streakStartDate ?? activeProfile?.creationDate ?? now
            let hours = Calendar.current.dateComponents([.hour], from: startDate, to: now).hour ?? 0
            if hours > 0 || (activeProfile?.currentStreakDays ?? 0) > 0 {
                let pastStreak = PastStreak(
                    startDate: startDate,
                    endDate: now,
                    failReason: finalReason,
                    failNotes: customReflection,
                    profileId: profileId
                )
                modelContext.insert(pastStreak)
            }
            
            // Log the relapse for today (as partial)
            let log = DetoxLog(
                date: now,
                isClean: false,
                isPartial: true,
                failReason: finalReason,
                failNotes: customReflection,
                isRescued: false,
                profileId: profileId
            )
            modelContext.insert(log)
            
            // Reset streak
            activeProfile?.currentStreakDays = 0
            activeProfile?.streakStartDate = now
            activeProfile?.lastCheckInDate = now
            progress.lastActiveDate = now
            activeProfile?.streakSavedToday = false
            
            // Recalculate streak & rebuild past streaks
            var updatedLogs = activeLogs
            if !updatedLogs.contains(where: { $0.id == log.id }) {
                updatedLogs.append(log)
            }
            DetoxDateHelper.recalculateStreak(logs: updatedLogs, boundaryHour: detoxDayBoundaryHour, profile: activeProfile)
            PastStreak.rebuildPastStreaks(logs: updatedLogs, context: modelContext, profileId: profileId)
            
            // Re-schedule notifications
            NotificationManager.shared.scheduleReminders(lastCheckInDate: now)
            
            try? modelContext.save()
            dismiss()
        }
    }
}
