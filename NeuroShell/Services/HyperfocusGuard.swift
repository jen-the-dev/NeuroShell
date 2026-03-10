import Combine
import Foundation
import SwiftUI

// MARK: - Hyperfocus Guard
/// Monitors user activity patterns and alerts when hyperfocus might be counterproductive
@MainActor
class HyperfocusGuard: ObservableObject {
    @Published var commandCount: Int = 0
    @Published var commandsPerMinute: Double = 0
    @Published var isHyperfocusDetected: Bool = false
    @Published var hyperfocusLevel: HyperfocusLevel = .normal
    @Published var showWarning: Bool = false
    @Published var warningMessage: String = ""
    @Published var sessionCommands: [(command: String, timestamp: Date)] = []
    @Published var repetitivePatternDetected: Bool = false
    
    private var monitorTimer: Timer?
    private let hyperfocusThresholdMinutes: Int = 45
    private var sessionStartTime = Date()
    
    enum HyperfocusLevel: String {
        case normal = "Normal"
        case elevated = "Elevated"
        case high = "High"
        case warning = "Warning"
        
        var color: Color {
            switch self {
            case .normal: return .green
            case .elevated: return .yellow
            case .high: return .orange
            case .warning: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .normal: return "brain"
            case .elevated: return "brain"
            case .high: return "exclamationmark.brain"
            case .warning: return "exclamationmark.triangle"
            }
        }
        
        var description: String {
            switch self {
            case .normal: return "You're in a good flow state"
            case .elevated: return "Getting focused — nice!"
            case .high: return "Deep focus detected — remember to check in with yourself"
            case .warning: return "You might be hyperfocusing — consider a break"
            }
        }
    }
    
    init() {
        startMonitoring()
    }
    
    deinit {
        monitorTimer?.invalidate()
    }
    
    func startMonitoring() {
        sessionStartTime = Date()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateHyperfocusLevel()
            }
        }
    }
    
    // MARK: - Command Tracking
    func trackCommand(_ command: String) {
        commandCount += 1
        sessionCommands.append((command: command, timestamp: Date()))
        
        // Keep only last 100 commands
        if sessionCommands.count > 100 {
            sessionCommands = Array(sessionCommands.suffix(100))
        }
        
        // Check for rapid-fire commands
        checkRapidFire()
        
        // Check for repetitive patterns
        checkRepetitivePatterns()
        
        // Update commands per minute
        updateCommandRate()
    }
    
    private func checkRapidFire() {
        let recentCommands = sessionCommands.filter {
            Date().timeIntervalSince($0.timestamp) < 60
        }
        
        if recentCommands.count > 10 {
            showGentleWarning("🏃 You're typing really fast! Take a breath between commands — your brain processes better with small pauses.")
        }
    }
    
    private func checkRepetitivePatterns() {
        guard sessionCommands.count >= 3 else { return }
        
        let lastThree = sessionCommands.suffix(3).map { $0.command }
        let uniqueCommands = Set(lastThree)
        
        if uniqueCommands.count == 1 {
            repetitivePatternDetected = true
            showGentleWarning("🔄 I notice you've run '\(lastThree[0])' a few times. Are you getting the result you expected? Maybe try a different approach?")
        }
        
        // Check for error-retry loop
        let lastFive = sessionCommands.suffix(5).map { $0.command }
        if lastFive.count >= 4 {
            let unique = Set(lastFive)
            if unique.count <= 2 {
                showGentleWarning("💡 Looks like you might be stuck in a loop. It's okay! Try stepping back and breaking this into smaller pieces, or take a quick break to reset.")
            }
        }
    }
    
    private func updateCommandRate() {
        let minutesSinceStart = max(1, Date().timeIntervalSince(sessionStartTime) / 60)
        commandsPerMinute = Double(commandCount) / minutesSinceStart
    }
    
    // MARK: - Hyperfocus Evaluation
    private func evaluateHyperfocusLevel() {
        let minutesActive = Int(Date().timeIntervalSince(sessionStartTime) / 60)
        
        if minutesActive < 15 {
            hyperfocusLevel = .normal
        } else if minutesActive < 30 {
            hyperfocusLevel = commandsPerMinute > 3 ? .elevated : .normal
        } else if minutesActive < 45 {
            hyperfocusLevel = .high
            if !showWarning {
                showGentleWarning("🧠 You've been focused for \(minutesActive) minutes. That's great, but check in: Are you still working on what you intended?")
            }
        } else {
            hyperfocusLevel = .warning
            showGentleWarning("⚠️ \(minutesActive) minutes of continuous work! Your brain needs a break to process everything. Even 5 minutes helps!")
        }
        
        isHyperfocusDetected = hyperfocusLevel == .high || hyperfocusLevel == .warning
    }
    
    private func showGentleWarning(_ message: String) {
        warningMessage = message
        showWarning = true
    }
    
    func dismissWarning() {
        showWarning = false
    }
    
    func resetSession() {
        commandCount = 0
        commandsPerMinute = 0
        sessionCommands.removeAll()
        hyperfocusLevel = .normal
        isHyperfocusDetected = false
        sessionStartTime = Date()
        repetitivePatternDetected = false
    }
    
    // MARK: - Activity Summary
    var activitySummary: String {
        let minutesActive = Int(Date().timeIntervalSince(sessionStartTime) / 60)
        return "\(commandCount) commands in \(minutesActive) minutes"
    }
}
