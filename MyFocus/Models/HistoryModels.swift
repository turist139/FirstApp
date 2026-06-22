import Foundation

struct StreakHistoryItem: Identifiable {
    let id = UUID()
    let length: Int
    let duration: TimeInterval?
    let startDate: Date
    let endDate: Date?
    let reason: String
    let notes: String?
}

struct RelapseHistoryItem: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date?
    let duration: TimeInterval
    let reason: String
    let notes: String?
}
