import SwiftUI
import AVFoundation

struct OnboardingBreathingView: View {
    var onComplete: () -> Void
    
    @State private var isInhaling: Bool = false
    @State private var textOpacity: Double = 0.0
    @State private var phaseText: String = "Вдох..."
    
    @AppStorage("activePalette", store: .shared) private var activePalette: String = "default"
    
    var body: some View {
        VStack(spacing: 30) {
                Text("Время для глубокого вдоха")
                    .font(.system(size: 24, weight: .light, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding()
            }
        .opacity(textOpacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .withAmbientGlow(isBreathing: true, isInhaling: isInhaling)
        .onAppear {
            startBreathingCycle()
        }
    }
    
    private func startBreathingCycle() {
        // Fade in text
        withAnimation(.easeIn(duration: 1.0)) {
            textOpacity = 1.0
        }
        
        // Inhale (4.0 seconds)
        withAnimation(.easeInOut(duration: 4.0)) {
            isInhaling = true // Rises
        }
        
        // Exhale (4.0 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeInOut(duration: 4.0)) {
                isInhaling = false // Falls
            }
            
            // Finish
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                #if targetEnvironment(macCatalyst)
                if let url = URL(string: "file:///System/Library/Sounds/Blow.aiff") {
                    var soundId: SystemSoundID = 0
                    AudioServicesCreateSystemSoundID(url as CFURL, &soundId)
                    AudioServicesPlaySystemSound(soundId)
                }
                #else
                AudioServicesPlaySystemSound(1110)
                #endif
                
                withAnimation(.easeOut(duration: 0.5)) {
                    textOpacity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
            }
        }
    }
}

#Preview {
    OnboardingBreathingView(onComplete: {})
}
