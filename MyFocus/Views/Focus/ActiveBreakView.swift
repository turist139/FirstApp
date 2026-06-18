import SwiftUI
import SwiftData

struct ActiveBreakView: View {
    let onComplete: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Query private var activities: [BreakActivity]
    
    @State private var timeRemaining: Int = 5 * 60
    @State private var timer: Timer?
    @State private var selectedActivity: BreakActivity?
    
    @State private var showAddCustom: Bool = false
    @State private var newActivityName: String = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Активный перерыв")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 40)
                
                if let activity = selectedActivity {
                    Text(activity.name)
                        .font(.title2)
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    
                    Text("\(timeRemaining / 60):\(String(format: "%02d", timeRemaining % 60))")
                        .font(.system(size: 64, weight: .thin, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.vertical, 40)
                    
                    Button(action: finishBreak) {
                        Text("Завершить перерыв")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(12)
                    }
                } else {
                    Text("Выберите активность:")
                        .foregroundColor(.white.opacity(0.8))
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(activities) { activity in
                                Button(action: {
                                    startBreak(with: activity)
                                }) {
                                    Text(activity.name)
                                        .font(.body)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(12)
                                }
                            }
                            
                            Button(action: {
                                showAddCustom = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Своя активность")
                                }
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Button(action: onComplete) {
                        Text("Пропустить перерыв")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showAddCustom) {
            AddCustomActivityView(name: $newActivityName) {
                let activity = BreakActivity(name: newActivityName, isCustom: true)
                modelContext.insert(activity)
                showAddCustom = false
                newActivityName = ""
            }
            .presentationDetents([.fraction(0.3)])
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startBreak(with activity: BreakActivity) {
        selectedActivity = activity
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                finishBreak()
            }
        }
    }
    
    private func finishBreak() {
        timer?.invalidate()
        timer = nil
        onComplete()
    }
}

struct AddCustomActivityView: View {
    @Binding var name: String
    let onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Новая активность")
                .font(.headline)
            
            TextField("Название", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Сохранить") {
                if !name.isEmpty {
                    onSave()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            
            Spacer()
        }
        .padding(.top, 30)
    }
}
