import SwiftUI

struct PaletteManager {
    static let shared = PaletteManager()
    
    let allPalettes: [String] = ["default", "palette_2", "palette_3", "palette_4", "palette_5", "palette_gold", "palette_100", "palette_365"]
    
    let paletteNames: [String: String] = [
        "default": "Базовая",
        "palette_2": "Закат",
        "palette_3": "Лес",
        "palette_4": "Космос",
        "palette_5": "Пламя",
        "palette_gold": "Золото",
        "palette_100": "Изумруд",
        "palette_365": "Алмаз"
    ]
    
    let paletteColors: [String: [Color]] = [
        "default": [Color(red: 0, green: 0.5, blue: 1), Color(red: 0.5, green: 0, blue: 1), Color(red: 0, green: 1, blue: 0.5)],
        "palette_2": [Color(red: 1, green: 0.5, blue: 0), Color(red: 1, green: 0, blue: 0), Color(red: 0.5, green: 0, blue: 0.5)],
        "palette_3": [Color(red: 0, green: 0.8, blue: 0), Color(red: 0, green: 1, blue: 0.8), Color(red: 0, green: 0.5, blue: 0.5)],
        "palette_4": [Color(red: 0.5, green: 0, blue: 1), Color(red: 0.3, green: 0, blue: 0.8), Color(red: 0, green: 0, blue: 0.8)],
        "palette_5": [Color(red: 1, green: 0.8, blue: 0), Color(red: 1, green: 0.5, blue: 0), Color(red: 1, green: 0, blue: 0)],
        "palette_gold": [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 0.9, green: 0.7, blue: 0.1), Color(red: 1.0, green: 0.9, blue: 0.5)],
        "palette_100": [Color(red: 0.0, green: 0.6, blue: 0.3), Color(red: 0.0, green: 0.8, blue: 0.5), Color(red: 0.1, green: 0.5, blue: 0.4)],
        "palette_365": [Color(red: 0.85, green: 0.9, blue: 1.0), Color(red: 0.6, green: 0.8, blue: 0.95), Color(red: 0.75, green: 0.75, blue: 0.9)]
    ]
    
    func getGradientColors(for id: String) -> [Color] {
        let base = paletteColors[id] ?? paletteColors["default"]!
        return [base[0].opacity(0.9), base[1], base[2].opacity(0.9)]
    }
    
    func isPaletteUnlocked(id: String, currentStreak: Int) -> Bool {
        switch id {
        case "default": return true
        case "palette_2": return currentStreak >= 1
        case "palette_3": return currentStreak >= 3
        case "palette_4": return currentStreak >= 7
        case "palette_5": return currentStreak >= 15
        case "palette_gold": return currentStreak >= 30
        case "palette_100": return currentStreak >= 100
        case "palette_365": return currentStreak >= 365
        default: return true
        }
    }
}
