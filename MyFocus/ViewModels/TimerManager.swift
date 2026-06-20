import Foundation
import Combine
@preconcurrency import UserNotifications
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class TimerManager: ObservableObject {
    @Published var selectedMinutes: Int = 25
    @Published var isFocusing: Bool = false
    @Published var timeRemaining: Int = 0
    @Published var showEvaluation: Bool = false
    
    private var timer: Timer?
    private var targetEndDate: Date?
    
    func updateFromBackground() {
        guard isFocusing, let targetDate = targetEndDate else { return }
        
        let remaining = Int(targetDate.timeIntervalSince(Date()))
        if remaining > 0 {
            timeRemaining = remaining
        } else {
            timeRemaining = 0
            finishFocus()
        }
    }
    
    func startFocus() {
        isFocusing = true
        timeRemaining = selectedMinutes * 60
        targetEndDate = Date().addingTimeInterval(TimeInterval(timeRemaining))
        
        scheduleNotification()
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    private func tick() {
        guard isFocusing else { return }
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            finishFocus()
        }
    }
    
    private func finishFocus() {
        timer?.invalidate()
        timer = nil
        isFocusing = false
        targetEndDate = nil
        
        playCompletionSound()
        showEvaluation = true
    }
    
    func cancelFocus() {
        timer?.invalidate()
        timer = nil
        isFocusing = false
        targetEndDate = nil
        timeRemaining = 0
        
        cancelNotification()
    }
    
    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()
        let targetDate = self.targetEndDate
        
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = "Фокус завершен!"
            content.body = "Отличная работа. Пора сделать перерыв."
            content.sound = .default
            
            if let targetDate = targetDate {
                let timeInterval = targetDate.timeIntervalSince(Date())
                guard timeInterval > 0 else { return }
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
                let request = UNNotificationRequest(identifier: "focus_timer_complete", content: content, trigger: trigger)
                
                center.add(request) { error in
                    if let error = error {
                        print("Error scheduling notification: \(error)")
                    }
                }
            }
        }
    }
    
    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["focus_timer_complete"])
    }
    
    private func playCompletionSound() {
        #if targetEnvironment(macCatalyst)
        if let url = URL(string: "file:///System/Library/Sounds/Glass.aiff") {
            var soundId: SystemSoundID = 0
            AudioServicesCreateSystemSoundID(url as CFURL, &soundId)
            AudioServicesPlaySystemSound(soundId)
        }
        #elseif canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        AudioServicesPlaySystemSound(1057)
        #endif
    }
}
