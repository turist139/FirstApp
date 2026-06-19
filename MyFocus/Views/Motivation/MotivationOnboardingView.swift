import SwiftUI

struct MotivationOnboardingView: View {
    @ObservedObject var settings = MotivationSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep = 0
    @State private var answers: [String] = Array(repeating: "", count: 7)
    @State private var slideDirection: Edge = .trailing
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Header
                HStack {
                    Spacer()
                    
                    Text("\(currentStep + 1)/\(settings.categories.count)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                }
                .padding()
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(Color.cyan)
                            .frame(width: geo.size.width * CGFloat(currentStep + 1) / CGFloat(settings.categories.count), height: 4)
                            .animation(.spring(), value: currentStep)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal)
                
                // Content Switcher
                ZStack {
                    ForEach(0..<settings.categories.count, id: \.self) { index in
                        if currentStep == index {
                            onboardingStepView(index: index)
                                .transition(.asymmetric(
                                    insertion: .move(edge: slideDirection == .trailing ? .trailing : .leading),
                                    removal: .move(edge: slideDirection == .trailing ? .leading : .trailing)
                                ))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom Buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button(action: {
                            slideDirection = .leading
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(16)
                        }
                    }
                    
                    Button(action: {
                        if currentStep < settings.categories.count - 1 {
                            slideDirection = .trailing
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep += 1
                            }
                        } else {
                            saveAndFinish()
                        }
                    }) {
                        Text(currentStep < settings.categories.count - 1 ? "Далее" : "Готово, погнали!")
                            .font(.headline.bold())
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.cyan)
                            .cornerRadius(16)
                    }
                }
                .padding()
            }
        }
    }
    
    private func onboardingStepView(index: Int) -> some View {
        let category = settings.categories[index]
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Spacer().frame(height: 20)
                
                ZStack {
                    Circle()
                        .fill(Color(hex: category.colorHex).opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(hex: category.colorHex))
                }
                .padding(.bottom, 10)
                
                Text(category.title)
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                
                Text(category.subtitle)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Каждая новая строка будет сохранена как отдельный пункт.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 10)
                
                TextEditor(text: $answers[index])
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(12)
                    .frame(minHeight: 150)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func saveAndFinish() {
        for (index, answer) in answers.enumerated() {
            let lines = answer.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            let items = lines.map { MotivationItem(text: $0) }
            settings.categories[index].items = items
        }
        settings.hasCompletedOnboarding = true
        dismiss()
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
