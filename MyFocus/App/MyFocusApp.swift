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
            PastStreak.self
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
            print("Failed to load ModelContainer: \(error.localizedDescription). Resetting database...")
            
            // Delete the store files if migration failed (migration error)
            let fm = FileManager.default
            let storeDir = storeURL.deletingLastPathComponent()
            let storeNames = ["default.store", "default.store-shm", "default.store-wal"]
            for name in storeNames {
                let fileURL = storeDir.appendingPathComponent(name)
                try? fm.removeItem(at: fileURL)
            }
            
            // Also clean any other .store or .sqlite files in the store directory
            if let files = try? fm.contentsOfDirectory(at: storeDir, includingPropertiesForKeys: nil) {
                for file in files {
                    let pathExt = file.pathExtension.lowercased()
                    if pathExt == "store" || pathExt == "sqlite" || file.lastPathComponent.contains("default.store") {
                        try? fm.removeItem(at: file)
                    }
                }
            }
            
            // Try creating the container one more time
            do {
                container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
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
                        PastStreak.rebuildPastStreaks(logs: logs, context: context)
                        UserDefaults.standard.set(true, forKey: "didRebuildPastStreaksWithHours3")
                    }
                }
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
