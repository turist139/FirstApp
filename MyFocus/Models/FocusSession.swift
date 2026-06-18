import Foundation
import SwiftData

@Model
final class FocusSession {
    var id: UUID
    var date: Date
    var durationMinutes: Int
    var productivityScore: Int // 1 to 5 scale
    
    init(id: UUID = UUID(), date: Date = Date(), durationMinutes: Int, productivityScore: Int) {
        self.id = id
        self.date = date
        self.durationMinutes = durationMinutes
        self.productivityScore = productivityScore
    }
}
