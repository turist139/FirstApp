import SwiftUI
import SwiftData

struct MindfulnessView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep: Int = 0
    
    // State to hold inputs
    @State private var sees: [String] = ["", "", ""]
    @State private var hears: [String] = ["", "", ""]
    @State private var feels: [String] = ["", "", ""]
    
    @State private var showHistory: Bool = false
    
    var body: some View {
        VStack {
            Spacer()
            
            if currentStep == 0 {
                introView
            } else if currentStep == 1 {
                stepView(title: "Что вы сейчас видите?", subtitle: "Оглянитесь вокруг и назовите 3 вещи.", items: $sees, nextStep: 2)
            } else if currentStep == 2 {
                stepView(title: "Что вы сейчас слышите?", subtitle: "Прислушайтесь и назовите 3 звука.", items: $hears, nextStep: 3)
            } else if currentStep == 3 {
                stepView(title: "Что вы сейчас чувствуете?", subtitle: "Обратите внимание на 3 физических ощущения.", items: $feels, nextStep: 4)
            } else if currentStep == 4 {
                summaryView
            }
            
            Spacer()
        }
        .padding()
        .withAmbientGlow()
        .navigationTitle("Осознанность")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { showHistory = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.white)
                }
            }
        }
        .navigationDestination(isPresented: $showHistory) {
            MindfulnessHistoryView()
        }
    }
    
    private var introView: some View {
        VStack(spacing: 30) {
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.4))
            
            Text("Правило 3-3-3")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Это упражнение поможет вам заземлиться и вернуться в настоящий момент. Оглянитесь, прислушайтесь и почувствуйте.")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal)
            
            Button(action: {
                withAnimation { currentStep = 1 }
            }) {
                Text("Начать")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
        }
        .transition(.opacity)
    }
    
    private func stepView(title: String, subtitle: String, items: Binding<[String]>, nextStep: Int) -> some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.title2.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text(subtitle)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)
            
            ForEach(0..<3, id: \.self) { index in
                TextField("...", text: items[index])
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .foregroundColor(.white)
            }
            
            Button(action: {
                withAnimation {
                    currentStep = nextStep
                    if nextStep == 4 {
                        saveSession()
                    }
                }
            }) {
                Text(nextStep == 4 ? "Завершить" : "Далее")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isStepComplete(items.wrappedValue) ? Color.white : Color.white.opacity(0.3))
                    .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .disabled(!isStepComplete(items.wrappedValue))
            .padding(.top, 20)
        }
        .transition(.slide)
    }
    
    private func isStepComplete(_ items: [String]) -> Bool {
        return items.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    private var summaryView: some View {
        VStack(spacing: 25) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.4))
            
            Text("Вы здесь и сейчас")
                .font(.title.bold())
                .foregroundColor(.white)
            
            ScrollView {
                VStack(spacing: 20) {
                    summarySection(icon: "eye.fill", title: "Я вижу", items: sees)
                    summarySection(icon: "ear", title: "Я слышу", items: hears)
                    summarySection(icon: "hand.raised.fill", title: "Я чувствую", items: feels)
                }
                .padding(.vertical)
            }
            
            Button(action: {
                withAnimation {
                    // Reset state
                    sees = ["", "", ""]
                    hears = ["", "", ""]
                    feels = ["", "", ""]
                    currentStep = 0
                }
            }) {
                Text("Готово")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
            }
            .buttonStyle(.plain)
        }
        .transition(.opacity)
    }
    
    private func summarySection(icon: String, title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.4))
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text("• \(item)")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private func saveSession() {
        let session = MindfulnessSession(
            thingsSeen: sees.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            thingsHeard: hears.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            thingsFelt: feels.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        )
        modelContext.insert(session)
        
        // Add 50 XP
        let fetchDescriptor = FetchDescriptor<UserProgress>()
        if let progress = try? modelContext.fetch(fetchDescriptor).first {
            progress.totalXP += 50
        }
    }
}
