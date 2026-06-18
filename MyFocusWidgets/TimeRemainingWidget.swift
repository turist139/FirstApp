#if !SWIFT_PACKAGE
import WidgetKit
import SwiftUI
import SwiftData

struct TimeEntry: TimelineEntry {
    let date: Date
    let endDate: Date
    let hasCheckedInToday: Bool
    let boundaryHour: Int
    let paletteName: String
}

struct TimeRemainingProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimeEntry {
        let now = Date()
        let calendar = Calendar.current
        let defaultEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now) ?? now
        return TimeEntry(date: now, endDate: defaultEnd, hasCheckedInToday: false, boundaryHour: 22, paletteName: "default")
    }

    func getSnapshot(in context: Context, completion: @escaping (TimeEntry) -> ()) {
        let entry = fetchLatestData()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimeEntry>) -> ()) {
        let entry = fetchLatestData()
        
        var entries = [entry]
        
        let now = Date()
        if entry.endDate > now && entry.endDate.timeIntervalSince(now) < 12 * 3600 {
            let endEntry = TimeEntry(
                date: entry.endDate,
                endDate: entry.endDate,
                hasCheckedInToday: entry.hasCheckedInToday,
                boundaryHour: entry.boundaryHour,
                paletteName: entry.paletteName
            )
            entries.append(endEntry)
        }
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func fetchLatestData() -> TimeEntry {
        let sharedDefaults = UserDefaults(suiteName: "group.com.gg.MyFocus") ?? .standard
        let paletteName = sharedDefaults.string(forKey: "activePalette") ?? "default"
        let boundaryHour = sharedDefaults.integer(forKey: "detoxDayBoundaryHour")
        
        let schema = Schema([UserProgress.self, DetoxLog.self])
        var storeURL: URL
        if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.gg.MyFocus") {
            storeURL = sharedURL.appendingPathComponent("default.store")
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            storeURL = appSupport.appendingPathComponent("default.store")
        }
        
        let config = ModelConfiguration(url: storeURL)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            let now = Date()
            let endOfCurrentDay = endOfDetoxDay(for: now, boundaryHour: boundaryHour)
            return TimeEntry(date: now, endDate: endOfCurrentDay, hasCheckedInToday: false, boundaryHour: boundaryHour, paletteName: paletteName)
        }
        
        let context = ModelContext(container)
        let progressFetch = FetchDescriptor<UserProgress>()
        let progress = (try? context.fetch(progressFetch))?.first ?? UserProgress()
        
        var finalBoundary = boundaryHour
        let overrideDate = sharedDefaults.string(forKey: "todayBoundaryOverrideDate") ?? ""
        let overrideHour = sharedDefaults.integer(forKey: "todayBoundaryHourOverride")
        
        let defaultDetoxDay = detoxDay(for: Date(), boundaryHour: boundaryHour)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let currentDateString = formatter.string(from: defaultDetoxDay)
        if overrideHour >= 0 && currentDateString == overrideDate {
            finalBoundary = overrideHour
        }
        
        var hasCheckedIn = false
        if let lastCheck = progress.lastCheckInDate {
            hasCheckedIn = isDateSameDetoxDay(lastCheck, Date(), boundaryHour: finalBoundary)
        }
        
        let now = Date()
        let endOfCurrentDay = endOfDetoxDay(for: now, boundaryHour: finalBoundary)
        
        return TimeEntry(
            date: now,
            endDate: endOfCurrentDay,
            hasCheckedInToday: hasCheckedIn,
            boundaryHour: finalBoundary,
            paletteName: paletteName
        )
    }
    
    private func detoxDay(for date: Date, boundaryHour: Int) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        if hour >= boundaryHour {
            return calendar.startOfDay(for: date)
        } else {
            return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: date) ?? date)
        }
    }
    
    private func endOfDetoxDay(for date: Date, boundaryHour: Int) -> Date {
        let dayStart = detoxDay(for: date, boundaryHour: boundaryHour)
        let calendar = Calendar.current
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return date }
        return calendar.date(byAdding: .hour, value: boundaryHour, to: nextDay) ?? date
    }
    
    private func isDateSameDetoxDay(_ date1: Date, _ date2: Date, boundaryHour: Int) -> Bool {
        let day1 = detoxDay(for: date1, boundaryHour: boundaryHour)
        let day2 = detoxDay(for: date2, boundaryHour: boundaryHour)
        return Calendar.current.isDate(day1, inSameDayAs: day2)
    }
}

struct TimeRemainingWidgetEntryView : View {
    var entry: TimeRemainingProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var themeColors: [Color] {
        PaletteColors_Widget.colors(for: entry.paletteName)
    }
    
    var formattedBoundaryTime: String {
        return String(format: "%02d:00", entry.boundaryHour)
    }
    
    var isTimeUp: Bool {
        entry.endDate <= Date()
    }
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 2) {
                if entry.hasCheckedInToday {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                } else if isTimeUp {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                } else {
                    Text(entry.endDate, style: .relative)
                        .font(.system(size: 14, weight: .bold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                }
            }
        case .accessoryRectangular:
            HStack(spacing: 6) {
                Image(systemName: "hourglass")
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    if entry.hasCheckedInToday {
                        Text("День завершен")
                            .font(.system(size: 12, weight: .bold))
                    } else if isTimeUp {
                        Text("Ожидание")
                            .font(.system(size: 12, weight: .bold))
                        Text("Сделайте чек-ин!")
                            .font(.system(size: 10))
                    } else {
                        Text("Осталось:")
                            .font(.system(size: 10))
                        Text(entry.endDate, style: .relative)
                            .font(.system(size: 14, weight: .bold))
                    }
                }
            }
        case .accessoryInline:
            if entry.hasCheckedInToday {
                Text("✅ Завершен")
            } else if isTimeUp {
                Text("⚠️ Ждет чек-ин")
            } else {
                Text("⏳ \(Text(entry.endDate, style: .relative))")
            }
        default:
            ZStack {
                LinearGradient(
                    colors: [Color(white: 0.08), Color(white: 0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                VStack(spacing: 8) {
                    HStack {
                        Text("MY FOCUS")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(themeColors.first ?? .green)
                            .tracking(1.5)
                        
                        Spacer()
                        
                        Text("Конец в \(formattedBoundaryTime)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    
                    Spacer()
                    
                    if entry.hasCheckedInToday {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.green)
                            .padding(.bottom, 2)
                        
                        Text("ДЕНЬ ЗАВЕРШЕН")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Отличная работа сегодня!")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    } else if isTimeUp {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.orange)
                            .padding(.bottom, 2)
                        
                        Text("ОЖИДАНИЕ ОТЧЕТА")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Сделайте чек-ин!")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4))
                    } else {
                        Text(entry.endDate, style: .timer)
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                            .shadow(color: themeColors.first?.opacity(0.3) ?? .green.opacity(0.3), radius: 6)
                        
                        Text("до завершения дня")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 12)
            }
        }
    }
}

struct TimeRemainingWidget: Widget {
    let kind: String = "TimeRemainingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimeRemainingProvider()) { entry in
            if #available(iOS 17.0, *) {
                TimeRemainingWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                TimeRemainingWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Осталось Времени")
        .description("Отображает обратный отсчет до конца сегодняшнего дня детокса.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}
#endif
