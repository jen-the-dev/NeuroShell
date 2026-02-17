import Foundation

// MARK: - Command Suggestion Engine
/// Provides context-aware command suggestions and breaks complex commands into steps
class CommandSuggestionEngine: ObservableObject {
    @Published var suggestions: [CommandSuggestion] = []
    @Published var currentExplanation: String = ""

    struct CommandSuggestion: Identifiable, Hashable {
        let id = UUID()
        let command: String
        let description: String
        let category: Category
        let complexity: Int // 1-5

        enum Category: String, CaseIterable {
            case navigation = "Navigation"
            case files = "Files"
            case git = "Git"
            case system = "System"
            case network = "Network"
            case search = "Search"
            case permissions = "Permissions"
            case process = "Processes"

            var icon: String {
                switch self {
                case .navigation: return "arrow.right.circle"
                case .files: return "doc"
                case .git: return "arrow.triangle.branch"
                case .system: return "gearshape"
                case .network: return "network"
                case .search: return "magnifyingglass"
                case .permissions: return "lock"
                case .process: return "cpu"
                }
            }
        }
    }

    // MARK: - Contextual Suggestions
    func getSuggestions(forInput input: String, currentDir: String, recentCommands: [String]) -> [CommandSuggestion] {
        let lowered = input.lowercased()

        if lowered.isEmpty {
            return getFrequentSuggestions(recentCommands: recentCommands)
        }

        var results: [CommandSuggestion] = []

        // Natural language matching
        results.append(contentsOf: matchNaturalLanguage(lowered))

        // Command prefix matching
        results.append(contentsOf: matchCommandPrefix(lowered))

        // Context-aware suggestions
        results.append(contentsOf: getContextualSuggestions(currentDir: currentDir))

        // Deduplicate
        var seen = Set<String>()
        results = results.filter { seen.insert($0.command).inserted }

        return Array(results.prefix(6))
    }

    private func matchNaturalLanguage(_ input: String) -> [CommandSuggestion] {
        var matches: [CommandSuggestion] = []

        let naturalLanguageMap: [(keywords: [String], suggestion: CommandSuggestion)] = [
            (["list", "show", "what's here", "files", "directory contents"],
             CommandSuggestion(command: "ls -la", description: "List all files with details", category: .navigation, complexity: 1)),

            (["go to", "navigate", "change dir", "move to", "cd"],
             CommandSuggestion(command: "cd ", description: "Change directory (add path after)", category: .navigation, complexity: 1)),

            (["go back", "previous", "parent", "up"],
             CommandSuggestion(command: "cd ..", description: "Go up one directory", category: .navigation, complexity: 1)),

            (["go home", "home dir"],
             CommandSuggestion(command: "cd ~", description: "Go to your home directory", category: .navigation, complexity: 1)),

            (["find", "search", "look for", "locate"],
             CommandSuggestion(command: "find . -name \"\"", description: "Find files by name (put name in quotes)", category: .search, complexity: 2)),

            (["search inside", "grep", "find text", "search text", "look inside"],
             CommandSuggestion(command: "grep -r \"\" .", description: "Search for text in files", category: .search, complexity: 2)),

            (["create file", "new file", "make file", "touch"],
             CommandSuggestion(command: "touch ", description: "Create a new empty file", category: .files, complexity: 1)),

            (["create folder", "new folder", "make dir", "mkdir", "new directory"],
             CommandSuggestion(command: "mkdir ", description: "Create a new directory", category: .files, complexity: 1)),

            (["delete", "remove", "rm"],
             CommandSuggestion(command: "rm ", description: "Delete a file (⚠️ careful, can't undo!)", category: .files, complexity: 2)),

            (["copy", "duplicate", "cp"],
             CommandSuggestion(command: "cp ", description: "Copy a file (source → destination)", category: .files, complexity: 2)),

            (["move", "rename", "mv"],
             CommandSuggestion(command: "mv ", description: "Move or rename a file", category: .files, complexity: 2)),

            (["read", "view", "show file", "cat", "display"],
             CommandSuggestion(command: "cat ", description: "Display file contents", category: .files, complexity: 1)),

            (["edit", "open in editor", "nano", "vim"],
             CommandSuggestion(command: "nano ", description: "Edit a file in the terminal", category: .files, complexity: 2)),

            (["git status", "what changed", "changes"],
             CommandSuggestion(command: "git status", description: "See what's changed in your git repo", category: .git, complexity: 1)),

            (["git add", "stage"],
             CommandSuggestion(command: "git add .", description: "Stage all changes for commit", category: .git, complexity: 1)),

            (["commit", "save changes", "git commit"],
             CommandSuggestion(command: "git commit -m \"\"", description: "Commit staged changes (add message in quotes)", category: .git, complexity: 2)),

            (["push", "upload", "git push"],
             CommandSuggestion(command: "git push", description: "Push commits to remote", category: .git, complexity: 2)),

            (["pull", "download", "git pull", "update"],
             CommandSuggestion(command: "git pull", description: "Pull latest changes from remote", category: .git, complexity: 2)),

            (["branch", "branches", "git branch"],
             CommandSuggestion(command: "git branch", description: "List all branches", category: .git, complexity: 1)),

            (["new branch", "create branch", "checkout"],
             CommandSuggestion(command: "git checkout -b ", description: "Create and switch to a new branch", category: .git, complexity: 2)),

            (["disk", "space", "storage", "how much space"],
             CommandSuggestion(command: "df -h", description: "Show disk space usage", category: .system, complexity: 1)),

            (["size", "folder size", "how big"],
             CommandSuggestion(command: "du -sh *", description: "Show size of items in current directory", category: .system, complexity: 2)),

            (["process", "running", "what's running", "top", "activity"],
             CommandSuggestion(command: "ps aux | head -20", description: "Show running processes", category: .process, complexity: 2)),

            (["kill", "stop", "end process"],
             CommandSuggestion(command: "kill ", description: "Stop a process (add PID)", category: .process, complexity: 3)),

            (["network", "internet", "connected", "ping"],
             CommandSuggestion(command: "ping -c 3 google.com", description: "Check internet connectivity", category: .network, complexity: 1)),

            (["ip", "my ip", "address"],
             CommandSuggestion(command: "ifconfig | grep inet", description: "Show your IP addresses", category: .network, complexity: 2)),

            (["permission", "chmod", "access"],
             CommandSuggestion(command: "chmod ", description: "Change file permissions", category: .permissions, complexity: 3)),

            (["owner", "chown"],
             CommandSuggestion(command: "chown ", description: "Change file ownership", category: .permissions, complexity: 3)),

            (["install", "brew", "package"],
             CommandSuggestion(command: "brew install ", description: "Install a package with Homebrew", category: .system, complexity: 2)),

            (["date", "time", "what time"],
             CommandSuggestion(command: "date", description: "Show current date and time", category: .system, complexity: 1)),

            (["who am i", "username", "user"],
             CommandSuggestion(command: "whoami", description: "Show your username", category: .system, complexity: 1)),

            (["history", "previous commands", "past"],
             CommandSuggestion(command: "history | tail -20", description: "Show recent command history", category: .system, complexity: 1)),
        ]

        for mapping in naturalLanguageMap {
            if mapping.keywords.contains(where: { input.contains($0) }) {
                matches.append(mapping.suggestion)
            }
        }

        return matches
    }

    private func matchCommandPrefix(_ input: String) -> [CommandSuggestion] {
        let allCommands: [CommandSuggestion] = [
            CommandSuggestion(command: "ls", description: "List directory contents", category: .navigation, complexity: 1),
            CommandSuggestion(command: "ls -la", description: "List all files with details", category: .navigation, complexity: 1),
            CommandSuggestion(command: "ls -lh", description: "List files with human-readable sizes", category: .navigation, complexity: 1),
            CommandSuggestion(command: "pwd", description: "Print working directory (where am I?)", category: .navigation, complexity: 1),
            CommandSuggestion(command: "cd ..", description: "Go up one directory", category: .navigation, complexity: 1),
            CommandSuggestion(command: "cat", description: "Display file contents", category: .files, complexity: 1),
            CommandSuggestion(command: "head -20", description: "Show first 20 lines of a file", category: .files, complexity: 1),
            CommandSuggestion(command: "tail -20", description: "Show last 20 lines of a file", category: .files, complexity: 1),
            CommandSuggestion(command: "wc -l", description: "Count lines in a file", category: .files, complexity: 1),
            CommandSuggestion(command: "git log --oneline -10", description: "Show last 10 commits", category: .git, complexity: 2),
            CommandSuggestion(command: "git diff", description: "Show changes not yet staged", category: .git, complexity: 2),
            CommandSuggestion(command: "git stash", description: "Temporarily save your changes", category: .git, complexity: 2),
        ]

        return allCommands.filter { $0.command.lowercased().hasPrefix(input) }
    }

    private func getContextualSuggestions(currentDir: String) -> [CommandSuggestion] {
        var suggestions: [CommandSuggestion] = []

        // Check if we're in a git repo
        let gitDir = (currentDir as NSString).appendingPathComponent(".git")
        if FileManager.default.fileExists(atPath: gitDir) {
            suggestions.append(CommandSuggestion(command: "git status", description: "Check git status (you're in a repo!)", category: .git, complexity: 1))
        }

        // Check for common project files
        let packageJson = (currentDir as NSString).appendingPathComponent("package.json")
        if FileManager.default.fileExists(atPath: packageJson) {
            suggestions.append(CommandSuggestion(command: "npm install", description: "Install Node.js dependencies", category: .system, complexity: 2))
            suggestions.append(CommandSuggestion(command: "npm start", description: "Start the project", category: .system, complexity: 1))
        }

        let makefile = (currentDir as NSString).appendingPathComponent("Makefile")
        if FileManager.default.fileExists(atPath: makefile) {
            suggestions.append(CommandSuggestion(command: "make", description: "Build using Makefile", category: .system, complexity: 2))
        }

        return suggestions
    }

    private func getFrequentSuggestions(recentCommands: [String]) -> [CommandSuggestion] {
        // Default helpful suggestions when input is empty
        return [
            CommandSuggestion(command: "ls -la", description: "See what's in this directory", category: .navigation, complexity: 1),
            CommandSuggestion(command: "pwd", description: "Where am I right now?", category: .navigation, complexity: 1),
            CommandSuggestion(command: "git status", description: "Check git changes", category: .git, complexity: 1),
        ]
    }

    // MARK: - Command Explanation
    func explainCommand(_ command: String) -> String {
        let parts = command.components(separatedBy: " ")
        guard let base = parts.first else { return "Type a command to get an explanation" }

        let explanations: [String: String] = [
            "ls": "📂 Lists what's in a directory — like opening a folder to see inside",
            "cd": "🚶 Changes your location — like walking to a different room",
            "pwd": "📍 Shows where you are right now — like checking a map",
            "cat": "📄 Displays file contents — like opening and reading a document",
            "mkdir": "📁 Creates a new folder — like making a new drawer",
            "touch": "✨ Creates an empty file — like putting a blank page somewhere",
            "rm": "🗑️ Deletes a file — ⚠️ careful, no recycle bin!",
            "cp": "📋 Copies a file — like photocopying a document",
            "mv": "📦 Moves or renames a file — like relocating something",
            "grep": "🔍 Searches for text in files — like Ctrl+F but for multiple files",
            "find": "🔎 Finds files by name — like searching your whole computer",
            "chmod": "🔐 Changes who can access a file — like changing locks",
            "chown": "👤 Changes who owns a file",
            "git": "📦 Version control — saves snapshots of your work",
            "npm": "📦 Node.js package manager — installs code libraries",
            "brew": "🍺 Homebrew — installs apps and tools on your Mac",
            "pip": "🐍 Python package installer",
            "sudo": "⚡ Run as administrator — ⚠️ be careful with this!",
            "man": "📖 Shows the manual for a command — like a help page",
            "echo": "🗣️ Prints text to the screen — makes the terminal say something",
            "curl": "🌐 Downloads from the internet — like a mini web browser",
            "head": "👆 Shows the beginning of a file",
            "tail": "👇 Shows the end of a file",
            "wc": "🔢 Counts lines, words, or characters in a file",
            "sort": "📊 Sorts lines of text alphabetically or numerically",
            "uniq": "🎯 Removes duplicate lines",
            "ping": "📡 Checks if you can reach a server on the internet",
            "kill": "🛑 Stops a running program",
            "ps": "📋 Shows running programs",
            "top": "📊 Shows system resource usage in real-time",
            "df": "💾 Shows disk space usage",
            "du": "📏 Shows file/folder sizes",
            "tar": "📦 Compresses or extracts archive files",
            "ssh": "🔒 Securely connect to another computer",
            "scp": "📤 Securely copy files between computers",

            // NeuroShell built-in commands
            "help": "🧠 Shows all NeuroShell commands — your starting point!",
            "?": "🧠 Shows all NeuroShell commands — same as 'help'",
            "encourage": "🌟 Gives you a motivational pep talk — because you deserve one",
            "motivate": "🌟 Gives you a motivational pep talk — same as 'encourage'",
            "breathe": "🫁 Guides you through a quick breathing exercise to reset",
            "breathing": "🫁 Guides you through a quick breathing exercise to reset",
            "calm": "🫁 Guides you through a quick breathing exercise to reset",
            "stuck": "🤔 Helps you figure out what to do next — step by step",
            "idk": "🤔 Helps you figure out what to do next — same as 'stuck'",
            "confused": "🤔 Helps you figure out what to do next — same as 'stuck'",
            "lost": "🤔 Helps you figure out what to do next — same as 'stuck'",
            "panic": "🤗 Slows everything down — nothing is on fire, you're safe",
            "sos": "🤗 Slows everything down — same as 'panic'",
            "tips": "💡 Shows a random ADHD-friendly terminal tip",
            "status": "📊 Shows your session stats — commands run, time elapsed",
            "stats": "📊 Shows your session stats — same as 'status'",
            "explain": "💡 Explains a command in plain English — e.g. 'explain ls -la'",
            "cheat": "📋 Shows a cheat sheet — try 'cheat git', 'cheat files', etc.",
            "cheatsheet": "📋 Shows a cheat sheet — same as 'cheat'",
            "history": "📜 Shows your recent command history",
            "alias": "📝 Shows or creates command shortcuts",
            "unalias": "🗑️ Removes a command shortcut",
            "focus": "🎯 Tips for staying focused in the terminal",
            "clear": "🧹 Clears the terminal screen — fresh start!",
            "reset": "🔄 Clears everything and resets the session",
            "version": "ℹ️ Shows NeuroShell version info",
            "about": "ℹ️ Shows NeuroShell version info",
            "whoami": "👤 Shows your username",
            "time": "🕐 Shows the current date and time",
            "date": "🕐 Shows the current date and time",
            "now": "🕐 Shows the current date and time",
            "uptime": "⏱️ Shows how long your system has been running",
            "neofetch": "🖥️ Shows system information",
            "shortcuts": "⌨️ Shows keyboard shortcuts",
            "emoji": "😀 Shows the NeuroShell emoji guide",
            "todo": "📝 Reminds you about the Task Chunker in the sidebar",
            "timer": "⏱️ Reminds you about the Timer in the sidebar",

            // Lolcat / Rainbow commands
            "lolcat": "🌈 Rainbow-ify text! Try 'lolcat Hello World!' or pipe: 'ls | lolcat'",
            "rainbow": "🌈 Rainbow mode — test, banner, themes, or rainbow-ify text",
            "nyan": "🐱 Shows nyan cat in glorious rainbow!",
            "pride": "🏳️‍🌈 Shows a pride banner — you are valid, you are loved",
            "gay": "✨ Easter egg — *gay hacker sounds* ✨",
            "sparkle": "✨ Activates sparkle mode!",
            "sparkles": "✨ Activates sparkle mode!",
            "glitter": "✨ Activates sparkle mode!",
            "cowsay": "🐄 A rainbow cow says your text — try 'cowsay Hello!'",
            "figlet": "🔤 Big block-letter ASCII art in rainbow — try 'figlet HI'",
            "banner": "🔤 Big block-letter ASCII art in rainbow — same as 'figlet'",
            "ascii": "🔤 Big block-letter ASCII art in rainbow — same as 'figlet'",
        ]

        return explanations[base] ?? "🤔 I don't have an explanation for '\(base)' yet, but you can try 'man \(base)' to read its manual"
    }

    // MARK: - Task Chunking
    func chunkComplexCommand(_ description: String) -> [TaskChunk] {
        let lowered = description.lowercased()

        if lowered.contains("deploy") || lowered.contains("release") {
            return createDeploymentChunks()
        }

        if lowered.contains("new project") || lowered.contains("setup") || lowered.contains("init") {
            return createProjectSetupChunks()
        }

        if lowered.contains("git") && (lowered.contains("merge") || lowered.contains("pull request") || lowered.contains("pr")) {
            return createGitMergeChunks()
        }

        if lowered.contains("debug") || lowered.contains("fix") || lowered.contains("error") {
            return createDebuggingChunks()
        }

        if lowered.contains("backup") || lowered.contains("copy") || lowered.contains("archive") {
            return createBackupChunks()
        }

        if lowered.contains("install") || lowered.contains("set up") || lowered.contains("configure") {
            return createInstallationChunks()
        }

        // Default: generic task breakdown
        return createGenericChunks(description)
    }

    private func createDeploymentChunks() -> [TaskChunk] {
        return [
            TaskChunk(title: "Check your status", description: "Make sure everything is saved and committed", command: "git status", estimatedMinutes: 2, difficulty: .easy, orderIndex: 0),
            TaskChunk(title: "Run tests", description: "Make sure nothing is broken", command: "npm test", estimatedMinutes: 5, difficulty: .medium, orderIndex: 1),
            TaskChunk(title: "Build the project", description: "Create the production build", command: "npm run build", estimatedMinutes: 5, difficulty: .medium, orderIndex: 2),
            TaskChunk(title: "Commit changes", description: "Save your work with a clear message", command: "git add . && git commit -m \"prepare for deployment\"", estimatedMinutes: 2, difficulty: .easy, orderIndex: 3),
            TaskChunk(title: "Push to remote", description: "Upload your code", command: "git push origin main", estimatedMinutes: 2, difficulty: .easy, orderIndex: 4),
            TaskChunk(title: "Deploy!", description: "Ship it! You've got this! 🚀", command: "npm run deploy", estimatedMinutes: 5, difficulty: .medium, orderIndex: 5),
        ]
    }

    private func createProjectSetupChunks() -> [TaskChunk] {
        return [
            TaskChunk(title: "Create project folder", description: "Make a home for your project", command: "mkdir my-project && cd my-project", estimatedMinutes: 1, difficulty: .easy, orderIndex: 0),
            TaskChunk(title: "Initialize git", description: "Start tracking changes", command: "git init", estimatedMinutes: 1, difficulty: .easy, orderIndex: 1),
            TaskChunk(title: "Create essential files", description: "Set up the basics", command: "touch README.md .gitignore", estimatedMinutes: 2, difficulty: .easy, orderIndex: 2),
            TaskChunk(title: "First commit", description: "Save your starting point!", command: "git add . && git commit -m \"initial commit\"", estimatedMinutes: 2, difficulty: .easy, orderIndex: 3),
        ]
    }

    private func createGitMergeChunks() -> [TaskChunk] {
        return [
            TaskChunk(title: "Save current work", description: "Stash any uncommitted changes", command: "git stash", estimatedMinutes: 1, difficulty: .easy, orderIndex: 0),
            TaskChunk(title: "Switch to main", description: "Go to the main branch", command: "git checkout main", estimatedMinutes: 1, difficulty: .easy, orderIndex: 1),
            TaskChunk(title: "Get latest", description: "Pull the latest changes", command: "git pull origin main", estimatedMinutes: 2, difficulty: .easy, orderIndex: 2),
            TaskChunk(title: "Go back to your branch", description: "Switch back to your working branch", command: "git checkout -", estimatedMinutes: 1, difficulty: .easy, orderIndex: 3),
            TaskChunk(title: "Merge main into yours", description: "Bring in the latest changes", command: "git merge main", estimatedMinutes: 3, difficulty: .medium, orderIndex: 4),
            TaskChunk(title: "Restore stashed work", description: "Get your saved changes back", command: "git stash pop", estimatedMinutes: 1, difficulty: .easy, orderIndex: 5),
        ]
    }

    private func createDebuggingChunks() -> [TaskChunk] {
        return [
            TaskChunk(title: "Read the error", description: "Take a breath, then read the error message carefully", command: "# Read the error output above", estimatedMinutes: 2, difficulty: .easy, orderIndex: 0),
            TaskChunk(title: "Check recent changes", description: "What did you change recently?", command: "git diff", estimatedMinutes: 3, difficulty: .easy, orderIndex: 1),
            TaskChunk(title: "Search for the issue", description: "Look for the error in your files", command: "grep -r \"ERROR_TEXT\" .", estimatedMinutes: 3, difficulty: .medium, orderIndex: 2),
            TaskChunk(title: "Check logs", description: "Look at any log files for clues", command: "tail -50 *.log 2>/dev/null || echo 'No log files found'", estimatedMinutes: 3, difficulty: .medium, orderIndex: 3),
            TaskChunk(title: "Test the fix", description: "Run your tests to see if it's fixed", command: "npm test", estimatedMinutes: 5, difficulty: .medium, orderIndex: 4),
        ]
    }

    private func createBackupChunks() -> [TaskChunk] {
        return [
            TaskChunk(title: "Check what to backup", description: "See what files need backing up", command: "ls -la", estimatedMinutes: 2, difficulty: .easy, orderIndex: 0),
            TaskChunk(title: "Create backup folder", description: "Make a place for the backup", command: "mkdir -p ~/backups/$(date +%Y%m%d)", estimatedMinutes: 1, difficulty: .easy, orderIndex: 1),
            TaskChunk(title: "Copy files", description: "Copy everything to the backup", command: "cp -r . ~/backups/$(date +%Y%m%d)/", estimatedMinutes: 3, difficulty: .easy, orderIndex: 2),
            TaskChunk(title: "Verify backup", description: "Make sure the backup looks right", command: "ls -la ~/backups/$(date +%Y%m%d)/", estimatedMinutes: 2, difficulty: .easy, orderIndex: 3),
        ]
    }

    private func createInstallationChunks() -> [TaskChunk] {
        return [
            TaskChunk(title: "Check if Homebrew is installed", description: "We need Homebrew first", command: "which brew || echo 'Homebrew not found'", estimatedMinutes: 1, difficulty: .easy, orderIndex: 0),
            TaskChunk(title: "Update package list", description: "Get the latest available packages", command: "brew update", estimatedMinutes: 3, difficulty: .easy, orderIndex: 1),
            TaskChunk(title: "Install the package", description: "Download and install", command: "brew install PACKAGE_NAME", estimatedMinutes: 5, difficulty: .medium, orderIndex: 2),
            TaskChunk(title: "Verify installation", description: "Make sure it worked!", command: "which PACKAGE_NAME && echo 'Installed successfully! 🎉'", estimatedMinutes: 1, difficulty: .easy, orderIndex: 3),
        ]
    }

    private func createGenericChunks(_ description: String) -> [TaskChunk] {
        return [
            TaskChunk(title: "Understand the goal", description: "What exactly do you want to achieve? Write it down.", command: "# Goal: \(description)", estimatedMinutes: 2, difficulty: .easy, orderIndex: 0),
            TaskChunk(title: "Check your starting point", description: "Where are you now? What do you have?", command: "pwd && ls -la", estimatedMinutes: 2, difficulty: .easy, orderIndex: 1),
            TaskChunk(title: "Take the first step", description: "What's the smallest thing you can do right now?", command: "# Start with the simplest part", estimatedMinutes: 5, difficulty: .medium, orderIndex: 2),
            TaskChunk(title: "Verify progress", description: "Did that work? Check the results", command: "# Check that the previous step worked", estimatedMinutes: 2, difficulty: .easy, orderIndex: 3),
        ]
    }
}
