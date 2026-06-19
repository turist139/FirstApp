import SwiftUI
import SwiftData
import UserNotifications

@main
struct MyFocusApp: App {
    @State private var showOnboarding: Bool = true
    @StateObject private var timerManager = TimerManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UserDefaults.migrateToSharedIfNeeded()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FocusSession.self,
            UserProgress.self,
            BreakActivity.self,
            MindfulnessSession.self,
            DetoxLog.self,
            PastStreak.self,
            DetoxProfile.self
        ])
        
        // Setup shared SQLite store for App Groups (falls back to local if App Group is not configured)
        var storeURL: URL
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let localStoreURL = appSupport.appendingPathComponent("default.store")
        
        if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.gg.MyFocus") {
            storeURL = sharedURL.appendingPathComponent("default.store")
            // Migrate local database to shared container if needed
            if !FileManager.default.fileExists(atPath: storeURL.path) && FileManager.default.fileExists(atPath: localStoreURL.path) {
                try? FileManager.default.copyItem(at: localStoreURL, to: storeURL)
                try? FileManager.default.copyItem(at: URL(fileURLWithPath: localStoreURL.path + "-shm"), to: URL(fileURLWithPath: storeURL.path + "-shm"))
                try? FileManager.default.copyItem(at: URL(fileURLWithPath: localStoreURL.path + "-wal"), to: URL(fileURLWithPath: storeURL.path + "-wal"))
            }
        } else {
            storeURL = localStoreURL
        }
        
        let modelConfiguration = ModelConfiguration(url: storeURL)

        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // ВАЖНО: Мы убрали автоматическое удаление базы данных при ошибках миграции.
            // Теперь, если структура моделей изменится без плана миграции (SchemaMigrationPlan),
            // приложение упадет здесь (crash), что защитит данные пользователя от случайного удаления.
            fatalError("Could not create ModelContainer: \(error)")
        }
        
        // Pre-populate default activities if none exist
        Task { @MainActor in
            let context = container.mainContext
            let descriptor = FetchDescriptor<BreakActivity>()
            if let count = try? context.fetchCount(descriptor), count == 0 {
                let defaultActivities = [
                    BreakActivity(name: "Растяжка (Stretching)"),
                    BreakActivity(name: "Отжимания (Push-ups)"),
                    BreakActivity(name: "Гимнастика для глаз (Eye exercises)"),
                    BreakActivity(name: "Пройтись по комнате (Walk around)")
                ]
                for activity in defaultActivities {
                    context.insert(activity)
                }
                try? context.save()
            }
            
            let detoxDescriptor = FetchDescriptor<DetoxLog>()
            if let detoxCount = try? context.fetchCount(detoxDescriptor), detoxCount == 0 {
                DetoxMockDataHelper.generateMockData(context: context)
            } else {
                if !UserDefaults.standard.bool(forKey: "didRebuildPastStreaksWithHours3") {
                    let fetch = FetchDescriptor<DetoxLog>(sortBy: [SortDescriptor(\.date)])
                    if let logs = try? context.fetch(fetch) {
                        PastStreak.rebuildPastStreaks(logs: logs, context: context) // Will just use nil profileId for now, migration handles it next
                        UserDefaults.standard.set(true, forKey: "didRebuildPastStreaksWithHours3")
                    }
                }
            }
            
            // Initialize database defaults (UserProgress & default DetoxProfile)
            let userProgressFetch = FetchDescriptor<UserProgress>()
            let progressList = (try? context.fetch(userProgressFetch)) ?? []
            let profilesFetch = FetchDescriptor<DetoxProfile>()
            let existingProfiles = (try? context.fetch(profilesFetch)) ?? []
            
            let progress: UserProgress
            if let firstProgress = progressList.first {
                progress = firstProgress
            } else {
                let newProgress = UserProgress()
                context.insert(newProgress)
                progress = newProgress
            }
            
            if existingProfiles.isEmpty {
                // Create default profile
                let defaultProfile = DetoxProfile(
                    name: "Основной",
                    icon: "flame.fill",
                    creationDate: progress.streakStartDate ?? Date(),
                    detoxHabits: progress.detoxHabits.isEmpty ? ["YouTube", "Новости", "Telegram", "Прямые эфиры"] : progress.detoxHabits,
                    currentStreakDays: progress.currentStreakDays,
                    longestStreakDays: progress.longestStreakDays,
                    lastCheckInDate: progress.lastCheckInDate,
                    streakStartDate: progress.streakStartDate,
                    streakSavedToday: progress.streakSavedToday,
                    streakQuestsCompleted: progress.streakQuestsCompleted
                )
                context.insert(defaultProfile)
                
                // Assign orphaned logs
                let logsFetch = FetchDescriptor<DetoxLog>()
                if let logs = try? context.fetch(logsFetch) {
                    for log in logs where log.profileId == nil {
                        log.profileId = defaultProfile.id
                    }
                }
                
                // Assign orphaned streaks
                let streaksFetch = FetchDescriptor<PastStreak>()
                if let streaks = try? context.fetch(streaksFetch) {
                    for streak in streaks where streak.profileId == nil {
                        streak.profileId = defaultProfile.id
                    }
                }
                
                progress.activeProfileId = defaultProfile.id
                progress.isMigratedToProfiles = true
                try? context.save()
            } else if progress.activeProfileId == nil {
                progress.activeProfileId = existingProfiles.first?.id
                try? context.save()
            }
        }
        
        return container
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingBreathingView(onComplete: {
                        withAnimation(.easeInOut(duration: 0.8)) {
                            showOnboarding = false
                        }
                    })
                    .preferredColorScheme(.dark)
                } else {
                    MainTabView()
                        .preferredColorScheme(.dark)
                        .environmentObject(timerManager)
                }
            }
            .onAppear {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                timerManager.updateFromBackground()
            }
        }
    }
}
