import Foundation
import SwiftUI

// MARK: - App State
/// Central state management for the application
@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .terminal
    @Published var currentSession: TaskSession?
    @Published var sessions: [TaskSession] = []
    @Published var commandHistory: [CommandHistoryEntry] = []
    @Published var activeReminders: [GentleReminder] = []
    @Published var showBreathingExercise: Bool = false
    @Published var showSettings: Bool = false
    @Published var focusModeEnabled: Bool = false
    @Published var currentMood: Mood = .neutral
    
    @Published var preferences = UserPreferences()
    
    enum AppTab: String, CaseIterable, Identifiable {
        case terminal = "Terminal"
        case taskChunker = "Tasks"
        case quickActions = "Actions"
        case soundMixer = "Sounds"
        case timer = "Timer"
        case breathing = "Breathe"
        case settings = "Settings"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .terminal: return "terminal"
            case .taskChunker: return "list.bullet.rectangle"
            case .quickActions: return "bolt.fill"
            case .soundMixer: return "waveform"
            case .timer: return "timer"
            case .breathing: return "wind"
            case .settings: return "gearshape"
            }
        }
        
        var color: Color {
            switch self {
            case .terminal: return .green
            case .taskChunker: return .blue
            case .quickActions: return .orange
            case .soundMixer: return .teal
            case .timer: return .purple
            case .breathing: return .cyan
            case .settings: return .gray
            }
        }
    }
    
    enum Mood: String, CaseIterable {
        case great = "Feeling great!"
        case good = "Doing okay"
        case neutral = "Meh"
        case struggling = "Struggling a bit"
        case overwhelmed = "Overwhelmed"
        
        var emoji: String {
            switch self {
            case .great: return "😊"
            case .good: return "🙂"
            case .neutral: return "😐"
            case .struggling: return "😔"
            case .overwhelmed: return "😰"
            }
        }
        
        var supportMessage: String {
            switch self {
            case .great: return "Awesome! Let's make the most of this energy!"
            case .good: return "Nice! Remember to keep up the momentum gently."
            case .neutral: return "That's perfectly fine. Let's take it one step at a time."
            case .struggling: return "Hey, it's okay. Let's start with something small and easy."
            case .overwhelmed: return "Take a breath. You don't have to do everything right now. Let's just do ONE tiny thing."
            }
        }
    }
    
    // MARK: - Session Management
    func createSession(name: String, chunks: [TaskChunk]) {
        let session = TaskSession(name: name, chunks: chunks)
        sessions.insert(session, at: 0)
        currentSession = session
    }
    
    func completeChunk(_ chunk: TaskChunk) {
        guard var session = currentSession,
              let index = session.chunks.firstIndex(where: { $0.id == chunk.id }) else { return }
        
        session.chunks[index].isCompleted = true
        currentSession = session
        
        if let sessionIndex = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[sessionIndex] = session
        }
        
        // Celebration!
        if session.progress == 1.0 {
            addReminder(GentleReminder(
                message: "🎉🎊 You completed ALL the steps in '\(session.name)'! That's incredible! Take a moment to appreciate what you just accomplished.",
                type: .encouragement
            ))
        }
    }
    
    // MARK: - Reminder Management
    func addReminder(_ reminder: GentleReminder) {
        activeReminders.insert(reminder, at: 0)
        // Keep only last 10 reminders
        if activeReminders.count > 10 {
            activeReminders = Array(activeReminders.prefix(10))
        }
    }
    
    func dismissReminder(_ reminder: GentleReminder) {
        activeReminders.removeAll { $0.id == reminder.id }
    }
    
    func dismissAllReminders() {
        activeReminders.removeAll()
    }
    
    // MARK: - History Management
    func addToHistory(_ command: String, wasSuccessful: Bool = true) {
        let entry = CommandHistoryEntry(command: command, wasSuccessful: wasSuccessful)
        commandHistory.insert(entry, at: 0)
        if commandHistory.count > 100 {
            commandHistory = Array(commandHistory.prefix(100))
        }
    }
}
