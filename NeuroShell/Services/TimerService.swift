import Combine
import Foundation
import SwiftUI
import UserNotifications

// MARK: - Timer Service
/// Manages time-blindness alerts, work/break intervals, and session tracking
@MainActor
class TimerService: ObservableObject {
    @Published var sessionStartTime: Date = Date()
    @Published var elapsedMinutes: Int = 0
    @Published var isOnBreak: Bool = false
    @Published var breakTimeRemaining: Int = 0
    @Published var currentPhase: WorkPhase = .working
    @Published var totalSessionMinutes: Int = 0
    @Published var lastReminderTime: Date = Date()
    @Published var showTimeAlert: Bool = false
    @Published var timeAlertMessage: String = ""
    
    private var timer: Timer?
    private var breakTimer: Timer?
    
    enum WorkPhase: String {
        case working = "Working"
        case breakTime = "Break Time"
        case paused = "Paused"
        
        var icon: String {
            switch self {
            case .working: return "laptopcomputer"
            case .breakTime: return "cup.and.saucer.fill"
            case .paused: return "pause.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .working: return .green
            case .breakTime: return .blue
            case .paused: return .gray
            }
        }
    }
    
    init() {
        requestNotificationPermission()
        startSessionTimer()
    }
    
    deinit {
        timer?.invalidate()
        breakTimer?.invalidate()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    // MARK: - Session Timer
    func startSessionTimer() {
        sessionStartTime = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }
    
    private func tick() {
        elapsedMinutes += 1
        totalSessionMinutes += 1
        
        // Time-blindness alerts at various intervals
        checkTimeAlerts()
    }
    
    private func checkTimeAlerts() {
        // Every 15 minutes - gentle time check
        if elapsedMinutes % 15 == 0 && elapsedMinutes > 0 {
            let messages = [
                "⏰ Hey! It's been \(elapsedMinutes) minutes. Just a friendly check-in!",
                "🕐 Time check: \(elapsedMinutes) minutes have passed. You're doing great!",
                "⏱️ \(elapsedMinutes) minutes into your session. How are you feeling?",
            ]
            showTimeNotification(messages.randomElement() ?? messages[0])
        }
        
        // Every 30 minutes - hydration reminder
        if elapsedMinutes % 30 == 0 && elapsedMinutes > 0 {
            showTimeNotification("💧 \(elapsedMinutes) minutes in — have you had some water?")
        }
        
        // Every 45 minutes - break suggestion
        if elapsedMinutes % 45 == 0 && elapsedMinutes > 0 {
            showTimeNotification("🧘 You've been going for \(elapsedMinutes) minutes. Your brain might appreciate a short break!")
        }
        
        // Every 60 minutes - posture check
        if elapsedMinutes % 60 == 0 && elapsedMinutes > 0 {
            showTimeNotification("🪑 One hour mark! How's your posture? Try rolling your shoulders back.")
        }
    }
    
    private func showTimeNotification(_ message: String) {
        timeAlertMessage = message
        showTimeAlert = true
        lastReminderTime = Date()
        
        // Also send system notification
        sendSystemNotification(message)
    }
    
    private func sendSystemNotification(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "NeuroShell"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Break Management
    func startBreak(minutes: Int = 10) {
        isOnBreak = true
        currentPhase = .breakTime
        breakTimeRemaining = minutes * 60
        elapsedMinutes = 0
        
        breakTimer?.invalidate()
        breakTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.breakTick()
            }
        }
        
        showTimeNotification("☕ Break time! \(minutes) minutes to recharge. You've earned it!")
    }
    
    private func breakTick() {
        if breakTimeRemaining > 0 {
            breakTimeRemaining -= 1
        } else {
            endBreak()
        }
    }
    
    func endBreak() {
        isOnBreak = false
        currentPhase = .working
        breakTimer?.invalidate()
        breakTimeRemaining = 0
        sessionStartTime = Date()
        
        let messages = [
            "🌟 Welcome back! Ready to continue? No pressure.",
            "💪 Break's over! Let's ease back into it.",
            "🧠 Refreshed? Remember, start with the smallest step.",
        ]
        showTimeNotification(messages.randomElement() ?? messages[0])
    }
    
    func pauseSession() {
        currentPhase = .paused
        timer?.invalidate()
    }
    
    func resumeSession() {
        currentPhase = .working
        startSessionTimer()
    }
    
    func resetSession() {
        elapsedMinutes = 0
        totalSessionMinutes = 0
        sessionStartTime = Date()
        currentPhase = .working
    }
    
    // MARK: - Formatted Time
    var formattedElapsed: String {
        let hours = elapsedMinutes / 60
        let mins = elapsedMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
    
    var formattedBreakRemaining: String {
        let mins = breakTimeRemaining / 60
        let secs = breakTimeRemaining % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    var formattedTotalSession: String {
        let hours = totalSessionMinutes / 60
        let mins = totalSessionMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
    
    func dismissTimeAlert() {
        showTimeAlert = false
    }
}
