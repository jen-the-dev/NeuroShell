import Combine
import Foundation
import SwiftUI

// MARK: - Context Memory Manager
/// Manages working memory context to reduce cognitive load
/// Tracks what the user was doing, where they were, and what they might need next
class ContextMemory: ObservableObject {
    @Published var breadcrumbs: [BreadcrumbItem] = []
    @Published var currentWorkingDirectory: String = "~"
    @Published var recentCommands: [String] = []
    @Published var currentGoal: String = ""
    @Published var contextNotes: [ContextNote] = []
    @Published var workingMemorySlots: [MemorySlot] = []
    
    private let maxBreadcrumbs = 10
    private let maxRecentCommands = 20
    private let maxMemorySlots = 5
    
    struct BreadcrumbItem: Identifiable {
        let id = UUID()
        let label: String
        let directory: String
        let timestamp: Date
        let icon: String
        
        init(label: String, directory: String, icon: String = "folder") {
            self.label = label
            self.directory = directory
            self.icon = icon
            self.timestamp = Date()
        }
    }
    
    struct ContextNote: Identifiable, Codable {
        let id: UUID
        var text: String
        let createdAt: Date
        var isPinned: Bool
        
        init(text: String, isPinned: Bool = false) {
            self.id = UUID()
            self.text = text
            self.createdAt = Date()
            self.isPinned = isPinned
        }
    }
    
    struct MemorySlot: Identifiable {
        let id = UUID()
        var label: String
        var value: String
        var category: SlotCategory
        let createdAt: Date
        
        enum SlotCategory: String, CaseIterable {
            case variable = "Variable"
            case path = "Path"
            case command = "Command"
            case note = "Note"
            
            var icon: String {
                switch self {
                case .variable: return "x.squareroot"
                case .path: return "folder"
                case .command: return "terminal"
                case .note: return "note.text"
                }
            }
            
            var color: Color {
                switch self {
                case .variable: return .purple
                case .path: return .blue
                case .command: return .green
                case .note: return .orange
                }
            }
        }
        
        init(label: String, value: String, category: SlotCategory) {
            self.label = label
            self.value = value
            self.category = category
            self.createdAt = Date()
        }
    }
    
    // MARK: - Breadcrumb Management
    func addBreadcrumb(_ label: String, directory: String, icon: String = "folder") {
        let crumb = BreadcrumbItem(label: label, directory: directory, icon: icon)
        breadcrumbs.insert(crumb, at: 0)
        if breadcrumbs.count > maxBreadcrumbs {
            breadcrumbs = Array(breadcrumbs.prefix(maxBreadcrumbs))
        }
    }
    
    func addCommand(_ command: String) {
        recentCommands.insert(command, at: 0)
        if recentCommands.count > maxRecentCommands {
            recentCommands = Array(recentCommands.prefix(maxRecentCommands))
        }
    }
    
    // MARK: - Memory Slot Management
    func addMemorySlot(label: String, value: String, category: MemorySlot.SlotCategory) {
        let slot = MemorySlot(label: label, value: value, category: category)
        workingMemorySlots.insert(slot, at: 0)
        if workingMemorySlots.count > maxMemorySlots {
            workingMemorySlots = Array(workingMemorySlots.prefix(maxMemorySlots))
        }
    }
    
    func removeMemorySlot(_ slot: MemorySlot) {
        workingMemorySlots.removeAll { $0.id == slot.id }
    }
    
    // MARK: - Context Notes
    func addNote(_ text: String, pinned: Bool = false) {
        let note = ContextNote(text: text, isPinned: pinned)
        contextNotes.insert(note, at: 0)
    }
    
    func removeNote(_ note: ContextNote) {
        contextNotes.removeAll { $0.id == note.id }
    }
    
    func toggleNotePin(_ note: ContextNote) {
        if let index = contextNotes.firstIndex(where: { $0.id == note.id }) {
            contextNotes[index].isPinned.toggle()
        }
    }
    
    // MARK: - Context Summary
    var contextSummary: String {
        var parts: [String] = []
        if !currentGoal.isEmpty {
            parts.append("Goal: \(currentGoal)")
        }
        parts.append("Directory: \(currentWorkingDirectory)")
        if let lastCmd = recentCommands.first {
            parts.append("Last command: \(lastCmd)")
        }
        return parts.joined(separator: " | ")
    }
    
    /// Returns a "where was I?" summary for when the user loses context
    func whereWasI() -> String {
        var summary = "📍 Here's where you are:\n\n"
        summary += "📂 Current directory: \(currentWorkingDirectory)\n"
        
        if !currentGoal.isEmpty {
            summary += "🎯 Your current goal: \(currentGoal)\n"
        }
        
        if !recentCommands.isEmpty {
            summary += "\n📜 Your last few commands:\n"
            for (i, cmd) in recentCommands.prefix(3).enumerated() {
                summary += "  \(i + 1). \(cmd)\n"
            }
        }
        
        let pinnedNotes = contextNotes.filter { $0.isPinned }
        if !pinnedNotes.isEmpty {
            summary += "\n📌 Your pinned notes:\n"
            for note in pinnedNotes {
                summary += "  • \(note.text)\n"
            }
        }
        
        if !workingMemorySlots.isEmpty {
            summary += "\n🧠 Things you saved to remember:\n"
            for slot in workingMemorySlots {
                summary += "  • \(slot.label): \(slot.value)\n"
            }
        }
        
        return summary
    }
}
