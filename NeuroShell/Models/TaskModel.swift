import Combine
import Foundation
import SwiftUI

// MARK: - Task Chunk Model
struct TaskChunk: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var description: String
    var command: String
    var isCompleted: Bool
    var estimatedMinutes: Int
    var difficulty: Difficulty
    var orderIndex: Int

    enum Difficulty: String, Codable, CaseIterable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"

        var color: Color {
            switch self {
            case .easy: return .green
            case .medium: return .orange
            case .hard: return .red
            }
        }

        var emoji: String {
            switch self {
            case .easy: return "🟢"
            case .medium: return "🟡"
            case .hard: return "🔴"
            }
        }
    }

    init(title: String, description: String, command: String, estimatedMinutes: Int = 5, difficulty: Difficulty = .easy, orderIndex: Int = 0) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.command = command
        self.isCompleted = false
        self.estimatedMinutes = estimatedMinutes
        self.difficulty = difficulty
        self.orderIndex = orderIndex
    }
}

// MARK: - Task Session
struct TaskSession: Identifiable, Codable {
    let id: UUID
    var name: String
    var chunks: [TaskChunk]
    var createdAt: Date
    var lastAccessedAt: Date
    var isActive: Bool

    init(name: String, chunks: [TaskChunk] = []) {
        self.id = UUID()
        self.name = name
        self.chunks = chunks
        self.createdAt = Date()
        self.lastAccessedAt = Date()
        self.isActive = true
    }

    var progress: Double {
        guard !chunks.isEmpty else { return 0 }
        return Double(chunks.filter { $0.isCompleted }.count) / Double(chunks.count)
    }

    var totalEstimatedMinutes: Int {
        chunks.reduce(0) { $0 + $1.estimatedMinutes }
    }

    var completedChunks: Int {
        chunks.filter { $0.isCompleted }.count
    }

    var nextChunk: TaskChunk? {
        chunks.sorted(by: { $0.orderIndex < $1.orderIndex }).first(where: { !$0.isCompleted })
    }
}

// MARK: - Terminal Output Line
struct TerminalLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: LineType
    let timestamp: Date

    enum LineType: Equatable {
        case input
        case output
        case error
        case system
        case suggestion
        case celebration
        case rainbow
    }

    /// Seed value used for consistent rainbow color offset per line (lolcat effect)
    let rainbowSeed: Double

    init(_ text: String, type: LineType = .output, rainbowSeed: Double? = nil) {
        self.text = text
        self.type = type
        self.timestamp = Date()
        self.rainbowSeed = rainbowSeed ?? Double.random(in: 0..<1)
    }
}

// MARK: - Command History Entry
struct CommandHistoryEntry: Identifiable, Codable {
    let id: UUID
    let command: String
    let timestamp: Date
    let wasSuccessful: Bool
    let category: String

    init(command: String, wasSuccessful: Bool = true, category: String = "general") {
        self.id = UUID()
        self.command = command
        self.timestamp = Date()
        self.wasSuccessful = wasSuccessful
        self.category = category
    }
}

// MARK: - Gentle Reminder
struct GentleReminder: Identifiable {
    let id = UUID()
    let message: String
    let type: ReminderType
    let timestamp: Date
    var isDismissed: Bool = false

    enum ReminderType {
        case timeCheck
        case hydration
        case posture
        case breakSuggestion
        case encouragement
        case hyperfocusWarning
        case taskSwitch

        var icon: String {
            switch self {
            case .timeCheck: return "clock.fill"
            case .hydration: return "drop.fill"
            case .posture: return "figure.stand"
            case .breakSuggestion: return "cup.and.saucer.fill"
            case .encouragement: return "heart.fill"
            case .hyperfocusWarning: return "exclamationmark.triangle.fill"
            case .taskSwitch: return "arrow.triangle.2.circlepath"
            }
        }

        var color: Color {
            switch self {
            case .timeCheck: return .blue
            case .hydration: return .cyan
            case .posture: return .purple
            case .breakSuggestion: return .green
            case .encouragement: return .pink
            case .hyperfocusWarning: return .orange
            case .taskSwitch: return .yellow
            }
        }
    }

    init(message: String, type: ReminderType) {
        self.message = message
        self.type = type
        self.timestamp = Date()
    }
}

// MARK: - User Preferences
class UserPreferences: ObservableObject, Codable {
    @Published var hyperfocusLimitMinutes: Int = 45
    @Published var breakDurationMinutes: Int = 10
    @Published var enableTimeAlerts: Bool = true
    @Published var enableHydrationReminders: Bool = true
    @Published var enablePostureReminders: Bool = true
    @Published var enableEncouragement: Bool = true
    @Published var enableSoundEffects: Bool = true
    @Published var terminalFontSize: CGFloat = 14
    @Published var reducedMotion: Bool = false
    @Published var highContrastMode: Bool = false
    @Published var reminderIntervalMinutes: Int = 20
    @Published var showCommandExplanations: Bool = true
    @Published var autoChunkComplexCommands: Bool = true
    @Published var maxWorkingMemoryItems: Int = 3

    enum CodingKeys: String, CodingKey {
        case hyperfocusLimitMinutes, breakDurationMinutes, enableTimeAlerts
        case enableHydrationReminders, enablePostureReminders, enableEncouragement
        case enableSoundEffects, terminalFontSize, reducedMotion, highContrastMode
        case reminderIntervalMinutes, showCommandExplanations, autoChunkComplexCommands
        case maxWorkingMemoryItems
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hyperfocusLimitMinutes = try container.decodeIfPresent(Int.self, forKey: .hyperfocusLimitMinutes) ?? 45
        breakDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .breakDurationMinutes) ?? 10
        enableTimeAlerts = try container.decodeIfPresent(Bool.self, forKey: .enableTimeAlerts) ?? true
        enableHydrationReminders = try container.decodeIfPresent(Bool.self, forKey: .enableHydrationReminders) ?? true
        enablePostureReminders = try container.decodeIfPresent(Bool.self, forKey: .enablePostureReminders) ?? true
        enableEncouragement = try container.decodeIfPresent(Bool.self, forKey: .enableEncouragement) ?? true
        enableSoundEffects = try container.decodeIfPresent(Bool.self, forKey: .enableSoundEffects) ?? true
        terminalFontSize = try container.decodeIfPresent(CGFloat.self, forKey: .terminalFontSize) ?? 14
        reducedMotion = try container.decodeIfPresent(Bool.self, forKey: .reducedMotion) ?? false
        highContrastMode = try container.decodeIfPresent(Bool.self, forKey: .highContrastMode) ?? false
        reminderIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .reminderIntervalMinutes) ?? 20
        showCommandExplanations = try container.decodeIfPresent(Bool.self, forKey: .showCommandExplanations) ?? true
        autoChunkComplexCommands = try container.decodeIfPresent(Bool.self, forKey: .autoChunkComplexCommands) ?? true
        maxWorkingMemoryItems = try container.decodeIfPresent(Int.self, forKey: .maxWorkingMemoryItems) ?? 3
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hyperfocusLimitMinutes, forKey: .hyperfocusLimitMinutes)
        try container.encode(breakDurationMinutes, forKey: .breakDurationMinutes)
        try container.encode(enableTimeAlerts, forKey: .enableTimeAlerts)
        try container.encode(enableHydrationReminders, forKey: .enableHydrationReminders)
        try container.encode(enablePostureReminders, forKey: .enablePostureReminders)
        try container.encode(enableEncouragement, forKey: .enableEncouragement)
        try container.encode(enableSoundEffects, forKey: .enableSoundEffects)
        try container.encode(terminalFontSize, forKey: .terminalFontSize)
        try container.encode(reducedMotion, forKey: .reducedMotion)
        try container.encode(highContrastMode, forKey: .highContrastMode)
        try container.encode(reminderIntervalMinutes, forKey: .reminderIntervalMinutes)
        try container.encode(showCommandExplanations, forKey: .showCommandExplanations)
        try container.encode(autoChunkComplexCommands, forKey: .autoChunkComplexCommands)
        try container.encode(maxWorkingMemoryItems, forKey: .maxWorkingMemoryItems)
    }
}
