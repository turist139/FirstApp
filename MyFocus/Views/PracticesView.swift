import SwiftUI

struct PracticesView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Выберите активность")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(1.5)
                        .padding(.top, 10)
                    
                    // 1. Breathing Tile
                    NavigationLink(destination: BreathingModuleView()) {
                        practiceTile(
                            title: "Дыхание",
                            subtitle: "Снятие стресса и балансировка ума",
                            icon: "wind",
                            description: "Упражнения для управления вниманием, снижения тревожности и быстрой перезагрузки нервной системы.",
                            color: .green
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // 2. Focus Tile
                    NavigationLink(destination: FocusTimerView()) {
                        practiceTile(
                            title: "Фокус",
                            subtitle: "Глубокая работа и концентрация",
                            icon: "timer",
                            description: "Таймер продуктивности с аудиосопровождением для защиты от отвлечений и отслеживания сессий.",
                            color: .blue
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // 3. Mindfulness Tile
                    NavigationLink(destination: MindfulnessView()) {
                        practiceTile(
                            title: "Осознанность",
                            subtitle: "Заземление в моменте (3-3-3)",
                            icon: "eye.fill",
                            description: "Быстрое ментальное возвращение в настоящее через наблюдение за тем, что вы видите, слышите и чувствуете.",
                            color: .purple
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .withAmbientGlow()
            .navigationTitle("Практики")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
        }
        .withSOSToolbar()
    }
    
    // MARK: - Helper Views
    
    private func practiceTile(title: String, subtitle: String, icon: String, description: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 15) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.3), lineWidth: 1)
                        )
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(color.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.3))
            }
            
            Text(description)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    PracticesView()
}
