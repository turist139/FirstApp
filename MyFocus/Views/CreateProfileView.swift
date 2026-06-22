import SwiftUI
import SwiftData
import WidgetKit

struct CreateProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var progress: UserProgress
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "flame.fill"
    @State private var newHabit: String = ""
    @State private var habits: [String] = []
    
    @AppStorage("activePalette", store: .shared) private var activePalette: String = "default"
    var themeColor: Color {
        PaletteManager.shared.paletteColors[activePalette]?.first ?? .green
    }
    
    let icons = ["flame.fill", "gamecontroller.fill", "fork.knife", "wineglass.fill", "cup.and.saucer.fill", "smoke.fill", "tv.fill", "play.rectangle.fill"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Название")) {
                    TextField("Например: Соцсети, Сладкое...", text: $name)
                }
                
                Section(header: Text("Иконка")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 16) {
                        ForEach(icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(selectedIcon == icon ? .white : .gray)
                                .frame(width: 44, height: 44)
                                .background(selectedIcon == icon ? themeColor : Color.clear)
                                .clipShape(Circle())
                                .onTapGesture {
                                    withAnimation {
                                        selectedIcon = icon
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Привычки (от чего отказываемся)")) {
                    HStack {
                        TextField("Новая привычка", text: $newHabit)
                        Button(action: {
                            let trimmed = newHabit.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && !habits.contains(trimmed) {
                                habits.append(trimmed)
                                newHabit = ""
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(themeColor)
                        }
                    }
                    
                    ForEach(habits, id: \.self) { habit in
                        Text(habit)
                    }
                    .onDelete { indexSet in
                        habits.remove(atOffsets: indexSet)
                    }
                }
            }
            .navigationTitle("Новый Детокс")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        let newProfile = DetoxProfile(
                            name: name.isEmpty ? "Новый Детокс" : name,
                            icon: selectedIcon,
                            detoxHabits: habits.isEmpty ? ["Новая привычка"] : habits
                        )
                        modelContext.insert(newProfile)
                        progress.activeProfileId = newProfile.id
                        try? modelContext.save()
                        
                        // Sync profile list to widget
                        let profilesFetch = FetchDescriptor<DetoxProfile>()
                        if let allProfiles = try? modelContext.fetch(profilesFetch) {
                            MyFocusApp.syncProfileListToDefaults(profiles: allProfiles)
                        }
                        WidgetCenter.shared.reloadAllTimelines()
                        
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
