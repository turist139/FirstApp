with open("MyFocus/Views/Progression/StreakRecoveryView.swift", "r") as f:
    content = f.read()

# Add states
state_target = "    @State private var customReflection: String = \"\""
state_replacement = """    @State private var customReflection: String = ""
    @State private var specifyRelapseTime: Bool = false
    @State private var relapseTime: Date = Date()"""
content = content.replace(state_target, state_replacement)

# Add Date Picker UI
ui_target = """            VStack(alignment: .leading, spacing: 10) {
                Text("Что вы можете сделать по-другому?")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.headline)
                
                TextField("Например: уберу телефон в другую комнату...", text: $customReflection)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 30)"""

ui_replacement = """            VStack(alignment: .leading, spacing: 10) {
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
            
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Указать время начала срыва", isOn: $specifyRelapseTime)
                    .foregroundColor(.white.opacity(0.8))
                    .font(.headline)
                    .tint(Color(red: 0.5, green: 0.0, blue: 0.0))
                
                if specifyRelapseTime {
                    DatePicker("Начало срыва", selection: $relapseTime, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .colorScheme(.dark)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 30)"""
content = content.replace(ui_target, ui_replacement)

# Update logic
logic_target = """            let finalReason = selectedReason == "Другое" ? customFailReason : selectedReason
            let now = Date()
            
            let profileId = activeProfile?.id"""
logic_replacement = """            let finalReason = selectedReason == "Другое" ? customFailReason : selectedReason
            let now = Date()
            let relapseStart = specifyRelapseTime ? relapseTime : now
            
            let profileId = activeProfile?.id"""
content = content.replace(logic_target, logic_replacement)

log_target = """            // Log the relapse for today (as partial)
            let log = DetoxLog(
                date: now,
                isClean: false,"""
log_replacement = """            // Log the relapse for today (as partial)
            let log = DetoxLog(
                date: relapseStart,
                endDate: now,
                isClean: false,"""
content = content.replace(log_target, log_replacement)

with open("MyFocus/Views/Progression/StreakRecoveryView.swift", "w") as f:
    f.write(content)
