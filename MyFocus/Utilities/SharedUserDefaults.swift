import Foundation

extension UserDefaults {
    /// Shared UserDefaults suite for App Groups
    public static var shared: UserDefaults {
        #if targetEnvironment(simulator)
        // In simulator, if app group is failing, we can fallback or use it
        return UserDefaults(suiteName: "group.com.gg.MyFocus") ?? .standard
        #else
        return UserDefaults(suiteName: "group.com.gg.MyFocus") ?? .standard
        #endif
    }
    
    /// Migrates existing keys from standard UserDefaults to shared suite
    public static func migrateToSharedIfNeeded() {
        let sharedSuite = UserDefaults.shared
        // If they are the same (.standard), no migration is needed
        if sharedSuite === UserDefaults.standard {
            return
        }
        
        let keysToMigrate = [
            "activePalette",
            "detoxDayBoundaryHour",
            "todayBoundaryHourOverride",
            "todayBoundaryOverrideDate",
            "notificationHour",
            "notificationMinute",
            "morningNotificationHour",
            "morningNotificationMinute",
            "overrideEveningDate",
            "overrideEveningHour",
            "overrideEveningMinute",
            "overrideMorningDate",
            "overrideMorningHour",
            "overrideMorningMinute",
            "customMantra"
        ]
        
        let hasMigratedKey = "hasMigratedToSharedSuite"
        guard !sharedSuite.bool(forKey: hasMigratedKey) else { return }
        
        for key in keysToMigrate {
            if let value = UserDefaults.standard.object(forKey: key) {
                sharedSuite.set(value, forKey: key)
            }
        }
        
        sharedSuite.set(true, forKey: hasMigratedKey)
        sharedSuite.synchronize()
        print("Successfully migrated UserDefaults to shared suite.")
    }
}
