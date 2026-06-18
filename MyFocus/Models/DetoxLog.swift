import Foundation
import SwiftData

@Model
final class DetoxLog {
    var id: UUID
    var date: Date
    var isClean: Bool
    var isPartial: Bool
    var failReason: String?
    var failNotes: String?
    var isRescued: Bool
    var sosCount: Int
    var silenceTolerance: Int?
    var relapseDuration: String?
    var sosTimes: [Date]? = []
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        isClean: Bool = true,
        isPartial: Bool = false,
        failReason: String? = nil,
        failNotes: String? = nil,
        isRescued: Bool = false,
        sosCount: Int = 0,
        silenceTolerance: Int? = 3,
        relapseDuration: String? = nil,
        sosTimes: [Date]? = []
    ) {
        self.id = id
        self.date = date
        self.isClean = isClean
        self.isPartial = isPartial
        self.failReason = failReason
        self.failNotes = failNotes
        self.isRescued = isRescued
        self.sosCount = sosCount
        self.silenceTolerance = silenceTolerance
        self.relapseDuration = relapseDuration
        self.sosTimes = sosTimes
    }
}
