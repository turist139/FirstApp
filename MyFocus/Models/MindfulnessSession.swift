import Foundation
import SwiftData

@Model
final class MindfulnessSession {
    var id: UUID
    var date: Date
    var thingsSeen: [String]
    var thingsHeard: [String]
    var thingsFelt: [String]
    
    init(id: UUID = UUID(), date: Date = Date(), thingsSeen: [String], thingsHeard: [String], thingsFelt: [String]) {
        self.id = id
        self.date = date
        self.thingsSeen = thingsSeen
        self.thingsHeard = thingsHeard
        self.thingsFelt = thingsFelt
    }
}
