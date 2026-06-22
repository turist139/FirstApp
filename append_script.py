code = """
enum MyFocusSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [FocusSession.self, UserProgress.self, BreakActivity.self, MindfulnessSession.self, DetoxLog.self, PastStreak.self, DetoxProfile.self]
    }
    
    @Model final class FocusSession {
        var id: UUID = UUID()
        var date: Date = Date()
        var durationMinutes: Int = 0
        var productivityScore: Int = 0
    }
    
    @Model final class UserProgress {
        var id: UUID = UUID()
        var totalXP: Int = 0
        var currentLevel: Int = 1
        var currentStreakDays: Int = 0
        var longestStreakDays: Int = 0
        var availableFreezes: Int = 1
        var unlockedPaletteIDs: [String] = []
        var lastActiveDate: Date? = nil
        var streakStartDate: Date? = nil
        var detoxHabits: [String] = []
        var lastCheckInDate: Date? = nil
        var streakSavedToday: Bool = false
        var streakQuestsCompleted: Int = 0
        var activeProfileId: UUID? = nil
        var isMigratedToProfiles: Bool? = nil
    }
    
    @Model final class BreakActivity {
        var id: UUID = UUID()
        var name: String = ""
        var isCustom: Bool = false
    }
    
    @Model final class MindfulnessSession {
        var id: UUID = UUID()
        var date: Date = Date()
        var thingsSeen: [String] = []
        var thingsHeard: [String] = []
        var thingsFelt: [String] = []
    }
    
    @Model final class DetoxLog {
        var id: UUID = UUID()
        var date: Date = Date()
        // No endDate in V1!
        var isClean: Bool = true
        var isPartial: Bool = false
        var failReason: String? = nil
        var failNotes: String? = nil
        var isRescued: Bool = false
        var sosCount: Int = 0
        var silenceTolerance: Int? = 3
        var relapseDuration: String? = nil
        var sosTimes: [Date]? = []
        var profileId: UUID? = nil
    }
    
    @Model final class PastStreak {
        var id: UUID = UUID()
        var startDate: Date = Date()
        var endDate: Date = Date()
        var failReason: String? = nil
        var failNotes: String? = nil
        var profileId: UUID? = nil
    }
    
    @Model final class DetoxProfile {
        var id: UUID = UUID()
        var name: String = ""
        var icon: String = ""
        var creationDate: Date = Date()
        var detoxHabits: [String] = []
        var currentStreakDays: Int = 0
        var longestStreakDays: Int = 0
        var lastCheckInDate: Date? = nil
        var streakStartDate: Date? = nil
        var streakStartBoundaryHour: Int? = nil
        var streakSavedToday: Bool = false
        var streakQuestsCompleted: Int = 0
    }
}

enum MyFocusSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [MyFocus.FocusSession.self, MyFocus.UserProgress.self, MyFocus.BreakActivity.self, MyFocus.MindfulnessSession.self, MyFocus.DetoxLog.self, MyFocus.PastStreak.self, MyFocus.DetoxProfile.self]
    }
}

enum MyFocusMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [MyFocusSchemaV1.self, MyFocusSchemaV2.self]
    }
    
    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }
    
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: MyFocusSchemaV1.self,
        toVersion: MyFocusSchemaV2.self
    )
}
"""

with open("MyFocus/App/MyFocusApp.swift", "a") as f:
    f.write("\n" + code)
