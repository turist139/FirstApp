import SwiftUI
import Combine

struct MotivationItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
}

struct MotivationCategory: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var subtitle: String
    var icon: String
    var colorHex: String // Will use this to derive UI colors
    var items: [MotivationItem]
}

class MotivationSettings: ObservableObject {
    @AppStorage("hasCompletedMotivationOnboarding", store: .shared) var hasCompletedOnboarding: Bool = false
    
    // We store the JSON representation of [MotivationCategory]
    @AppStorage("motivationCategoriesJSON", store: .shared) private var categoriesJSON: String = ""
    
    @Published var categories: [MotivationCategory] = [] {
        didSet {
            saveToStorage()
        }
    }
    
    static let shared = MotivationSettings()
    
    private init() {
        loadFromStorage()
    }
    
    private func loadFromStorage() {
        if categoriesJSON.isEmpty {
            // Setup default categories
            categories = [
                MotivationCategory(title: "Мои цели", subtitle: "Какие мои цели, к чему я стремлюсь?", icon: "target", colorHex: "00FFFF", items: []),
                MotivationCategory(title: "Что я меняю", subtitle: "Что мне не нравится в текущей жизни, что я обязательно хочу изменить?", icon: "xmark.shield.fill", colorHex: "FF3B30", items: []),
                MotivationCategory(title: "Если сдамся", subtitle: "Что будет через год, если я ничего не изменю?", icon: "exclamationmark.triangle.fill", colorHex: "FF9500", items: []),
                MotivationCategory(title: "Если выстою", subtitle: "К чему я могу прийти за год (идеальный образ будущего себя)?", icon: "star.fill", colorHex: "34C759", items: []),
                MotivationCategory(title: "День идеальной версии", subtitle: "День идеальной версии себя", icon: "sun.max.fill", colorHex: "FFD60A", items: []),
                MotivationCategory(title: "Лучшая версия меня", subtitle: "Как поступала бы лучшая версия меня в трудные моменты?", icon: "crown.fill", colorHex: "AF52DE", items: []),
                MotivationCategory(title: "Дополнительные смыслы", subtitle: "Любые другие важные мысли (свободное поле)", icon: "quote.opening", colorHex: "007AFF", items: [])
            ]
        } else {
            if let data = categoriesJSON.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([MotivationCategory].self, from: data) {
                categories = decoded
            }
        }
    }
    
    private func saveToStorage() {
        if let encoded = try? JSONEncoder().encode(categories),
           let jsonString = String(data: encoded, encoding: .utf8) {
            categoriesJSON = jsonString
        }
    }
}
