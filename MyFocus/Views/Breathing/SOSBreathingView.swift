import SwiftUI
import AVFoundation
import SwiftData

struct SOSBreathingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var timeRemaining: Int = 90
    @State private var timer: Timer?
    @State private var isInhaling: Bool = false
    @State private var showFeedback: Bool = false
    @State private var currentAffirmation: String = "Тяга длится всего 90 секунд. Дышите вместе со мной."
    
    let affirmations = [
        "Тяга длится всего 90 секунд. Дышите вместе со мной.",
        "Импульс — это просто волна. Оседлайте её, не сопротивляясь.",
        "Почувствуйте свои стопы на полу. Вы здесь и сейчас.",
        "Каждый вдох приносит ясность, каждый выдох уносит тягу.",
        "Вы сильнее, чем автоматическая привычка вашего мозга.",
        "С каждым циклом дыхания дофаминовая буря утихает.",
        "Вы управляете своим вниманием. Вы свободны.",
        "Почти готово. Спокойствие возвращается к вам."
    ]
    
    var body: some View {
        VStack {
            if showFeedback {
                feedbackView
            } else {
                breathingView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .withAmbientGlow(isBreathing: !showFeedback, isInhaling: isInhaling)
        .onAppear {
            startSession()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Subviews
    
    private var breathingView: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    timer?.invalidate()
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white.opacity(0.4))
                        .padding()
                }
                .buttonStyle(.plain)
            }
            
            Text("SOS: Дыхание Спасения")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(currentAffirmation)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.top, 10)
                .frame(height: 60)
            
            Spacer()
            
            // Pulsing circle
            ZStack {
                Circle()
                    .stroke(Color.red.opacity(0.1), lineWidth: 4)
                    .frame(width: 230, height: 230)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.red.opacity(0.4), Color.purple.opacity(0.1)],
                            center: .center,
                            startRadius: 5,
                            endRadius: 100
                        )
                    )
                    .frame(width: isInhaling ? 210 : 110, height: isInhaling ? 210 : 110)
                    .blur(radius: 5)
                    .animation(.easeInOut(duration: 4.75).repeatForever(autoreverses: true), value: isInhaling)
                
                VStack(spacing: 5) {
                    Text("\(timeRemaining)")
                        .font(.system(size: 64, weight: .light, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(isInhaling ? "Вдох..." : "Выдох...")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .animation(.easeInOut(duration: 0.5), value: isInhaling)
                }
            }
            
            Spacer()
            
            Text("Сфокусируйтесь на физических ощущениях воздуха")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 20)
            
            Button(action: {
                timer?.invalidate()
                dismiss()
            }) {
                Text("Отменить")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.vertical, 14)
                    .padding(.horizontal, 40)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
        }
    }
    
    private var feedbackView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .shadow(color: .green.opacity(0.3), radius: 10)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 12) {
                Text("Отличная работа!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Вы дышали в течение 90 секунд.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal)
            
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, 40)
                .padding(.vertical, 10)
            
            VStack(spacing: 20) {
                Text("Помогло справиться с тягой?")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 20) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Нет")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        incrementSOSCount()
                        dismiss()
                    }) {
                        Text("Да")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(16)
                            .shadow(color: .green.opacity(0.3), radius: 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 30)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Logic
    
    private func startSession() {
        timeRemaining = 90
        withAnimation(.easeInOut(duration: 4.75).repeatForever(autoreverses: true)) {
            isInhaling = true
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
                
                // Change affirmation text every 12 seconds
                if timeRemaining % 12 == 0 {
                    withAnimation {
                        currentAffirmation = affirmations[Int.random(in: 0..<affirmations.count)]
                    }
                }
            } else {
                timer?.invalidate()
                timer = nil
                playCompletionSound()
                withAnimation {
                    showFeedback = true
                }
            }
        }
    }
    
    private func playCompletionSound() {
        #if targetEnvironment(macCatalyst)
        if let url = URL(string: "file:///System/Library/Sounds/Hero.aiff") {
            var soundId: SystemSoundID = 0
            AudioServicesCreateSystemSoundID(url as CFURL, &soundId)
            AudioServicesPlaySystemSound(soundId)
        }
        #else
        AudioServicesPlaySystemSound(1021) // success sound (gentle Bloom chime)
        #endif
    }
    
    private func incrementSOSCount() {
        let today = Date()
        let calendar = Calendar.current
        let fetchDescriptor = FetchDescriptor<DetoxLog>()
        if let logs = try? modelContext.fetch(fetchDescriptor) {
            if let todayLog = logs.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
                todayLog.sosCount += 1
                if todayLog.sosTimes == nil {
                    todayLog.sosTimes = []
                }
                todayLog.sosTimes?.append(today)
            } else {
                let newLog = DetoxLog(date: today, isClean: true, sosCount: 1, sosTimes: [today])
                modelContext.insert(newLog)
            }
            try? modelContext.save()
        }
    }
}
