import Foundation
import SwiftData

@Model
final class BreakActivity {
    var id: UUID
    var name: String
    var isCustom: Bool
    
    init(id: UUID = UUID(), name: String, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.isCustom = isCustom
    }
}
