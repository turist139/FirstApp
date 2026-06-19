#if !SWIFT_PACKAGE
import WidgetKit
import SwiftUI
import SwiftData

struct StreakEntry: TimelineEntry {
    let date: Date
    let streakDays: Int
    let paletteName: String
    let hasCheckedInToday: Bool
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), streakDays: 7, paletteName: "default", hasCheckedInToday: true)
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
    
    private func fetchLatestData() -> StreakEntry {
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
            return StreakEntry(date: Date(), streakDays: 0, paletteName: paletteName, hasCheckedInToday: false)
        }
        
        let context = ModelContext(container)
        let progressFetch = FetchDescriptor<UserProgress>()
        let progress = (try? context.fetch(progressFetch))?.first ?? UserProgress()
        
        let profilesFetch = FetchDescriptor<DetoxProfile>()
        let profiles = (try? context.fetch(profilesFetch)) ?? []
        let activeProfile = profiles.first { $0.id == progress.activeProfileId } ?? profiles.first
        
        let currentStreak = activeProfile?.currentStreakDays ?? progress.currentStreakDays
        let lastCheckIn = activeProfile?.lastCheckInDate ?? progress.lastCheckInDate
        
        var hasCheckedIn = false
        if let lastCheck = lastCheckIn {
            var finalBoundary = boundaryHour
            let overrideDate = sharedDefaults.string(forKey: "todayBoundaryOverrideDate") ?? ""
            let overrideHour = sharedDefaults.integer(forKey: "todayBoundaryHourOverride")
            
            let defaultDetoxDay = DetoxDateHelper_Widget.detoxDay(for: Date(), boundaryHour: boundaryHour)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let currentDateString = formatter.string(from: defaultDetoxDay)
            if overrideHour >= 0 && currentDateString == overrideDate {
                finalBoundary = overrideHour
            }
            
            hasCheckedIn = DetoxDateHelper_Widget.isDateSameDetoxDay(lastCheck, Date(), boundaryHour: finalBoundary)
        }
        
        return StreakEntry(
            date: Date(),
            streakDays: currentStreak,
            paletteName: paletteName,
            hasCheckedInToday: hasCheckedIn
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
                Text("\(entry.streakDays)")
                    .font(.system(size: 18, weight: .bold))
            }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Стрик детокса")
                        .font(.system(size: 10))
                    Text("\(entry.streakDays) \(daysString(entry.streakDays))")
                        .font(.system(size: 14, weight: .bold))
                }
            }
        case .accessoryInline:
            Text("\(Image(systemName: "flame.fill")) \(entry.streakDays) \(daysString(entry.streakDays))")
        default:
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
                        
                        Text("\(entry.streakDays)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(daysString(entry.streakDays))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
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
                                
                                Text("\(entry.streakDays) \(daysString(entry.streakDays))")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.15))
                                .frame(height: 70)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("MY FOCUS")
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
}

struct StreakWidget: Widget {
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
}

// MARK: - Date helper specific to widgets to ensure no compilation dependency
struct DetoxDateHelper_Widget {
    static func detoxDay(for date: Date, boundaryHour: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let hour = components.hour ?? 0
        
        if hour < boundaryHour {
            if let prevDay = calendar.date(byAdding: .day, value: -1, to: date) {
                components = calendar.dateComponents([.year, .month, .day], from: prevDay)
            }
        } else {
            components = calendar.dateComponents([.year, .month, .day], from: date)
        }
        
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? date
    }
    
    static func isDateSameDetoxDay(_ date1: Date, _ date2: Date, boundaryHour: Int) -> Bool {
        let day1 = detoxDay(for: date1, boundaryHour: boundaryHour)
        let day2 = detoxDay(for: date2, boundaryHour: boundaryHour)
        return Calendar.current.isDate(day1, inSameDayAs: day2)
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
