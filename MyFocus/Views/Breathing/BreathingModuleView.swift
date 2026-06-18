import SwiftUI
import AVFoundation

struct BreathingModuleView: View {
    @State private var selectedDuration: Int = 60
    @State private var isBreathing: Bool = false
    @State private var timeRemaining: Int = 0
    @State private var timer: Timer?
    @State private var breathTimer: Timer?
    @State private var isInhaling: Bool = false
    
    @AppStorage("activePalette", store: .shared) private var activePalette: String = "default"
    
    var body: some View {
        VStack {
                if !isBreathing {
                    Text("Дыхание")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 40)
                    
                    Spacer()
                    
                    Text("Выберите длительность")
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 10)
                    
                    let durationsInSeconds = [5, 30, 60, 120, 180, 240, 300, 600, 900]
                    
                    Picker("Длительность", selection: $selectedDuration) {
                        ForEach(durationsInSeconds, id: \.self) { duration in
                            Text(formatDuration(duration))
                                .foregroundColor(.white)
                                .tag(duration)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                    .clipped()
                    
                    Spacer()
                    
                    Button(action: startSession) {
                        Text("Начать")
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
                    
                    Text("\(timeRemaining / 60):\(String(format: "%02d", timeRemaining % 60))")
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Button(action: stopSession) {
                        Text("Завершить")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 40)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .withAmbientGlow(isBreathing: isBreathing, isInhaling: isInhaling)
        .onDisappear {
            stopSession()
        }
    }
    
    private func startSession() {
        withAnimation {
            isBreathing = true
            timeRemaining = selectedDuration
        }
        
        startBreathingCycle()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                playCompletionSound()
                stopSession()
            }
        }
    }
    
    private func startBreathingCycle() {
        guard isBreathing else { return }
        
        isInhaling = false
        withAnimation(.easeInOut(duration: 4.75).repeatForever(autoreverses: true)) {
            isInhaling = true
        }
    }
    
    private func stopSession() {
        timer?.invalidate()
        timer = nil
        breathTimer?.invalidate()
        breathTimer = nil
        withAnimation {
            isBreathing = false
            isInhaling = false
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) сек"
        } else {
            return "\(seconds / 60) мин"
        }
    }
    
    private func playCompletionSound() {
        #if targetEnvironment(macCatalyst)
        if let url = URL(string: "file:///System/Library/Sounds/Blow.aiff") {
            var soundId: SystemSoundID = 0
            AudioServicesCreateSystemSoundID(url as CFURL, &soundId)
            AudioServicesPlaySystemSound(soundId)
        }
        #else
        AudioServicesPlaySystemSound(1110)
        #endif
    }
}
