import SwiftUI

struct SessionEvaluationView: View {
    let duration: Int
    let onSubmit: (Int) -> Void
    
    @State private var selectedScore: Int = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Text("Отличная работа!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Вы были сфокусированы \(duration) минут.")
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Оцените свою продуктивность:")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                HStack(spacing: 15) {
                    ForEach(1...5, id: \.self) { score in
                        Button(action: {
                            selectedScore = score
                        }) {
                            Image(systemName: score <= selectedScore ? "star.fill" : "star")
                                .font(.system(size: 40))
                                .foregroundColor(score <= selectedScore ? .yellow : .white.opacity(0.3))
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    onSubmit(selectedScore)
                }) {
                    Text("Продолжить")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedScore > 0 ? Color.white : Color.white.opacity(0.3))
                        .cornerRadius(16)
                }
                .disabled(selectedScore == 0)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .padding(.top, 60)
        }
    }
}
