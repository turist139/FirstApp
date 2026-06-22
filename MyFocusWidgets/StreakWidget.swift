#if !SWIFT_PACKAGE
import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

@available(iOS 17.0, *)
struct WidgetProfile: AppEntity {
    var id: UUID
    var name: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Детокс Профиль"
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    static var defaultQuery = WidgetProfileQuery()
}

@available(iOS 17.0, *)
struct WidgetProfileQuery: EntityQuery {
    func entities(for identifiers: [WidgetProfile.ID]) async throws -> [WidgetProfile] {
        return fetchProfiles().filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [WidgetProfile] {
        return fetchProfiles()
    }
    
    func defaultResult() async -> WidgetProfile? {
        return fetchProfiles().first
    }
    
    private func fetchProfiles() -> [WidgetProfile] {
        let schema = Schema([FocusSession.self, UserProgress.self, BreakActivity.self, MindfulnessSession.self, DetoxLog.self, PastStreak.self, DetoxProfile.self])
        var storeURL: URL
        if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.gg.MyFocus") {
            storeURL = sharedURL.appendingPathComponent("default.store")
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            storeURL = appSupport.appendingPathComponent("default.store")
        }
        
        let config = ModelConfiguration(url: storeURL)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            return []
        }
        
        let context = ModelContext(container)
        let profilesFetch = FetchDescriptor<DetoxProfile>()
        let profiles = (try? context.fetch(profilesFetch)) ?? []
        return profiles.map { WidgetProfile(id: $0.id, name: $0.name) }
    }
}

@available(iOS 17.0, *)
struct StreakWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Выбор Детокса"
    static var description = IntentDescription("Выберите детокс для отображения.")

    @Parameter(title: "Детокс")
    var profile: WidgetProfile?
}

struct StreakEntry: TimelineEntry {
    let date: Date
    let streakDays: Int
    let activeHours: Int
    let paletteName: String
    let hasCheckedInToday: Bool
    let profileName: String
}

@available(iOS 17.0, *)
struct StreakProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), streakDays: 7, activeHours: 168, paletteName: "default", hasCheckedInToday: true, profileName: "Трекинг")
    }

    func snapshot(for configuration: StreakWidgetConfigurationIntent, in context: Context) async -> StreakEntry {
        return fetchLatestData(for: configuration.profile)
    }

    func timeline(for configuration: StreakWidgetConfigurationIntent, in context: Context) async -> Timeline<StreakEntry> {
        let entry = fetchLatestData(for: configuration.profile)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func fetchLatestData(for widgetProfile: WidgetProfile?) -> StreakEntry {
        let sharedDefaults = UserDefaults(suiteName: "group.com.gg.MyFocus") ?? .standard
        let paletteName = sharedDefaults.string(forKey: "activePalette") ?? "default"
        let boundaryHour = sharedDefaults.integer(forKey: "detoxDayBoundaryHour")
        
        let schema = Schema([FocusSession.self, UserProgress.self, BreakActivity.self, MindfulnessSession.self, DetoxLog.self, PastStreak.self, DetoxProfile.self])
        var storeURL: URL
        if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.gg.MyFocus") {
            storeURL = sharedURL.appendingPathComponent("default.store")
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            storeURL = appSupport.appendingPathComponent("default.store")
        }
        
        let config = ModelConfiguration(url: storeURL)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            return StreakEntry(date: Date(), streakDays: 0, activeHours: 0, paletteName: paletteName, hasCheckedInToday: false, profileName: "Трекинг")
        }
        
        let context = ModelContext(container)
        let progressFetch = FetchDescriptor<UserProgress>()
        let progress = (try? context.fetch(progressFetch))?.first ?? UserProgress()
        
        let profilesFetch = FetchDescriptor<DetoxProfile>()
        let profiles = (try? context.fetch(profilesFetch)) ?? []
        
        var activeProfile: DetoxProfile?
        if let widgetProfileId = widgetProfile?.id {
            activeProfile = profiles.first { $0.id == widgetProfileId }
        }
        if activeProfile == nil {
            activeProfile = profiles.first { $0.id == progress.activeProfileId } ?? profiles.first
        }
        
        let pName = activeProfile?.name ?? "Трекинг"

        
        let isMainProfile = activeProfile?.id == progress.activeProfileId
        let streakStartDate = activeProfile?.streakStartDate ?? (isMainProfile ? progress.streakStartDate : (activeProfile?.creationDate ?? Date()))
        let creationDate = activeProfile?.creationDate ?? Date()
        let lastCheckIn = activeProfile?.lastCheckInDate ?? (isMainProfile ? progress.lastCheckInDate : nil)
        
        var hasCheckedIn = false
        if let lastCheck = lastCheckIn {
            var finalBoundary = boundaryHour
            let overrideDate = sharedDefaults.string(forKey: "todayBoundaryOverrideDate") ?? ""
            let overrideHour = sharedDefaults.integer(forKey: "todayBoundaryHourOverride")
            
            let defaultDetoxDay = DetoxDateHelper.detoxDay(for: Date(), boundaryHour: boundaryHour)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let currentDateString = formatter.string(from: defaultDetoxDay)
            if overrideHour >= 0 && currentDateString == overrideDate {
                finalBoundary = overrideHour
            }
            
            hasCheckedIn = DetoxDateHelper.isDateSameDetoxDay(lastCheck, Date(), boundaryHour: finalBoundary)
        }
        
        let streakStartBoundaryHour = activeProfile?.streakStartBoundaryHour
        let activeHours = DetoxDateHelper.calculateActiveHours(from: streakStartDate, creationDate: creationDate)
        let currentStreak = DetoxDateHelper.calculateStreakDays(from: streakStartDate, creationDate: creationDate, currentBoundaryHour: boundaryHour, startBoundaryHour: streakStartBoundaryHour)
        
        return StreakEntry(
            date: Date(),
            streakDays: currentStreak,
            activeHours: activeHours,
            paletteName: paletteName,
            hasCheckedInToday: hasCheckedIn,
            profileName: pName
        )
    }
}

struct StreakWidgetEntryView : View {
    var entry: StreakProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var themeColors: [Color] {
        PaletteColors_Widget.colors(for: entry.paletteName)
    }
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16))
                if entry.streakDays < 1 {
                    Text("\(entry.activeHours)h")
                        .font(.system(size: 18, weight: .bold))
                } else {
                    Text("\(entry.streakDays)")
                        .font(.system(size: 18, weight: .bold))
                }
            }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Стрик детокса")
                        .font(.system(size: 10))
                    if entry.streakDays < 1 {
                        Text("\(entry.activeHours) \(hoursString(entry.activeHours))")
                            .font(.system(size: 14, weight: .bold))
                    } else {
                        Text("\(entry.streakDays) \(daysString(entry.streakDays))")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
            }
        case .accessoryInline:
            if entry.streakDays < 1 {
                Text("\(Image(systemName: "flame.fill")) \(entry.activeHours) \(hoursString(entry.activeHours))")
            } else {
                Text("\(Image(systemName: "flame.fill")) \(entry.streakDays) \(daysString(entry.streakDays))")
            }
        default:
            VStack(spacing: 8) {
                    if family == .systemSmall {
                        Text(entry.profileName.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(themeColors.first ?? .green)
                            .tracking(1)
                            .lineLimit(1)
                            
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: themeColors, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.15))
                                .frame(width: 55, height: 55)
                            
                            Image(systemName: "flame.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(
                                    LinearGradient(colors: themeColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .shadow(color: themeColors.first?.opacity(0.4) ?? .green.opacity(0.4), radius: 8)
                        }
                        
                        if entry.streakDays < 1 {
                            Text("\(entry.activeHours)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(hoursString(entry.activeHours))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                        } else {
                            Text("\(entry.streakDays)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(daysString(entry.streakDays))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    } else {
                        HStack(spacing: 20) {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: themeColors, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.15))
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(
                                            LinearGradient(colors: themeColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                        .shadow(color: themeColors.first?.opacity(0.4) ?? .green.opacity(0.4), radius: 6)
                                }
                                
                                if entry.streakDays < 1 {
                                    Text("\(entry.activeHours) \(hoursString(entry.activeHours))")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                } else {
                                    Text("\(entry.streakDays) \(daysString(entry.streakDays))")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.15))
                                .frame(height: 70)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(entry.profileName.uppercased())
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(themeColors.first ?? .green)
                                    .tracking(1)
                                
                                if entry.hasCheckedInToday {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 14))
                                        Text("День завершен")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    Text("Вы сегодня молодец! Отдыхайте.")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.5))
                                        .lineLimit(2)
                                } else {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 14))
                                        Text("Стрик под угрозой")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    Text("Не забудьте отметиться вечером, чтобы сберечь стрик!")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.5))
                                        .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                    }
            }
        }
    }
    

    private func daysString(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        
        if mod100 >= 11 && mod100 <= 19 {
            return "дней"
        }
        switch mod10 {
        case 1:
            return "день"
        case 2, 3, 4:
            return "дня"
        default:
            return "дней"
        }
    }
    
    private func hoursString(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod100 >= 11 && mod100 <= 14 {
            return "часов"
        } else if mod10 == 1 {
            return "час"
        } else if mod10 >= 2 && mod10 <= 4 {
            return "часа"
        } else {
            return "часов"
        }
    }
}

struct StreakWidget: Widget {
    let kind: String = "StreakWidget"

    var body: some WidgetConfiguration {
        if #available(iOS 17.0, *) {
            return AppIntentConfiguration(kind: kind, intent: StreakWidgetConfigurationIntent.self, provider: StreakProvider()) { entry in
                StreakWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        LinearGradient(
                            colors: [Color(white: 0.08), Color(white: 0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            }
            .configurationDisplayName("Прогресс Детокса")
            .description("Показывает количество дней вашего стрика детокса.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
            .contentMarginsDisabled()
        } else {
            fatalError("Widget requires iOS 17")
        }
    }
}



struct PaletteColors_Widget {
    static func colors(for name: String) -> [Color] {
        switch name {
        case "default_warm":
            return [Color.orange, Color.red]
        case "default_cool":
            return [Color.blue, Color.purple]
        case "default_calm":
            return [Color.teal, Color.cyan]
        case "palette_15":
            return [Color(red: 0.95, green: 0.4, blue: 0.13), Color(red: 0.9, green: 0.15, blue: 0.1)]
        case "palette_30":
            return [Color.purple, Color(red: 0.9, green: 0.3, blue: 0.6)]
        case "palette_50":
            return [Color.yellow, Color.orange]
        case "palette_100":
            return [Color(red: 0.0, green: 0.6, blue: 0.3), Color(red: 0.0, green: 0.35, blue: 0.15)]
        case "palette_365":
            return [Color(red: 0.5, green: 0.85, blue: 1.0), Color(red: 0.1, green: 0.4, blue: 0.8)]
        default: // "default"
            return [Color.green, Color(red: 0.0, green: 0.6, blue: 0.4)]
        }
    }
}
#endif
