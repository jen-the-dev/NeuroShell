import Foundation

// MARK: - Output Parser Service
/// Parses terminal output and provides ADHD-friendly explanations
class OutputParserService {
    
    struct ParsedOutput {
        let originalText: String
        let simplifiedExplanation: String
        let actionItems: [String]
        let severity: Severity
        
        enum Severity {
            case info
            case success
            case warning
            case error
            
            var emoji: String {
                switch self {
                case .info: return "ℹ️"
                case .success: return "✅"
                case .warning: return "⚠️"
                case .error: return "❌"
                }
            }
        }
    }
    
    // MARK: - Error Parsing
    static func parseError(_ errorText: String) -> ParsedOutput {
        let lowered = errorText.lowercased()
        
        // Permission denied
        if lowered.contains("permission denied") {
            return ParsedOutput(
                originalText: errorText,
                simplifiedExplanation: "You don't have permission to do this. It's like trying to open a locked door — you need the key (admin access).",
                actionItems: [
                    "Try adding 'sudo' before your command (you'll need your password)",
                    "Check if you own the file with 'ls -la filename'",
                    "Ask: do you actually need to modify this file?"
                ],
                severity: .error
            )
        }
        
        // Command not found
        if lowered.contains("command not found") || lowered.contains("not recognized") {
            let command = extractCommandName(from: errorText)
            return ParsedOutput(
                originalText: errorText,
                simplifiedExplanation: "The command '\(command)' isn't installed on your computer. It's like trying to use an app that isn't downloaded yet.",
                actionItems: [
                    "Check for typos in the command name",
                    "Try installing it with 'brew install \(command)'",
                    "Use 'which \(command)' to check if it's installed somewhere else"
                ],
                severity: .error
            )
        }
        
        // No such file or directory
        if lowered.contains("no such file or directory") {
            return ParsedOutput(
                originalText: errorText,
                simplifiedExplanation: "The file or folder you're looking for doesn't exist at that location. It might be somewhere else, or spelled differently.",
                actionItems: [
                    "Check the spelling of the file/folder name",
                    "Use 'ls' to see what IS in the current directory",
                    "Use 'find . -name \"filename\"' to search for it",
                    "Check if you're in the right directory with 'pwd'"
                ],
                severity: .error
            )
        }
        
        // Git conflicts
        if lowered.contains("merge conflict") || lowered.contains("conflict") {
            return ParsedOutput(
                originalText: errorText,
                simplifiedExplanation: "Two different versions of the same file have conflicting changes. Think of it like two people editing the same paragraph differently — you need to choose which version to keep.",
                actionItems: [
                    "Don't panic! This is normal and fixable",
                    "Open the conflicting files and look for <<<< and >>>> markers",
                    "Choose which version to keep (or combine them)",
                    "After fixing, run 'git add .' then 'git commit'"
                ],
                severity: .warning
            )
        }
        
        // Disk space
        if lowered.contains("no space left") || lowered.contains("disk full") {
            return ParsedOutput(
                originalText: errorText,
                simplifiedExplanation: "Your disk is full! Like a closet that's overflowing — you need to make room.",
                actionItems: [
                    "Check disk usage with 'df -h'",
                    "Find large files with 'du -sh * | sort -h'",
                    "Empty the trash",
                    "Clear old downloads or temporary files"
                ],
                severity: .error
            )
        }
        
        // Connection errors
        if lowered.contains("connection refused") || lowered.contains("could not resolve") || lowered.contains("network") {
            return ParsedOutput(
                originalText: errorText,
                simplifiedExplanation: "Can't connect to the internet or a server. Like trying to call someone when there's no signal.",
                actionItems: [
                    "Check your internet connection",
                    "Try 'ping google.com' to test connectivity",
                    "The server might be down — wait a moment and try again",
                    "Check if you need a VPN"
                ],
                severity: .error
            )
        }
        
        // Syntax errors
        if lowered.contains("syntax error") || lowered.contains("unexpected token") {
            return ParsedOutput(
                originalText: errorText,
                simplifiedExplanation: "There's a typo or formatting issue in the command. Like a sentence with missing punctuation — the computer can't understand it.",
                actionItems: [
                    "Check for missing quotes, brackets, or parentheses",
                    "Make sure spaces are in the right places",
                    "Try the command in smaller pieces"
                ],
                severity: .error
            )
        }
        
        // Default
        return ParsedOutput(
            originalText: errorText,
            simplifiedExplanation: "Something went wrong, but that's okay — errors are just the computer asking for help.",
            actionItems: [
                "Read the error message above carefully",
                "Try searching the error message online",
                "Break the command into smaller parts and try each one"
            ],
            severity: .error
        )
    }
    
    // MARK: - Helper
    private static func extractCommandName(from error: String) -> String {
        // Try to extract the command name from "command not found" errors
        let parts = error.components(separatedBy: ":")
        if let first = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) {
            let words = first.components(separatedBy: " ")
            if let cmd = words.last {
                return cmd
            }
        }
        return "unknown"
    }
    
    // MARK: - Success Messages
    static func celebrateSuccess(for command: String) -> String {
        let celebrations = [
            "🎉 Nice work! That ran perfectly!",
            "✨ Smooth! Command completed successfully!",
            "💪 You're on a roll!",
            "🌟 Look at you, making things happen!",
            "🎯 Nailed it!",
            "🚀 That worked great!",
            "👏 Well done! One more thing checked off!",
        ]
        return celebrations.randomElement() ?? celebrations[0]
    }
}
