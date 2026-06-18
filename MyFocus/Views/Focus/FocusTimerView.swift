import SwiftUI
import SwiftData
import AVFoundation

struct FocusTimerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var timerManager: TimerManager
    
    @State private var showBreak: Bool = false
    
    var body: some View {
        VStack {
            if !timerManager.isFocusing {
                Text("Фокус")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 40)
                
                Spacer()
                
                Text("Выберите длительность")
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 10)
                
                Picker("Длительность", selection: $timerManager.selectedMinutes) {
                    ForEach(Array(stride(from: 5, through: 120, by: 5)), id: \.self) { min in
                        Text("\(min) мин")
                            .foregroundColor(.white)
                            .tag(min)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)
                .clipped()
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        timerManager.startFocus()
                    }
                }) {
                    Text("Начать сессию")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            } else {
                Spacer()
                
                // Simple minimal progress
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 10)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(timerManager.timeRemaining) / CGFloat(timerManager.selectedMinutes * 60))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: timerManager.timeRemaining)
                    
                    Text("\(timerManager.timeRemaining / 60):\(String(format: "%02d", timerManager.timeRemaining % 60))")
                        .font(.system(size: 64, weight: .thin, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(40)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        timerManager.cancelFocus()
                    }
                }) {
                    Text("Прервать")
                        .foregroundColor(.white.opacity(0.7))
                        .padding()
                }
                .padding(.bottom, 40)
            }
        }
        .withAmbientGlow()
        .fullScreenCover(isPresented: $timerManager.showEvaluation) {
            SessionEvaluationView(duration: timerManager.selectedMinutes) { score in
                saveSession(duration: timerManager.selectedMinutes, score: score)
                timerManager.showEvaluation = false
                showBreak = true
            }
        }
        .fullScreenCover(isPresented: $showBreak) {
            ActiveBreakView(onComplete: {
                showBreak = false
            })
        }
    }
    
    private func saveSession(duration: Int, score: Int) {
        let session = FocusSession(durationMinutes: duration, productivityScore: score)
        modelContext.insert(session)
        
        // Update user progress
        let fetchDescriptor = FetchDescriptor<UserProgress>()
        if let progress = try? modelContext.fetch(fetchDescriptor).first {
            progress.totalXP += (duration * score) // Example XP formula
            progress.lastActiveDate = Date()
            // Streak logic here (simplified for now)
            progress.currentStreakDays += 1
            
            // Level up logic (every 100 XP)
            if progress.totalXP >= progress.currentLevel * 100 {
                progress.currentLevel += 1
                progress.unlockedPaletteIDs.append("palette_\(progress.currentLevel)")
            }
        } else {
            let progress = UserProgress(totalXP: duration * score)
            modelContext.insert(progress)
        }
    }
}
