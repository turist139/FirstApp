import re

with open("MyFocusWidgets/StreakWidget.swift", "r") as f:
    content = f.read()

# 1. Imports and AppIntent
intent_code = """import SwiftData
import AppIntents

@available(iOS 17.0, *)
struct WidgetProfile: AppEntity {
    var id: UUID
    var name: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Детокс Профиль"
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\\(name)")
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
"""
content = content.replace("import SwiftData\n", intent_code)

# 2. Entry
content = content.replace(
    "let hasCheckedInToday: Bool",
    "let hasCheckedInToday: Bool\n    let profileName: String"
)

# 3. Provider
provider_old = """struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), streakDays: 7, activeHours: 168, paletteName: "default", hasCheckedInToday: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> ()) {
        let entry = fetchLatestData()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> ()) {
        let entry = fetchLatestData()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func fetchLatestData() -> StreakEntry {"""

provider_new = """@available(iOS 17.0, *)
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
    
    private func fetchLatestData(for widgetProfile: WidgetProfile?) -> StreakEntry {"""
content = content.replace(provider_old, provider_new)

# 4. Profile logic
logic_old = """        let profilesFetch = FetchDescriptor<DetoxProfile>()
        let profiles = (try? context.fetch(profilesFetch)) ?? []
        let activeProfile = profiles.first { $0.id == progress.activeProfileId } ?? profiles.first"""
logic_new = """        let profilesFetch = FetchDescriptor<DetoxProfile>()
        let profiles = (try? context.fetch(profilesFetch)) ?? []
        
        var activeProfile: DetoxProfile?
        if let widgetProfileId = widgetProfile?.id {
            activeProfile = profiles.first { $0.id == widgetProfileId }
        }
        if activeProfile == nil {
            activeProfile = profiles.first { $0.id == progress.activeProfileId } ?? profiles.first
        }
        
        let pName = activeProfile?.name ?? "Трекинг"
"""
content = content.replace(logic_old, logic_new)

# 5. Return Entry
return_old = """        return StreakEntry(
            date: Date(),
            streakDays: currentStreak,
            activeHours: activeHours,
            paletteName: paletteName,
            hasCheckedInToday: hasCheckedIn
        )"""
return_new = """        return StreakEntry(
            date: Date(),
            streakDays: currentStreak,
            activeHours: activeHours,
            paletteName: activeProfile?.colorPalette ?? paletteName,
            hasCheckedInToday: hasCheckedIn,
            profileName: pName
        )"""
content = content.replace(return_old, return_new)

# 6. Widget UI for small widget
ui_old = """                default:
                    VStack(spacing: 8) {
                            if family == .systemSmall {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: themeColors, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.15))
                                        .frame(width: 65, height: 65)
                                    
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(
                                            LinearGradient(colors: themeColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                        .shadow(color: themeColors.first?.opacity(0.4) ?? .green.opacity(0.4), radius: 8)
                                }
                                
                                if entry.streakDays < 1 {
                                    Text("\\(entry.activeHours)")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Text(hoursString(entry.activeHours))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white.opacity(0.4))
                                } else {
                                    Text("\\(entry.streakDays)")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Text(daysString(entry.streakDays))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            } else {
                                HStack(spacing: 20) {"""
ui_new = """                default:
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
                                    Text("\\(entry.activeHours)")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                } else {
                                    Text("\\(entry.streakDays)")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            } else {
                                HStack(spacing: 20) {"""
content = content.replace(ui_old, ui_new)

# 7. Add profileName to systemMedium
medium_ui_old = """                            VStack(alignment: .leading, spacing: 8) {
                                Text("MY FOCUS")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(themeColors.first ?? .green)
                                    .tracking(1)"""
medium_ui_new = """                            VStack(alignment: .leading, spacing: 8) {
                                Text(entry.profileName.uppercased())
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(themeColors.first ?? .green)
                                    .tracking(1)"""
content = content.replace(medium_ui_old, medium_ui_new)

# 8. Widget struct
widget_old = """struct StreakWidget: Widget {
    let kind: String = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            if #available(iOS 17.0, *) {
                StreakWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        LinearGradient(
                            colors: [Color(white: 0.08), Color(white: 0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            } else {
                StreakWidgetEntryView(entry: entry)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color(white: 0.08), Color(white: 0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .configurationDisplayName("Прогресс Детокса")
        .description("Показывает количество дней вашего стрика детокса.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}"""
widget_new = """struct StreakWidget: Widget {
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
}"""
content = content.replace(widget_old, widget_new)

with open("MyFocusWidgets/StreakWidget.swift", "w") as f:
    f.write(content)

