import SwiftUI
import SwiftData

struct ProgressionView: View {
    @Query private var progressQuery: [UserProgress]
    @Query private var profilesQuery: [DetoxProfile]
    
    var progress: UserProgress {
        progressQuery.first ?? UserProgress()
    }
    
    var activeProfile: DetoxProfile? {
        let activeId = progress.activeProfileId
        return profilesQuery.first(where: { $0.id == activeId }) ?? profilesQuery.first
    }
    
    @AppStorage("detoxDayBoundaryHour", store: UserDefaults(suiteName: "group.com.gg.MyFocus") ?? .standard) private var detoxDayBoundaryHour: Int = 0

    private var maxActiveStreakDays: Int {
        var maxDays = 0
        for profile in profilesQuery {
            let days = DetoxDateHelper.calculateStreakDays(from: profile.streakStartDate, creationDate: profile.creationDate, currentBoundaryHour: detoxDayBoundaryHour, startBoundaryHour: profile.streakStartBoundaryHour)
            if days > maxDays {
                maxDays = days
            }
        }
        return maxDays
    }
    
    private var maxLongestStreakDays: Int {
        return profilesQuery.map { $0.longestStreakDays }.max() ?? 0
    }
    

    @AppStorage("activePalette", store: .shared) private var activePalette: String = "default"
    
    var body: some View {
        ScrollView {
                VStack(spacing: 30) {
                    // 1. Streak Card
                    VStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                            .shadow(color: .orange.opacity(0.4), radius: 10)
                        
                        Text("\(maxActiveStreakDays) дн.")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Текущий стрик детокса")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(1)
                        
                        if maxLongestStreakDays > 0 {
                            Text("Рекорд: \(maxLongestStreakDays) дн.")
                                .font(.caption2)
                                .foregroundColor(.orange.opacity(0.8))
                                .padding(.top, 2)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // 2. Medals Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("МЕДАЛИ ДЕТОКСА")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(1)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            let medals = [
                                (1, "Первый шаг", "Свобода началась", Color.orange, "medal.fill"),
                                (3, "Чистый разум", "Мысли проясняются", Color(red: 0, green: 0.8, blue: 0), "sparkles"),
                                (7, "Неделя силы", "Новая привычка", Color(red: 0.5, green: 0, blue: 1), "shield.fill"),
                                (15, "Победитель", "Власть над импульсом", Color.red, "flame.fill"),
                                (30, "Мастер детокса", "Золотой стандарт", Color.yellow, "trophy.fill"),
                                (100, "Изумрудный век", "Вековая стойкость", Color(red: 0.0, green: 0.6, blue: 0.3), "crown.fill"),
                                (365, "Алмазный год", "Целый год триумфа", Color(red: 0.6, green: 0.8, blue: 0.95), "suit.diamond.fill")
                            ]
                            
                            ForEach(medals, id: \.0) { days, title, description, color, icon in
                                let isUnlocked = maxActiveStreakDays >= days
                                
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(isUnlocked ? color.opacity(0.15) : Color.white.opacity(0.05))
                                            .frame(width: 50, height: 50)
                                            .overlay(
                                                Circle()
                                                    .stroke(isUnlocked ? color : Color.white.opacity(0.1), lineWidth: 2)
                                            )
                                            .shadow(color: isUnlocked ? color.opacity(0.4) : Color.clear, radius: 8)
                                        
                                        if isUnlocked {
                                            Image(systemName: icon)
                                                .font(.title3)
                                                .foregroundColor(color)
                                        } else {
                                            Image(systemName: "lock.fill")
                                                .font(.subheadline)
                                                .foregroundColor(.white.opacity(0.3))
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(title)
                                                .font(.headline)
                                                .foregroundColor(isUnlocked ? .white : .white.opacity(0.4))
                                            
                                            Spacer()
                                            
                                            Text("\(days) дн.")
                                                .font(.caption2.bold())
                                                .foregroundColor(isUnlocked ? color : .white.opacity(0.3))
                                                .padding(.vertical, 2)
                                                .padding(.horizontal, 6)
                                                .background(isUnlocked ? color.opacity(0.15) : Color.white.opacity(0.05))
                                                .cornerRadius(6)
                                        }
                                        
                                        Text(description)
                                            .font(.subheadline)
                                            .foregroundColor(isUnlocked ? .white.opacity(0.6) : .white.opacity(0.3))
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 3. Breathing Palettes
                    VStack(alignment: .leading, spacing: 15) {
                        Text("ВЫБОР ТЕМЫ")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(1)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(PaletteManager.shared.allPalettes, id: \.self) { key in
                                    let req = streakRequirement(for: key)
                                    let hasStreak = maxActiveStreakDays >= req
                                    
                                    Button(action: {
                                        if hasStreak {
                                            withAnimation {
                                                activePalette = key
                                            }
                                        }
                                    }) {
                                        VStack(spacing: 4) {
                                            PalettePreview(
                                                name: PaletteManager.shared.paletteNames[key] ?? key,
                                                colors: PaletteManager.shared.paletteColors[key] ?? [.gray],
                                                isUnlocked: hasStreak,
                                                isActive: activePalette == key
                                            )
                                            
                                            if req > 0 {
                                                Text("🔥 \(req) дн")
                                                    .font(.caption2)
                                                    .foregroundColor(hasStreak ? .orange : .white.opacity(0.4))
                                                    .padding(.vertical, 2)
                                                    .padding(.horizontal, 6)
                                                    .background(hasStreak ? Color.orange.opacity(0.15) : Color.white.opacity(0.05))
                                                    .cornerRadius(8)
                                            } else {
                                                Text("Базовая")
                                                    .font(.caption2)
                                                    .foregroundColor(.white.opacity(0.4))
                                                    .padding(.vertical, 2)
                                                    .padding(.horizontal, 6)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!hasStreak)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .withAmbientGlow()
            .navigationTitle("Прогресс")
            .navigationBarTitleDisplayMode(.inline)
            // Optional: you can keep or remove toolbarColorScheme if you want
            // .toolbarColorScheme(.dark, for: .navigationBar)
            // .toolbarBackground(Color.black, for: .navigationBar)
    }
    
    private func streakRequirement(for key: String) -> Int {
        switch key {
        case "default": return 0
        case "palette_2": return 1
        case "palette_3": return 3
        case "palette_4": return 7
        case "palette_5": return 15
        case "palette_gold": return 30
        case "palette_100": return 100
        case "palette_365": return 365
        default: return 0
        }
    }
}

struct PalettePreview: View {
    let name: String
    let colors: [Color]
    let isUnlocked: Bool
    let isActive: Bool
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isUnlocked ? colors : [Color.gray.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle()
                            .stroke(isActive ? Color.white : Color.clear, lineWidth: 3)
                    )
                
                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.title2)
                }
            }
            .padding(4)
            
            Text(name)
                .font(.subheadline)
                .foregroundColor(isUnlocked ? .white : .white.opacity(0.4))
        }
    }
}
