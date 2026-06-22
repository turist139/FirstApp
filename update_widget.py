import sys

with open("MyFocus/MyFocusWidgets/StreakWidget.swift", "r") as f:
    content = f.read()

# Add AppIntents import and Intent definitions
intents_code = """import SwiftData
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
"""

content = content.replace("import SwiftData\n", intents_code)

# Update StreakEntry
entry_target = """struct StreakEntry: TimelineEntry {
    let date: Date
    let streakDays: Int
    let activeHours: Int
    let paletteName: String
    let hasCheckedInToday: Bool
}"""
entry_replacement = """struct StreakEntry: TimelineEntry {
    let date: Date
    let streakDays: Int
    let activeHours: Int
    let paletteName: String
    let hasCheckedInToday: Bool
    let profileName: String
}"""
content = content.replace(entry_target, entry_replacement)

# Update StreakProvider
provider_target = """struct StreakProvider: TimelineProvider {
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

provider_replacement = """@available(iOS 17.0, *)
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

# Replace for fetchLatestData parameters inside provider if using TimelineProvider fallback
# Wait, actually we can just drop iOS 16 support for the widget if it's purely AppIntent, but iOS 17 is standard for interactive widgets.

content = content.replace(provider_target, provider_replacement)

# Update fetchLatestData logic
fetch_logic_target = """        let profilesFetch = FetchDescriptor<DetoxProfile>()
        let profiles = (try? context.fetch(profilesFetch)) ?? []
        let activeProfile = profiles.first { $0.id == progress.activeProfileId } ?? profiles.first"""
fetch_logic_replacement = """        let profilesFetch = FetchDescriptor<DetoxProfile>()
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
content = content.replace(fetch_logic_target, fetch_logic_replacement)

# Update fetchLatestData return
return_target = """        return StreakEntry(
            date: Date(),
            streakDays: currentStreak,
            activeHours: activeHours,
            paletteName: paletteName,
            hasCheckedInToday: hasCheckedIn
        )"""
return_replacement = """        return StreakEntry(
            date: Date(),
            streakDays: currentStreak,
            activeHours: activeHours,
            paletteName: activeProfile?.colorPalette ?? paletteName,
            hasCheckedInToday: hasCheckedIn,
            profileName: pName
        )"""
content = content.replace(return_target, return_replacement)

# Update StreakWidget
widget_target = """struct StreakWidget: Widget {
    let kind: String = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            if #available(iOS 17.0, *) {"""

widget_replacement = """struct StreakWidget: Widget {
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
            // Fallback for older iOS versions would go here if needed, but AppIntentTimelineProvider requires iOS 17+.
            fatalError("Widget requires iOS 17")
        }
    }
}
"""

# Replace the whole widget body since we changed the return structure
# It's safer to use regex or just direct replace if the text matches exactly
# Let's write the whole file manually by reading and replacing carefully.
