import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    /// Requests notification permissions from the user
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Schedules reminders.
    /// `lastCheckInDate` is the date of the user's last successful check-in (usually today).
    func scheduleReminders(lastCheckInDate: Date) {
        // First, clear any existing reminders
        cancelAllNotifications()
        
        let calendar = Calendar.current
        
        // 1. Evening Check-In Reminder (for tomorrow evening at custom time)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: lastCheckInDate) else { return }
        let tomorrowStr = formatter.string(from: tomorrow)
        
        let overrideEveningDate = UserDefaults.shared.string(forKey: "overrideEveningDate") ?? ""
        let isEveningOverride = (overrideEveningDate == tomorrowStr)
        
        let hour = isEveningOverride ? UserDefaults.shared.integer(forKey: "overrideEveningHour") : (UserDefaults.shared.object(forKey: "notificationHour") as? Int ?? 21)
        let minute = isEveningOverride ? UserDefaults.shared.integer(forKey: "overrideEveningMinute") : (UserDefaults.shared.object(forKey: "notificationMinute") as? Int ?? 0)
        
        scheduleNotification(
            id: "detox_evening_reminder",
            title: "Время чек-ина 🌿",
            body: "Проверь свои цели детокса за сегодня! Зайди и отметь свой успех.",
            at: tomorrow,
            hour: hour,
            minute: minute
        )
        
        // 2. Morning Nag Notifications (for the day after tomorrow)
        // If they missed yesterday's check-in (which was scheduled for the evening before), we nag them frequently.
        guard let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: lastCheckInDate) else { return }
        let dayAfterTomorrowStr = formatter.string(from: dayAfterTomorrow)
        
        let overrideMorningDate = UserDefaults.shared.string(forKey: "overrideMorningDate") ?? ""
        let isMorningOverride = (overrideMorningDate == dayAfterTomorrowStr)
        
        let mHour = isMorningOverride ? UserDefaults.shared.integer(forKey: "overrideMorningHour") : (UserDefaults.shared.object(forKey: "morningNotificationHour") as? Int ?? 9)
        let mMinute = isMorningOverride ? UserDefaults.shared.integer(forKey: "overrideMorningMinute") : (UserDefaults.shared.object(forKey: "morningNotificationMinute") as? Int ?? 0)
        
        // Nag 1 (Base time)
        scheduleNotification(
            id: "detox_morning_nag_0",
            title: "Стрик под угрозой! ⚠️",
            body: "Ты вчера не отметился! Открой приложение прямо сейчас, чтобы спасти стрик.",
            at: dayAfterTomorrow,
            hour: mHour,
            minute: mMinute
        )
        
        // Loop to schedule frequent nags every 5 minutes (e.g., for 2 hours -> 24 notifications)
        let baseTime = calendar.date(bySettingHour: mHour, minute: mMinute, second: 0, of: dayAfterTomorrow)!
        for i in 1...24 {
            let offsetMinutes = i * 5
            if let nagTime = calendar.date(byAdding: .minute, value: offsetMinutes, to: baseTime) {
                let nagHour = calendar.component(.hour, from: nagTime)
                let nagMinute = calendar.component(.minute, from: nagTime)
                
                let title = (i % 2 == 0) ? "Не сдавайся! 🔥" : "Последнее предупреждение! 🚨"
                let body = (i % 2 == 0) ? "Даже если был срыв — зайди и начни Квест Спасения. Стрик можно восстановить!" : "Твой стрик сгорит полностью, если ты не сделаешь отчет. Открой приложение прямо сейчас!"
                
                scheduleNotification(
                    id: "detox_morning_nag_\(i)",
                    title: title,
                    body: body,
                    at: dayAfterTomorrow,
                    hour: nagHour,
                    minute: nagMinute
                )
            }
        }
    }
    
    /// Cancels all scheduled local notifications
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    private func scheduleNotification(id: String, title: String, body: String, at date: Date, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification \(id): \(error.localizedDescription)")
            }
        }
    }
}
