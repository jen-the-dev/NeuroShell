import Combine
import Foundation
import SwiftUI

// MARK: - Terminal Service
/// Manages actual shell process interaction with proper async execution
/// and comprehensive built-in command handling for ADHD/AuDHD users
@MainActor
class TerminalService: ObservableObject {
    @Published var outputLines: [TerminalLine] = []
    @Published var isRunning: Bool = false
    @Published var currentDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path

    /// Reference to the shared LolcatRenderer so terminal commands can switch themes
    weak var lolcatRenderer: LolcatRenderer?

    private var currentProcess: Process?
    private var commandHistory: [String] = []
    private var historyIndex: Int = -1
    private var previousDirectory: String = ""
    private var aliases: [String: String] = [:]
    private var sessionStartTime: Date = Date()
    private var commandCount: Int = 0

    init() {
        setupDefaultAliases()
        addSystemMessage("🧠 Welcome to NeuroShell v3 — your neurodivergent-friendly terminal")
        addSystemMessage("💡 Type 'help' for commands, '?' for quick reference, or just start typing")
        addSystemMessage("🎯 Tip: Describe what you want in plain English and I'll help break it down")
        addSystemMessage("📖 Type 'man <command>' to learn about any command in plain language")
        addSystemMessage("")
    }

    // MARK: - Default Aliases
    private func setupDefaultAliases() {
        aliases = [
            "ll": "ls -la",
            "la": "ls -la",
            "l": "ls -CF",
            "..": "cd ..",
            "...": "cd ../..",
            "....": "cd ../../..",
            "~": "cd ~",
            "cls": "clear",
            "c": "clear",
            "q": "exit",
            "quit": "exit",
            "h": "help",
            "?": "help",
            "commands": "help",
            "halp": "help",
            "hlep": "help",
            "hepl": "help",
            "hep": "help",
            "dir": "ls -la",
            "whereami": "pwd",
            "where": "pwd",
            "whichdir": "pwd",
        ]
    }

    // MARK: - Build Shell Environment
    private func buildEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment

        // Disable all pagers — #1 cause of hangs
        env["PAGER"] = "cat"
        env["GIT_PAGER"] = "cat"
        env["MANPAGER"] = "cat"
        env["SYSTEMD_PAGER"] = "cat"
        env["BAT_PAGER"] = "cat"

        // Use dumb terminal to prevent ncurses interactive UI
        env["TERM"] = "dumb"
        env["COLUMNS"] = "120"
        env["LINES"] = "50"

        // Disable color codes that produce garbage in our text view
        env["NO_COLOR"] = "1"
        env["GIT_TERMINAL_PROMPT"] = "0"
        env["CLICOLOR"] = "0"
        env["CLICOLOR_FORCE"] = "0"

        // Force non-interactive
        env["DEBIAN_FRONTEND"] = "noninteractive"
        env["CI"] = "true"

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        env["HOME"] = home

        // Build comprehensive PATH
        let pathComponents: [String] = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "/usr/bin",
            "/usr/sbin",
            "/bin",
            "/sbin",
            "\(home)/.cargo/bin",
            "\(home)/.local/bin",
            "\(home)/go/bin",
            "\(home)/.nvm/versions/node/default/bin",
            "/Library/Apple/usr/bin",
            "/Library/Frameworks/Python.framework/Versions/Current/bin",
            "\(home)/.rbenv/shims",
            "\(home)/.pyenv/shims",
            "/opt/homebrew/opt/python/libexec/bin",
            "\(home)/.volta/bin",
            "\(home)/.bun/bin",
            "\(home)/.deno/bin",
        ]

        let existingPath = env["PATH"] ?? ""
        let existingComponents = existingPath.components(separatedBy: ":")
        var finalComponents = pathComponents
        for component in existingComponents {
            if !finalComponents.contains(component) && !component.isEmpty {
                finalComponents.append(component)
            }
        }
        env["PATH"] = finalComponents.joined(separator: ":")

        return env
    }

    // MARK: - Execute Command (Main Entry Point)
    func executeCommand(_ command: String) async {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Save to history
        commandHistory.append(trimmed)
        historyIndex = commandHistory.count
        commandCount += 1

        // Add input line
        outputLines.append(TerminalLine("❯ \(trimmed)", type: .input))

        // Resolve aliases first
        let resolved = resolveAlias(trimmed)

        // Handle built-in commands first (these ALWAYS work, no shell needed)
        if await handleBuiltInCommand(resolved) {
            return
        }

        // Handle cd command specially (must change our state)
        if resolved == "cd" || resolved.hasPrefix("cd ") {
            handleCd(resolved)
            return
        }

        // Handle man/help-for-command requests as built-in
        if resolved.hasPrefix("man ") || resolved.hasSuffix(" --help") || resolved.hasSuffix(" -h") {
            if handleManCommand(resolved) {
                return
            }
            // If our built-in man doesn't know it, fall through to external
        }

        // Handle lolcat pipe: "somecommand | lolcat" or "somecommand | lolcat --flags"
        if let lolcatResult = extractLolcatPipe(resolved) {
            await runExternalCommandAsRainbow(lolcatResult.command, seed: lolcatResult.seed)
            return
        }

        // Execute as external shell command
        await runExternalCommand(resolved)
    }

    // MARK: - Lolcat Pipe Detection

    private struct LolcatPipeResult {
        let command: String
        let seed: Double
    }

    /// Detect "command | lolcat" patterns and strip the pipe so we can run the
    /// command normally and render its output as rainbow lines.
    private func extractLolcatPipe(_ command: String) -> LolcatPipeResult? {
        // Match: anything | lolcat (optionally with flags like --spread, --freq, etc.)
        // Also match: anything | rainbow
        let patterns = [
            " | lolcat", " |lolcat",
            " | rainbow", " |rainbow",
            " | gay", " |gay",           // for the memes
            " | nyan", " |nyan",
        ]

        for pattern in patterns {
            if let range = command.range(of: pattern, options: .caseInsensitive) {
                let baseCommand = String(command[command.startIndex..<range.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !baseCommand.isEmpty {
                    return LolcatPipeResult(command: baseCommand, seed: Double.random(in: 0..<1))
                }
            }
        }

        return nil
    }

    /// Run a command and render ALL output as rainbow text
    private func runExternalCommandAsRainbow(_ command: String, seed: Double) async {
        isRunning = true

        let workDir = effectiveWorkingDirectory()

        let wrappedCommand = """
        export PAGER=cat
        export GIT_PAGER=cat
        export MANPAGER=cat
        export TERM=dumb
        export NO_COLOR=1
        export GIT_TERMINAL_PROMPT=0
        export CLICOLOR=0
        export COLUMNS=120
        \(command) 2>&1
        """

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", wrappedCommand]
        process.currentDirectoryURL = URL(fileURLWithPath: workDir)
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice
        process.environment = buildEnvironment()

        currentProcess = process

        let timeoutSeconds: Double = 120
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            if process.isRunning {
                process.terminate()
                await MainActor.run {
                    addErrorMessage("⏰ Command timed out after \(Int(timeoutSeconds)) seconds")
                }
            }
        }

        do {
            try process.run()

            let stdoutData: Data
            let stderrData: Data

            (stdoutData, stderrData) = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let out = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let err = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    continuation.resume(returning: (out, err))
                }
            }

            timeoutTask.cancel()

            // Render stdout as rainbow 🌈
            if let output = String(data: stdoutData, encoding: .utf8), !output.isEmpty {
                let lines = output.components(separatedBy: "\n")
                var lineCount = 0
                let maxLines = 500

                for (lineIndex, line) in lines.enumerated() {
                    if lineCount >= maxLines {
                        outputLines.append(TerminalLine("⚠️ Output truncated. Showing first \(maxLines) rainbow lines.", type: .system))
                        break
                    }
                    if !line.isEmpty {
                        // Each line gets a seed based on its position for the diagonal rainbow effect
                        let lineSeed = (seed + Double(lineIndex) * 0.05)
                            .truncatingRemainder(dividingBy: 1.0)
                        outputLines.append(TerminalLine(line, type: .rainbow, rainbowSeed: lineSeed))
                        lineCount += 1
                    }
                }
            }

            // Stderr also as rainbow (why not?)
            if let errOutput = String(data: stderrData, encoding: .utf8), !errOutput.isEmpty {
                let lines = errOutput.components(separatedBy: "\n")
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        outputLines.append(TerminalLine(trimmed, type: .rainbow, rainbowSeed: seed))
                    }
                }
            }

            if process.terminationStatus == 0 {
                addRainbowMessage("✨ Rainbow complete! ✨")
            } else {
                addErrorMessage("⚠️ Command exited with code \(process.terminationStatus)")
                let helpMessage = getErrorHelp(for: command, exitCode: process.terminationStatus)
                addSystemMessage(helpMessage)
            }

        } catch {
            timeoutTask.cancel()
            addErrorMessage("❌ Failed to run command: \(error.localizedDescription)")
        }

        isRunning = false
        currentProcess = nil
    }

    // MARK: - Alias Resolution
    private func resolveAlias(_ command: String) -> String {
        let parts = command.components(separatedBy: " ")
        guard let first = parts.first else { return command }

        if let aliasTarget = aliases[first] {
            if parts.count > 1 {
                let rest = parts.dropFirst().joined(separator: " ")
                return "\(aliasTarget) \(rest)"
            }
            return aliasTarget
        }

        return command
    }

    // MARK: - Built-in Commands
    private func handleBuiltInCommand(_ command: String) async -> Bool {
        let lowered = command.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = lowered.components(separatedBy: " ")
        let baseCommand = parts.first ?? ""

        switch baseCommand {
        case "help", "?", "commands", "h":
            if parts.count > 1 {
                // "help <topic>" — show help for a specific topic
                let topic = parts.dropFirst().joined(separator: " ")
                showTopicHelp(topic)
            } else {
                showHelp()
            }
            return true

        case "clear", "cls", "c":
            outputLines.removeAll()
            return true

        case "pwd", "whereami", "where", "whichdir":
            addSystemMessage("📂 You are in: \(currentDirectory)")
            addSystemMessage("   (short: \(shortenPath(currentDirectory)))")
            return true

        case "encourage", "motivate", "pep":
            showEncouragement()
            return true

        case "breathe", "breath", "breathing", "calm":
            showBreathingExercise()
            return true

        case "history":
            showHistory()
            return true

        case "alias":
            if parts.count == 1 {
                showAliases()
            } else {
                handleAliasCommand(command)
            }
            return true

        case "unalias":
            if parts.count > 1 {
                let name = parts[1]
                aliases.removeValue(forKey: name)
                addSystemMessage("🗑️ Removed alias '\(name)'")
            }
            return true

        case "exit", "quit", "q":
            addSystemMessage("👋 To quit NeuroShell, use ⌘Q or close the window.")
            addSystemMessage("   (The terminal can't quit itself, but you're in control!)")
            return true

        case "version", "ver", "about":
            showVersion()
            return true

        case "tips", "tip":
            showRandomTip()
            return true

        case "status", "stats":
            showSessionStats()
            return true

        case "shortcuts", "keys", "keybinds", "keyboard":
            showKeyboardShortcuts()
            return true

        case "env":
            showEnvironment()
            return true

        case "reset":
            outputLines.removeAll()
            commandHistory.removeAll()
            historyIndex = -1
            commandCount = 0
            sessionStartTime = Date()
            addSystemMessage("🔄 Terminal reset! Fresh start. You've got this! 💪")
            return true

        case "time", "date", "now", "clock":
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm:ss a"
            addSystemMessage("🕐 \(formatter.string(from: Date()))")
            return true

        case "whoami":
            addSystemMessage("👤 \(NSUserName())")
            return true

        case "hostname":
            addSystemMessage("🖥️ \(ProcessInfo.processInfo.hostName)")
            return true

        case "uptime":
            let uptime = ProcessInfo.processInfo.systemUptime
            let hours = Int(uptime) / 3600
            let minutes = (Int(uptime) % 3600) / 60
            addSystemMessage("⏱️ System uptime: \(hours)h \(minutes)m")
            return true

        case "neofetch", "sysinfo", "systeminfo":
            await showSystemInfo()
            return true

        case "cheatsheet", "cheat":
            if parts.count > 1 {
                let topic = parts.dropFirst().joined(separator: " ")
                showCheatSheet(for: topic)
            } else {
                showCheatSheetIndex()
            }
            return true

        case "explain":
            if parts.count > 1 {
                let cmd = parts.dropFirst().joined(separator: " ")
                explainCommand(cmd)
            } else {
                addSystemMessage("💡 Usage: explain <command>")
                addSystemMessage("   Example: explain 'ls -la'")
            }
            return true

        case "todo", "tasks":
            addSystemMessage("📝 Use the Task Chunker in the toolbar → to break down tasks!")
            addSystemMessage("   Click 'Tasks' in the top toolbar.")
            return true

        case "timer", "pomodoro":
            addSystemMessage("⏱️ Use the Timer in the toolbar → for focus sessions!")
            addSystemMessage("   Click 'Timer' in the top toolbar.")
            return true

        case "focus":
            addSystemMessage("🎯 Focus mode tip: Stay on the Terminal tab and tune out distractions.")
            addSystemMessage("   Your brain works better with fewer distractions.")
            addSystemMessage("   Try: Set a 25-minute timer, pick ONE task, and go!")
            return true

        case "stuck", "idk", "confused", "lost":
            showStuckHelp()
            return true

        case "panic", "help!", "sos":
            showPanicHelp()
            return true

        case "emoji":
            showEmojiReference()
            return true

        case "lolcat":
            if parts.count > 1 {
                // "lolcat some text here" — render the text as rainbow
                let text = String(command.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
                addRainbowMessage(text)
            } else {
                showLolcatHelp()
            }
            return true

        case "rainbow":
            if parts.count > 1 {
                let subcommand = parts[1]
                switch subcommand {
                case "on", "enable":
                    lolcatRenderer?.isEnabled = true
                    addRainbowMessage("🌈 Rainbow mode: ON — celebrations will sparkle!")
                    addSystemMessage("   (Use 'rainbow off' to disable)")
                    return true
                case "off", "disable":
                    lolcatRenderer?.isEnabled = false
                    addSystemMessage("Rainbow mode: OFF — back to normal colors")
                    addSystemMessage("   (Use 'rainbow on' to re-enable)")
                    return true
                case "test":
                    showRainbowTest()
                    return true
                case "banner":
                    showRainbowBanner()
                    return true
                case "themes":
                    showRainbowThemes()
                    return true
                case "theme":
                    if parts.count > 2 {
                        applyTheme(parts[2])
                    } else {
                        showRainbowThemes()
                    }
                    return true
                default:
                    // Treat as text to rainbowify
                    let text = parts.dropFirst().joined(separator: " ")
                    addRainbowMessage(text)
                    return true
                }
            } else {
                showRainbowTest()
            }
            return true

        case "nyan":
            showNyanCat()
            return true

        case "gay":
            // Easter egg
            addRainbowMessage("✨ *gay hacker sounds* ✨")
            return true

        case "pride":
            showPrideBanner()
            return true

        case "sparkle", "sparkles", "glitter":
            showSparkles()
            return true

        case "cowsay":
            if parts.count > 1 {
                let text = parts.dropFirst().joined(separator: " ")
                showCowsay(text)
            } else {
                showCowsay("Moo! 🌈")
            }
            return true

        case "figlet", "banner", "ascii":
            if parts.count > 1 {
                let text = parts.dropFirst().joined(separator: " ")
                showFiglet(text)
            } else {
                showRainbowBanner()
            }
            return true

        default:
            // Check for "man" or "--help" patterns handled elsewhere
            return false
        }
    }

    // MARK: - Man Command (Built-in ADHD-Friendly Manual)
    private func handleManCommand(_ command: String) -> Bool {
        var topic = ""

        if command.hasPrefix("man ") {
            topic = String(command.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if command.hasSuffix(" --help") {
            topic = String(command.dropLast(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if command.hasSuffix(" -h") {
            topic = String(command.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !topic.isEmpty else {
            addSystemMessage("📖 Usage: man <command>")
            addSystemMessage("   Example: man ls, man git, man cp")
            return true
        }

        // Check if we have a built-in friendly manual for this command
        if let manual = friendlyManPages[topic.lowercased()] {
            addSystemMessage("")
            addSystemMessage("📖 Manual: \(topic)")
            addSystemMessage("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            for line in manual {
                addSystemMessage(line)
            }
            addSystemMessage("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            addSystemMessage("")
            return true
        }

        // We don't have it built-in — return false to let it try external
        addSystemMessage("📖 I don't have a friendly manual for '\(topic)' yet.")
        addSystemMessage("   Trying the system manual (may take a moment)...")
        addSystemMessage("")
        return false
    }

    // MARK: - Friendly Man Pages Database
    private var friendlyManPages: [String: [String]] {
        return [
            "ls": [
                "📂 ls — List directory contents",
                "",
                "Think of it as: Opening a folder to see what's inside",
                "",
                "Common uses:",
                "  ls              → List files in current directory",
                "  ls -l           → Long format (shows sizes, dates, permissions)",
                "  ls -a           → Show hidden files too (files starting with .)",
                "  ls -la          → Show ALL files with full details (most common!)",
                "  ls -lh          → Human-readable sizes (KB, MB, GB instead of bytes)",
                "  ls -lt          → Sort by time (newest first)",
                "  ls -lS          → Sort by size (biggest first)",
                "  ls -R           → List everything recursively (all subfolders too)",
                "  ls *.txt        → List only .txt files",
                "  ls ~/Desktop    → List files on your Desktop",
                "",
                "💡 Pro tip: 'll' is an alias for 'ls -la' in NeuroShell",
            ],
            "cd": [
                "🚶 cd — Change directory",
                "",
                "Think of it as: Walking to a different room in your house",
                "",
                "Common uses:",
                "  cd foldername   → Go into a folder",
                "  cd ..           → Go up one level (parent folder)",
                "  cd ../..        → Go up two levels",
                "  cd ~            → Go to your home directory",
                "  cd /            → Go to the root of your computer",
                "  cd -            → Go back to where you just were",
                "  cd ~/Desktop    → Go to your Desktop",
                "  cd ~/Downloads  → Go to your Downloads folder",
                "",
                "💡 Pro tip: Use Tab to auto-complete folder names!",
                "💡 Pro tip: '..' and '...' are aliases for 'cd ..' and 'cd ../..'",
            ],
            "pwd": [
                "📍 pwd — Print working directory",
                "",
                "Think of it as: Checking the map to see where you are",
                "",
                "Usage:",
                "  pwd             → Shows your current location as a full path",
                "",
                "💡 NeuroShell also shows your location in the top bar!",
                "💡 You can also type 'whereami' or 'where' as shortcuts",
            ],
            "cat": [
                "📄 cat — Display file contents",
                "",
                "Think of it as: Opening a document to read it",
                "",
                "Common uses:",
                "  cat file.txt        → Display the contents of file.txt",
                "  cat file1 file2     → Display multiple files in order",
                "  cat -n file.txt     → Show with line numbers",
                "",
                "Related commands:",
                "  head -20 file.txt   → Show just the first 20 lines",
                "  tail -20 file.txt   → Show just the last 20 lines",
                "  less file.txt       → Read a long file page by page",
                "  wc -l file.txt      → Count how many lines",
                "",
                "💡 For very long files, use 'head' to see just the beginning",
            ],
            "cp": [
                "📋 cp — Copy files or directories",
                "",
                "Think of it as: Photocopying a document",
                "",
                "Common uses:",
                "  cp file.txt backup.txt        → Copy a file",
                "  cp file.txt ~/Desktop/         → Copy to Desktop",
                "  cp -r folder/ folder_backup/   → Copy an entire folder (-r = recursive)",
                "  cp -i file.txt dest.txt        → Ask before overwriting (-i = interactive)",
                "",
                "⚠️ Be careful: cp will overwrite existing files without asking (unless you use -i)!",
                "💡 Use 'cp -i' if you're not sure — it'll ask first",
            ],
            "mv": [
                "📦 mv — Move or rename files",
                "",
                "Think of it as: Moving a file to a different drawer, or relabeling it",
                "",
                "Common uses:",
                "  mv old.txt new.txt            → Rename a file",
                "  mv file.txt ~/Desktop/         → Move to Desktop",
                "  mv folder/ ~/Documents/        → Move a whole folder",
                "  mv -i file.txt dest.txt        → Ask before overwriting",
                "",
                "⚠️ mv overwrites the destination if it exists (use -i to be safe)",
                "💡 Unlike cp, mv doesn't need -r for folders",
            ],
            "rm": [
                "🗑️ rm — Remove (delete) files",
                "",
                "Think of it as: Shredding a document — there's NO recycle bin!",
                "",
                "Common uses:",
                "  rm file.txt                    → Delete a file",
                "  rm -i file.txt                 → Ask before deleting (safer!)",
                "  rm -r folder/                  → Delete a folder and everything in it",
                "  rm *.txt                       → Delete all .txt files",
                "",
                "⚠️⚠️⚠️ DANGER ZONE:",
                "  rm -rf /        ← NEVER DO THIS — deletes everything!",
                "  rm -rf *        ← Very dangerous — deletes all files!",
                "",
                "💡 Always use 'rm -i' if you're not 100% sure",
                "💡 Consider 'mv file.txt ~/.Trash/' instead — that's recoverable!",
            ],
            "mkdir": [
                "📁 mkdir — Create a new directory (folder)",
                "",
                "Think of it as: Making a new drawer to put things in",
                "",
                "Common uses:",
                "  mkdir myproject               → Create a folder called 'myproject'",
                "  mkdir -p a/b/c/d              → Create nested folders (all at once!)",
                "  mkdir my-folder my-other       → Create multiple folders",
                "",
                "💡 -p is your friend — it creates parent folders automatically",
            ],
            "touch": [
                "✨ touch — Create an empty file (or update timestamp)",
                "",
                "Think of it as: Putting a blank page somewhere",
                "",
                "Common uses:",
                "  touch newfile.txt              → Create an empty file",
                "  touch file1.txt file2.txt      → Create multiple files",
                "  touch .gitignore               → Create a hidden file (starts with .)",
                "",
                "💡 If the file already exists, touch just updates its timestamp",
            ],
            "grep": [
                "🔍 grep — Search for text in files",
                "",
                "Think of it as: Ctrl+F but for your entire project",
                "",
                "Common uses:",
                "  grep 'hello' file.txt          → Find 'hello' in a file",
                "  grep -r 'TODO' .               → Search ALL files for 'TODO'",
                "  grep -i 'error' log.txt        → Case-insensitive search",
                "  grep -n 'func' *.swift         → Show line numbers",
                "  grep -c 'test' file.txt        → Count matches",
                "  grep -l 'import' *.py          → List files that contain 'import'",
                "  grep -v 'debug' log.txt        → Show lines NOT containing 'debug'",
                "",
                "Useful combos:",
                "  grep -rn 'TODO' . --include='*.swift'  → Search only Swift files",
                "  ps aux | grep python                    → Find running Python processes",
                "",
                "💡 -r = recursive, -i = ignore case, -n = line numbers",
            ],
            "find": [
                "🔎 find — Find files by name, type, or other attributes",
                "",
                "Think of it as: Searching your whole computer by filename",
                "",
                "Common uses:",
                "  find . -name '*.txt'           → Find all .txt files",
                "  find . -name 'README*'         → Find files starting with README",
                "  find . -type d -name 'test'    → Find directories named 'test'",
                "  find . -size +10M              → Find files larger than 10MB",
                "  find . -mtime -7               → Files modified in last 7 days",
                "  find ~ -name '*.pdf'           → Find all PDFs in home directory",
                "",
                "💡 The '.' means 'start from current directory'",
                "💡 Use '~' to search from your home directory",
            ],
            "chmod": [
                "🔐 chmod — Change file permissions",
                "",
                "Think of it as: Changing who has the key to a room",
                "",
                "Common uses:",
                "  chmod +x script.sh             → Make a script executable",
                "  chmod 644 file.txt             → Owner read/write, others read only",
                "  chmod 755 script.sh            → Owner all, others read/execute",
                "  chmod -R 755 folder/           → Change permissions recursively",
                "",
                "Number meanings:",
                "  4 = read, 2 = write, 1 = execute",
                "  7 = all (4+2+1), 5 = read+execute (4+1), 6 = read+write (4+2)",
                "  First digit = owner, second = group, third = others",
                "",
                "💡 Most common: chmod +x to make scripts runnable",
            ],
            "git": [
                "📦 git — Version control system",
                "",
                "Think of it as: A time machine for your code",
                "",
                "Getting started:",
                "  git init                → Start tracking a project",
                "  git clone <url>         → Download a project from GitHub",
                "",
                "Daily workflow:",
                "  git status              → What's changed? (always start here!)",
                "  git add .               → Stage all changes",
                "  git add file.txt        → Stage one file",
                "  git commit -m 'msg'     → Save a snapshot with a message",
                "  git push                → Upload to GitHub",
                "  git pull                → Download latest from GitHub",
                "",
                "Branching:",
                "  git branch              → List branches",
                "  git checkout -b new     → Create & switch to new branch",
                "  git checkout main       → Switch to main branch",
                "  git merge branch-name   → Merge a branch into current",
                "",
                "Checking things:",
                "  git log --oneline -10   → Last 10 commits (short)",
                "  git diff                → See unstaged changes",
                "  git diff --staged       → See staged changes",
                "  git stash               → Temporarily save changes",
                "  git stash pop           → Restore saved changes",
                "",
                "💡 When in doubt: git status → git add . → git commit → git push",
            ],
            "git status": [
                "📊 git status — Check what's changed",
                "",
                "This shows you:",
                "  • Which files you've modified",
                "  • Which files are staged (ready to commit)",
                "  • Which files are untracked (new, not yet added)",
                "  • Which branch you're on",
                "",
                "💡 ALWAYS run this first before doing any git operation",
            ],
            "ssh": [
                "🔒 ssh — Securely connect to another computer",
                "",
                "Think of it as: Remotely logging into another computer",
                "",
                "Common uses:",
                "  ssh user@hostname              → Connect to a remote server",
                "  ssh user@192.168.1.100         → Connect by IP address",
                "  ssh -p 2222 user@host          → Connect on a different port",
                "  ssh-keygen                     → Generate SSH keys",
                "",
                "💡 Press Ctrl+D or type 'exit' to disconnect",
            ],
            "curl": [
                "🌐 curl — Transfer data from/to a URL",
                "",
                "Think of it as: A mini web browser in your terminal",
                "",
                "Common uses:",
                "  curl https://example.com           → Download a webpage",
                "  curl -o file.zip <url>             → Save to a file",
                "  curl -I <url>                      → Just show headers",
                "  curl -X POST <url> -d 'data'       → Send POST request",
                "",
                "💡 For downloading files, 'curl -O <url>' keeps the original filename",
            ],
            "brew": [
                "🍺 brew — Homebrew package manager (macOS)",
                "",
                "Think of it as: An app store for command-line tools",
                "",
                "Common uses:",
                "  brew search <name>         → Search for a package",
                "  brew install <name>        → Install a package",
                "  brew uninstall <name>      → Remove a package",
                "  brew update                → Update Homebrew itself",
                "  brew upgrade               → Upgrade all packages",
                "  brew list                  → See what's installed",
                "  brew info <name>           → Get info about a package",
                "  brew doctor                → Check for problems",
                "",
                "💡 Always 'brew update' before 'brew install' for latest versions",
            ],
            "npm": [
                "📦 npm — Node.js package manager",
                "",
                "Think of it as: An app store for JavaScript libraries",
                "",
                "Common uses:",
                "  npm init                   → Start a new Node.js project",
                "  npm install                → Install all dependencies (from package.json)",
                "  npm install <package>      → Install a package",
                "  npm install -g <package>   → Install globally",
                "  npm start                  → Run the start script",
                "  npm test                   → Run tests",
                "  npm run <script>           → Run a custom script",
                "  npm list                   → See installed packages",
                "  npm outdated               → Check for updates",
                "",
                "💡 'npm i' is short for 'npm install'",
            ],
            "python": [
                "🐍 python / python3 — Python interpreter",
                "",
                "Common uses:",
                "  python3 script.py          → Run a Python script",
                "  python3 -m venv env        → Create virtual environment",
                "  python3 -c 'print(1+1)'   → Run quick one-liner",
                "  python3 --version          → Check Python version",
                "",
                "Virtual environments:",
                "  python3 -m venv myenv      → Create",
                "  source myenv/bin/activate  → Activate",
                "  deactivate                 → Deactivate",
                "",
                "💡 On macOS, use 'python3' (not 'python') for Python 3",
            ],
            "python3": [
                "🐍 python3 — Python 3 interpreter",
                "",
                "Common uses:",
                "  python3 script.py          → Run a Python script",
                "  python3 -m venv env        → Create virtual environment",
                "  python3 -c 'print(1+1)'   → Run quick one-liner",
                "  python3 --version          → Check Python version",
                "",
                "Virtual environments:",
                "  python3 -m venv myenv      → Create",
                "  source myenv/bin/activate  → Activate",
                "  deactivate                 → Deactivate",
                "",
                "💡 On macOS, use 'python3' (not 'python') for Python 3",
            ],
            "pip": [
                "📦 pip — Python package installer",
                "",
                "Common uses:",
                "  pip install <package>       → Install a package",
                "  pip install -r requirements.txt → Install from file",
                "  pip list                    → See installed packages",
                "  pip freeze > requirements.txt → Save your dependencies",
                "  pip uninstall <package>     → Remove a package",
                "",
                "💡 Use 'pip3' on macOS, and always work in a virtual environment!",
            ],
            "tar": [
                "📦 tar — Archive and compress files",
                "",
                "Think of it as: Packing (or unpacking) a suitcase",
                "",
                "Common uses:",
                "  tar -czf archive.tar.gz folder/   → Compress a folder",
                "  tar -xzf archive.tar.gz           → Extract an archive",
                "  tar -tzf archive.tar.gz           → List contents without extracting",
                "",
                "Remember the flags:",
                "  c = create, x = extract, t = list",
                "  z = gzip compression, f = filename follows",
                "",
                "💡 Mnemonic: 'tar -czf' = Create Zipped File",
                "💡 Mnemonic: 'tar -xzf' = eXtract Zipped File",
            ],
            "echo": [
                "🗣️ echo — Print text to the terminal",
                "",
                "Think of it as: Making the terminal say something",
                "",
                "Common uses:",
                "  echo 'Hello!'              → Print Hello!",
                "  echo $HOME                 → Print your home directory path",
                "  echo $PATH                 → Print your PATH variable",
                "  echo 'text' > file.txt     → Write text to a file (overwrites!)",
                "  echo 'text' >> file.txt    → Append text to a file",
                "",
                "💡 Use single quotes for literal text, double quotes for variables",
            ],
            "head": [
                "👆 head — Show the beginning of a file",
                "",
                "Common uses:",
                "  head file.txt              → Show first 10 lines",
                "  head -20 file.txt          → Show first 20 lines",
                "  head -n 5 file.txt         → Show first 5 lines",
                "",
                "💡 Great for previewing files without loading the whole thing",
            ],
            "tail": [
                "👇 tail — Show the end of a file",
                "",
                "Common uses:",
                "  tail file.txt              → Show last 10 lines",
                "  tail -20 file.txt          → Show last 20 lines",
                "  tail -f log.txt            → Watch a file in real-time (Ctrl+C to stop)",
                "",
                "💡 'tail -f' is great for watching log files as they update",
            ],
            "sudo": [
                "⚡ sudo — Run a command as administrator",
                "",
                "Think of it as: Using a master key",
                "",
                "Usage:",
                "  sudo <command>             → Run command with admin privileges",
                "  sudo -i                    → Open admin shell",
                "",
                "⚠️ Be very careful with sudo!",
                "  • Only use it when you understand what the command does",
                "  • You'll be asked for your password",
                "  • With great power comes great responsibility 🕷️",
                "",
                "💡 If a command says 'permission denied', sudo MIGHT fix it",
                "   But first ask: should I actually have permission to do this?",
            ],
            "which": [
                "🔍 which — Find where a command lives",
                "",
                "Usage:",
                "  which python3              → Shows the path to python3",
                "  which git                  → Shows where git is installed",
                "",
                "💡 If 'which' returns nothing, the command isn't installed",
            ],
            "wc": [
                "🔢 wc — Count words, lines, or characters",
                "",
                "Common uses:",
                "  wc file.txt               → Show lines, words, and bytes",
                "  wc -l file.txt            → Count lines only",
                "  wc -w file.txt            → Count words only",
                "  wc -c file.txt            → Count bytes",
                "",
                "💡 Great with pipes: ls | wc -l → count how many files",
            ],
            "sort": [
                "📊 sort — Sort lines of text",
                "",
                "Common uses:",
                "  sort file.txt             → Sort alphabetically",
                "  sort -r file.txt          → Reverse sort",
                "  sort -n file.txt          → Numerical sort",
                "  sort -u file.txt          → Sort and remove duplicates",
                "",
                "💡 Often used with pipes: cat data.txt | sort | uniq",
            ],
            "xcode-select": [
                "🛠️ xcode-select — Manage Xcode developer tools",
                "",
                "Common uses:",
                "  xcode-select --install     → Install command line tools",
                "  xcode-select -p            → Show current developer directory",
                "",
                "💡 Run '--install' if you get errors about missing dev tools",
            ],
            "nano": [
                "✏️ nano — Simple text editor in the terminal",
                "",
                "Usage:",
                "  nano file.txt              → Open/create a file for editing",
                "",
                "Inside nano:",
                "  Ctrl+O    → Save (write Out)",
                "  Ctrl+X    → Exit",
                "  Ctrl+K    → Cut a line",
                "  Ctrl+U    → Paste a line",
                "  Ctrl+W    → Search for text",
                "  Ctrl+G    → Show help",
                "",
                "💡 nano shows shortcuts at the bottom — ^ means Ctrl",
                "⚠️ Note: nano is interactive and may not work perfectly in NeuroShell",
                "   For editing, consider using your regular code editor instead.",
            ],
            "vim": [
                "✏️ vim — Powerful text editor (steep learning curve!)",
                "",
                "Usage:",
                "  vim file.txt               → Open a file",
                "",
                "Essential survival guide:",
                "  i         → Enter insert mode (now you can type!)",
                "  Esc       → Exit insert mode",
                "  :w        → Save",
                "  :q        → Quit",
                "  :wq       → Save and quit",
                "  :q!       → Quit WITHOUT saving (emergency exit!)",
                "",
                "💡 If you're stuck in vim: press Esc, then type :q! and Enter",
                "⚠️ vim is interactive and won't work in NeuroShell",
                "   Use your regular code editor for editing files.",
            ],
            "df": [
                "💾 df — Show disk space usage",
                "",
                "Common uses:",
                "  df -h                      → Human-readable sizes (GB, MB)",
                "  df -h .                    → Space on current drive",
                "",
                "💡 -h means 'human-readable' — gives you GB instead of bytes",
            ],
            "du": [
                "📏 du — Show file/folder sizes",
                "",
                "Common uses:",
                "  du -sh *                   → Size of each item in current directory",
                "  du -sh folder/             → Size of a specific folder",
                "  du -sh . | sort -h         → Sorted by size",
                "",
                "💡 -s = summary, -h = human-readable",
            ],
            "ps": [
                "📋 ps — Show running processes",
                "",
                "Common uses:",
                "  ps aux                     → Show all running processes",
                "  ps aux | grep python       → Find Python processes",
                "  ps aux | head -20          → Top 20 processes",
                "",
                "Related:",
                "  kill <PID>                 → Stop a process (get PID from ps)",
                "",
                "💡 Use 'ps aux | grep <name>' to find a specific program",
            ],
            "kill": [
                "🛑 kill — Stop a running process",
                "",
                "Common uses:",
                "  kill <PID>                 → Gracefully stop a process",
                "  kill -9 <PID>              → Force kill (last resort!)",
                "",
                "How to find the PID:",
                "  ps aux | grep <name>       → The number in the 2nd column is the PID",
                "",
                "💡 Always try regular kill first, -9 only if it won't stop",
            ],
            "ping": [
                "📡 ping — Check network connectivity",
                "",
                "Common uses:",
                "  ping google.com            → Check internet (Ctrl+C to stop)",
                "  ping -c 5 google.com       → Ping 5 times then stop",
                "",
                "💡 Use -c to limit pings, otherwise it runs forever!",
            ],
            "man": [
                "📖 man — Read the manual for a command",
                "",
                "Usage:",
                "  man <command>              → Show the manual page",
                "",
                "In NeuroShell, man pages are shown in ADHD-friendly plain language!",
                "Try: man ls, man git, man cp, man grep",
                "",
                "💡 In NeuroShell, you can also use: help <command>, explain <command>",
            ],
            "open": [
                "📂 open — Open files/folders with default app (macOS)",
                "",
                "Common uses:",
                "  open .                     → Open current folder in Finder",
                "  open file.pdf              → Open a PDF with Preview",
                "  open -a 'Visual Studio Code' .  → Open folder in VS Code",
                "  open https://google.com    → Open URL in browser",
                "",
                "💡 'open .' is one of the most useful macOS commands!",
            ],
            "pbcopy": [
                "📋 pbcopy — Copy to clipboard (macOS)",
                "",
                "Common uses:",
                "  echo 'text' | pbcopy       → Copy text to clipboard",
                "  cat file.txt | pbcopy      → Copy file contents to clipboard",
                "  pwd | pbcopy               → Copy current path to clipboard",
                "",
                "Related: pbpaste → paste from clipboard",
            ],
            "pbpaste": [
                "📋 pbpaste — Paste from clipboard (macOS)",
                "",
                "Common uses:",
                "  pbpaste                    → Print clipboard contents",
                "  pbpaste > file.txt         → Save clipboard to a file",
                "",
                "Related: pbcopy → copy to clipboard",
            ],
            "xargs": [
                "🔗 xargs — Build and execute commands from input",
                "",
                "Common uses:",
                "  find . -name '*.txt' | xargs wc -l     → Count lines in all txt files",
                "  echo 'a b c' | xargs -n 1              → Process one item at a time",
                "",
                "💡 xargs takes output from one command and feeds it to another",
            ],
            "awk": [
                "🔧 awk — Pattern scanning and processing",
                "",
                "Common uses:",
                "  awk '{print $1}' file.txt      → Print first column",
                "  awk -F',' '{print $2}' csv.csv  → Print 2nd column of CSV",
                "  ls -l | awk '{print $5, $9}'   → Show only size and name",
                "",
                "💡 $1, $2, etc. refer to columns. $0 is the whole line.",
            ],
            "sed": [
                "🔧 sed — Stream editor for text transformation",
                "",
                "Common uses:",
                "  sed 's/old/new/g' file.txt     → Replace 'old' with 'new'",
                "  sed -i '' 's/old/new/g' file   → Replace in-place (macOS)",
                "  sed -n '5,10p' file.txt        → Print lines 5-10",
                "",
                "💡 The 'g' at the end means 'global' — replace ALL occurrences",
            ],
            "zip": [
                "📦 zip — Compress files into a zip archive",
                "",
                "Common uses:",
                "  zip archive.zip file1 file2     → Zip specific files",
                "  zip -r archive.zip folder/      → Zip a whole folder",
                "",
                "Related: unzip archive.zip → Extract a zip file",
            ],
            "unzip": [
                "📦 unzip — Extract a zip archive",
                "",
                "Common uses:",
                "  unzip archive.zip               → Extract here",
                "  unzip archive.zip -d folder/    → Extract to specific folder",
                "  unzip -l archive.zip            → List contents without extracting",
            ],
            "scp": [
                "📤 scp — Securely copy files between computers",
                "",
                "Common uses:",
                "  scp file.txt user@host:/path/   → Upload a file",
                "  scp user@host:/path/file.txt .  → Download a file",
                "  scp -r folder/ user@host:/path/ → Copy whole folder",
                "",
                "💡 scp uses the same login as ssh",
            ],
            "rsync": [
                "🔄 rsync — Smart file synchronization",
                "",
                "Common uses:",
                "  rsync -av source/ dest/         → Sync folders (archive, verbose)",
                "  rsync -av --delete src/ dest/   → Sync and delete extra files in dest",
                "  rsync -avz src/ user@host:dest/ → Sync to remote server",
                "",
                "💡 rsync is smarter than cp — it only copies what's changed!",
            ],
            "top": [
                "📊 top — Show real-time system activity",
                "",
                "Usage:",
                "  top                        → Show running processes (q to quit)",
                "",
                "⚠️ top is interactive — it may not work well in NeuroShell.",
                "   Try 'ps aux | head -20' instead for a snapshot of processes.",
            ],
            "htop": [
                "📊 htop — Improved top (interactive process viewer)",
                "",
                "Usage:",
                "  htop                       → Show processes with nice UI",
                "",
                "⚠️ htop is interactive — use 'ps aux' in NeuroShell instead.",
                "💡 Install with: brew install htop",
            ],
        ]
    }

    // MARK: - Change Directory
    private func handleCd(_ command: String) {
        let path: String
        if command == "cd" || command == "cd " {
            path = "~"
        } else {
            path = String(command.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !path.isEmpty else {
            previousDirectory = currentDirectory
            currentDirectory = FileManager.default.homeDirectoryForCurrentUser.path
            addSystemMessage("📂 Changed to home directory")
            return
        }

        let resolvedPath: String
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        if path == "~" || path == "$HOME" {
            resolvedPath = home
        } else if path.hasPrefix("~/") {
            resolvedPath = home + String(path.dropFirst(1))
        } else if path.hasPrefix("/") {
            resolvedPath = path
        } else if path == "-" {
            if !previousDirectory.isEmpty {
                resolvedPath = previousDirectory
                addSystemMessage("📂 Back to: \(shortenPath(resolvedPath))")
            } else {
                addSystemMessage("📂 No previous directory — you haven't cd'd yet")
                return
            }
        } else {
            resolvedPath = (currentDirectory as NSString).appendingPathComponent(path)
        }

        let standardized = (resolvedPath as NSString).standardizingPath

        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: standardized, isDirectory: &isDir), isDir.boolValue {
            previousDirectory = currentDirectory
            currentDirectory = standardized
            addSystemMessage("📂 Moved to: \(shortenPath(standardized))")

            // Show a quick peek of what's there
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: standardized) {
                let visible = contents.filter { !$0.hasPrefix(".") }
                let count = visible.count
                let hidden = contents.count - visible.count
                if count > 0 {
                    let preview = visible.prefix(5).joined(separator: ", ")
                    let more = count > 5 ? " (+\(count - 5) more)" : ""
                    addSystemMessage("   📄 Contains: \(preview)\(more)")
                    if hidden > 0 {
                        addSystemMessage("   👻 \(hidden) hidden files (use 'ls -a' to see)")
                    }
                } else if hidden > 0 {
                    addSystemMessage("   👻 \(hidden) hidden files only (use 'ls -a' to see)")
                } else {
                    addSystemMessage("   📭 This directory is empty")
                }
            }
        } else if FileManager.default.fileExists(atPath: standardized) {
            addErrorMessage("Not a directory: \(path)")
            addSystemMessage("💡 That's a file, not a folder. Try 'cat \(path)' to read it.")
        } else {
            addErrorMessage("Directory not found: \(path)")
            addSystemMessage("💡 Tip: Use 'ls' to see what's in the current directory")

            // Try to suggest similar directories
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: currentDirectory) {
                let similar = contents.filter { item in
                    var isDir: ObjCBool = false
                    let itemPath = (currentDirectory as NSString).appendingPathComponent(item)
                    FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir)
                    return isDir.boolValue && item.lowercased().contains(path.lowercased().prefix(3))
                }
                if !similar.isEmpty {
                    addSystemMessage("💡 Did you mean one of these? \(similar.prefix(5).joined(separator: ", "))")
                }
            }
        }
    }

    // MARK: - External Command Execution

    /// Returns a directory path that exists and is usable as the process cwd.
    /// If currentDirectory is missing (e.g. was deleted), falls back to home so commands don't fail.
    private func effectiveWorkingDirectory() -> String {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: currentDirectory, isDirectory: &isDir), isDir.boolValue {
            return currentDirectory
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if currentDirectory != home {
            addSystemMessage("📂 Working directory no longer exists; using home (~)")
            currentDirectory = home
        }
        return home
    }

    private func runExternalCommand(_ command: String) async {
        isRunning = true

        let workDir = effectiveWorkingDirectory()

        // Wrap the command with environment overrides
        let wrappedCommand = """
        export PAGER=cat
        export GIT_PAGER=cat
        export MANPAGER=cat
        export TERM=dumb
        export NO_COLOR=1
        export GIT_TERMINAL_PROMPT=0
        export CLICOLOR=0
        export COLUMNS=120
        \(command) 2>&1
        """

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", wrappedCommand]
        process.currentDirectoryURL = URL(fileURLWithPath: workDir)
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice
        process.environment = buildEnvironment()

        currentProcess = process

        // Set a timeout so commands can't hang forever (2 min allows curl | bash etc.)
        let timeoutSeconds: Double = 120
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            if process.isRunning {
                process.terminate()
                await MainActor.run {
                    addErrorMessage("⏰ Command timed out after \(Int(timeoutSeconds)) seconds")
                    addSystemMessage("💡 The command took too long. This might be because:")
                    addSystemMessage("   • It's an interactive command (requires user input)")
                    addSystemMessage("   • It's trying to open a pager (like less/more)")
                    addSystemMessage("   • It's actually just slow (try running it again)")
                    addSystemMessage("   • Try adding specific flags to limit output")
                }
            }
        }

        do {
            try process.run()

            // Read output on background thread
            let stdoutData: Data
            let stderrData: Data

            (stdoutData, stderrData) = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let out = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let err = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    continuation.resume(returning: (out, err))
                }
            }

            // Cancel the timeout
            timeoutTask.cancel()

            // Parse and display stdout
            if let output = String(data: stdoutData, encoding: .utf8), !output.isEmpty {
                let lines = output.components(separatedBy: "\n")
                var lineCount = 0
                let maxLines = 500 // Prevent flooding

                for line in lines {
                    if lineCount >= maxLines {
                        addSystemMessage("⚠️ Output truncated (\(lines.count) total lines). Showing first \(maxLines).")
                        addSystemMessage("💡 Try piping through 'head' or 'tail' to limit output")
                        break
                    }
                    if !line.isEmpty {
                        // Check if this looks like an error (from 2>&1 redirect)
                        if process.terminationStatus != 0 && isActualError(line, exitCode: process.terminationStatus) {
                            outputLines.append(TerminalLine(line, type: .error))
                        } else {
                            outputLines.append(TerminalLine(line, type: .output))
                        }
                        lineCount += 1
                    }
                }
            }

            // Parse and display stderr (some might come through even with 2>&1)
            if let errorOutput = String(data: stderrData, encoding: .utf8), !errorOutput.isEmpty {
                let lines = errorOutput.components(separatedBy: "\n")
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        if isActualError(trimmed, exitCode: process.terminationStatus) {
                            outputLines.append(TerminalLine(trimmed, type: .error))
                        } else {
                            outputLines.append(TerminalLine(trimmed, type: .output))
                        }
                    }
                }
            }

            // Status feedback
            if process.terminationStatus == 0 {
                // Only celebrate occasionally to avoid noise
                if commandCount % 3 == 0 {
                    let celebrations = [
                        "✅ Done!",
                        "✅ Command completed!",
                        "✅ All good!",
                        "✅ Nailed it!",
                        "✅ That worked!",
                    ]
                    addSystemMessage(celebrations.randomElement() ?? "✅ Done!")
                }
            } else {
                // Provide context-specific help
                addErrorMessage("⚠️ Command exited with code \(process.terminationStatus)")
                let helpMessage = getErrorHelp(for: command, exitCode: process.terminationStatus)
                addSystemMessage(helpMessage)
            }

        } catch {
            timeoutTask.cancel()
            addErrorMessage("❌ Failed to run command: \(error.localizedDescription)")

            // Give specific, helpful advice
            let errDesc = error.localizedDescription
            let cmdName = command.components(separatedBy: " ").first ?? command
            if errDesc.lowercased().contains("permission") || errDesc.contains("not permitted") || errDesc.contains("Operation not permitted") {
                addSystemMessage("💡 This often means the app is sandboxed and can't run external tools.")
                addSystemMessage("   In Xcode: Target → Signing & Capabilities → disable 'App Sandbox' if you need curl, git, etc.")
                addSystemMessage("   Or try running the command in the system Terminal to confirm it works.")
            } else if errDesc.contains("No such file") || errDesc.contains("doesn't exist") {
                addSystemMessage("💡 The shell or working directory couldn't be used. If this keeps happening, report the bug with the error above.")
            } else {
                addSystemMessage("💡 '\(cmdName)' might not be in PATH. Try: which \(cmdName)")
                addSystemMessage("   Or install with: brew install \(cmdName)")
            }
        }

        isRunning = false
        currentProcess = nil
    }

    // MARK: - Error Analysis
    private func isActualError(_ line: String, exitCode: Int32) -> Bool {
        if exitCode == 0 { return false }

        let errorIndicators = [
            "error:", "Error:", "ERROR:",
            "fatal:", "Fatal:", "FATAL:",
            "failed", "Failed", "FAILED",
            "permission denied", "Permission denied",
            "not found", "Not found",
            "No such file", "no such file",
            "command not found",
            "cannot ", "Cannot ",
            "unable to", "Unable to",
            "denied", "Denied",
            "refused", "Refused",
            "invalid", "Invalid",
        ]

        return errorIndicators.contains(where: { line.contains($0) })
    }

    private func getErrorHelp(for command: String, exitCode: Int32) -> String {
        let cmd = command.lowercased()
        let cmdName = command.components(separatedBy: " ").first ?? command

        if exitCode == 127 {
            return "💡 '\(cmdName)' wasn't found. It might not be installed.\n   Try: brew install \(cmdName)\n   Or check spelling with: which \(cmdName)"
        }

        if exitCode == 126 {
            return "💡 Permission denied — the file can't be executed. Try: chmod +x \(cmdName)"
        }

        if exitCode == 128 {
            return "💡 Invalid exit — the command received a signal. This sometimes just means it was interrupted. Try again."
        }

        if exitCode == 1 && cmd.contains("man ") {
            let manTopic = cmd.replacingOccurrences(of: "man ", with: "")
            return "💡 No manual entry for '\(manTopic)'. Try: help \(manTopic) — or — \(manTopic) --help"
        }

        if cmd.hasPrefix("git") {
            return "💡 Git issue. Start with 'git status' to see where things stand."
        }

        if cmd.hasPrefix("npm") || cmd.hasPrefix("yarn") || cmd.hasPrefix("pnpm") {
            return "💡 Package manager error. Try:\n   1. Delete node_modules: rm -rf node_modules\n   2. Reinstall: npm install"
        }

        if cmd.hasPrefix("python") || cmd.hasPrefix("pip") {
            return "💡 Python error. Check:\n   • Are you in a virtual environment? (python3 -m venv env && source env/bin/activate)\n   • Is the module installed? (pip3 install <module>)"
        }

        if cmd.hasPrefix("swift") || cmd.hasPrefix("xcodebuild") {
            return "💡 Swift/Xcode error. Try:\n   • xcode-select --install (for command line tools)\n   • Clean build: rm -rf .build/ or clean in Xcode"
        }

        return "💡 Don't worry — errors are just clues. Try breaking the command into smaller parts.\n   Or ask: explain '\(command)'"
    }

    // MARK: - Process Control
    func cancelCurrentProcess() {
        if let process = currentProcess, process.isRunning {
            process.terminate()
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if process.isRunning {
                    process.interrupt()
                }
            }
        }
        isRunning = false
        currentProcess = nil
        addSystemMessage("🛑 Process cancelled — that's okay, you can try again when ready")
    }

    // MARK: - History Navigation
    func previousHistoryItem() -> String? {
        guard !commandHistory.isEmpty else { return nil }
        historyIndex = max(0, historyIndex - 1)
        return commandHistory[historyIndex]
    }

    func nextHistoryItem() -> String? {
        guard !commandHistory.isEmpty else { return nil }
        historyIndex = min(commandHistory.count, historyIndex + 1)
        if historyIndex >= commandHistory.count {
            return ""
        }
        return commandHistory[historyIndex]
    }

    // MARK: - Output Helpers
    func addSystemMessage(_ message: String) {
        outputLines.append(TerminalLine(message, type: .system))
    }

    func addSuggestion(_ message: String) {
        outputLines.append(TerminalLine(message, type: .suggestion))
    }

    func addCelebration(_ message: String) {
        outputLines.append(TerminalLine(message, type: .celebration))
    }

    private func addErrorMessage(_ message: String) {
        outputLines.append(TerminalLine(message, type: .error))
    }

    // MARK: - Path Helpers
    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home {
            return "~"
        } else if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    // MARK: - Rainbow Output Helper
    func addRainbowMessage(_ message: String) {
        let seed = Double.random(in: 0..<1)
        outputLines.append(TerminalLine(message, type: .rainbow, rainbowSeed: seed))
    }

    func addRainbowLines(_ lines: [String]) {
        let baseSeed = Double.random(in: 0..<1)
        for (index, line) in lines.enumerated() {
            let lineSeed = (baseSeed + Double(index) * 0.05)
                .truncatingRemainder(dividingBy: 1.0)
            outputLines.append(TerminalLine(line, type: .rainbow, rainbowSeed: lineSeed))
        }
    }

    // MARK: - Help System
    private func showHelp() {
        let helpLines = [
            "",
            "🧠 ═══════════════════════════════════════════",
            "   N E U R O S H E L L   H E L P",
            "🧠 ═══════════════════════════════════════════",
            "",
            "🏠 NeuroShell Built-in Commands:",
            "────────────────────────────────────────────",
            "  help              → Show this help menu",
            "  help <topic>      → Help on a specific topic (e.g., help git)",
            "  man <command>     → Friendly manual page for any command",
            "  explain <command> → Break down what a command does",
            "  clear             → Clear the screen (fresh start!)",
            "  pwd / whereami    → Show current directory",
            "  history           → Show your command history",
            "  alias             → Show all shortcuts",
            "  shortcuts         → Show keyboard shortcuts",
            "  cheatsheet        → Quick reference guides",
            "  cheat <topic>     → Cheatsheet for a topic (git, files, etc.)",
            "",
            "💛 Wellbeing Commands:",
            "────────────────────────────────────────────",
            "  encourage         → Get some encouragement 💪",
            "  breathe           → Guided breathing exercise 🫁",
            "  stuck             → Don't know what to do? Start here.",
            "  panic             → Feeling overwhelmed? I've got you. 🤗",
            "  focus             → Tips for entering focus mode",
            "  tips              → Random productivity tip",
            "  timer             → Use the sidebar timer for focus sessions",
            "  todo              → Use the Task Chunker to break down work",
            "",
            "📂 Common Terminal Commands:",
            "────────────────────────────────────────────",
            "  ls                → List files here",
            "  ls -la            → List ALL files with details",
            "  cd <folder>       → Go into a folder",
            "  cd ..             → Go up one level",
            "  cd ~              → Go home",
            "  cat <file>        → Read a file",
            "  touch <file>      → Create an empty file",
            "  mkdir <name>      → Create a folder",
            "  cp <src> <dest>   → Copy a file",
            "  mv <src> <dest>   → Move or rename",
            "  rm <file>         → Delete (⚠️ no undo!)",
            "  grep 'text' file  → Search in files",
            "  find . -name '*.txt' → Find files by name",
            "",
            "🔀 Git Commands:",
            "────────────────────────────────────────────",
            "  git status        → See what's changed",
            "  git add .         → Stage all changes",
            "  git commit -m ''  → Save a snapshot",
            "  git push          → Upload to GitHub",
            "  git pull          → Download latest",
            "  git log --oneline → See recent history",
            "",
            "ℹ️  System Commands:",
            "────────────────────────────────────────────",
            "  whoami            → Your username",
            "  date              → Current date and time",
            "  df -h             → Disk space",
            "  du -sh *          → Folder sizes",
            "  open .            → Open current folder in Finder",
            "  status / stats    → Your session stats",
            "  version           → NeuroShell version info",
            "",
            "⌨️  Quick Shortcuts:",
            "────────────────────────────────────────────",
            "  ..                → cd ..",
            "  ...               → cd ../..",
            "  ll                → ls -la",
            "  ?                 → help",
            "  h                 → help",
            "",
            "🌈 Lolcat / Rainbow Commands:",
            "────────────────────────────────────────────",
            "  lolcat <text>       → Rainbow-ify any text",
            "  <cmd> | lolcat      → Pipe any command through rainbow",
            "  rainbow test        → Show rainbow color test pattern",
            "  rainbow banner      → NeuroShell ASCII banner in rainbow",
            "  rainbow themes      → List available color themes",
            "  rainbow theme <name>→ Switch to a theme (e.g. rainbow theme fire)",
            "  rainbow on/off      → Enable/disable rainbow mode",
            "  nyan                → Show nyan cat! 🐱",
            "  pride               → Show pride banner 🏳️‍🌈",
            "  sparkle             → Sparkle mode ✨",
            "  cowsay <text>       → Rainbow cow says your text 🐄",
            "  figlet <text>       → Big block-letter ASCII art",
            "",
            "🎯 Tips for ADHD-friendly terminal use:",
            "────────────────────────────────────────────",
            "  • Start with small commands, build up",
            "  • Use the Task Chunker to break big tasks apart (sidebar)",
            "  • Type 'stuck' if you don't know what to do next",
            "  • It's okay to forget commands — I'm here to help!",
            "  • Take breaks! Your brain needs them ☕",
            "  • Try 'man <command>' for a friendly manual page",
            "",
        ]
        for line in helpLines {
            addSystemMessage(line)
        }
    }

    private func showTopicHelp(_ topic: String) {
        let lowered = topic.lowercased()

        // Check if it's a man page topic
        if let manual = friendlyManPages[lowered], !manual.isEmpty {
            addSystemMessage("")
            for line in manual {
                addSystemMessage(line)
            }
            addSystemMessage("")
            return
        }

        // Topic-based help
        switch lowered {
        case "git", "version control":
            addSystemMessage("")
            addSystemMessage("🔀 Git Quick Reference:")
            addSystemMessage("────────────────────────────────────────")
            addSystemMessage("  git status              → What's changed?")
            addSystemMessage("  git add .               → Stage everything")
            addSystemMessage("  git add <file>          → Stage one file")
            addSystemMessage("  git commit -m 'msg'     → Save snapshot")
            addSystemMessage("  git push                → Upload")
            addSystemMessage("  git pull                → Download latest")
            addSystemMessage("  git log --oneline -10   → Recent history")
            addSystemMessage("  git branch              → List branches")
            addSystemMessage("  git checkout -b <name>  → New branch")
            addSystemMessage("  git diff                → See changes")
            addSystemMessage("  git stash               → Temp save")
            addSystemMessage("  git stash pop           → Restore temp save")
            addSystemMessage("")
            addSystemMessage("💡 Typical flow: status → add → commit → push")
            addSystemMessage("")

        case "files", "file":
            addSystemMessage("")
            addSystemMessage("📄 File Operations:")
            addSystemMessage("────────────────────────────────────────")
            addSystemMessage("  cat file.txt            → Read a file")
            addSystemMessage("  touch newfile.txt       → Create empty file")
            addSystemMessage("  cp src.txt dest.txt     → Copy")
            addSystemMessage("  mv old.txt new.txt      → Move/rename")
            addSystemMessage("  rm file.txt             → Delete (⚠️)")
            addSystemMessage("  mkdir folder            → Create folder")
            addSystemMessage("  head -20 file.txt       → First 20 lines")
            addSystemMessage("  tail -20 file.txt       → Last 20 lines")
            addSystemMessage("  wc -l file.txt          → Count lines")
            addSystemMessage("")

        case "navigation", "nav", "navigate", "moving":
            addSystemMessage("")
            addSystemMessage("📂 Navigation:")
            addSystemMessage("────────────────────────────────────────")
            addSystemMessage("  pwd                     → Where am I?")
            addSystemMessage("  ls                      → What's here?")
            addSystemMessage("  cd folder               → Go into folder")
            addSystemMessage("  cd ..                   → Go up")
            addSystemMessage("  cd ~                    → Go home")
            addSystemMessage("  cd -                    → Go back to previous")
            addSystemMessage("  open .                  → Open in Finder")
            addSystemMessage("")

        case "search", "find", "finding":
            addSystemMessage("")
            addSystemMessage("🔍 Searching:")
            addSystemMessage("────────────────────────────────────────")
            addSystemMessage("  find . -name '*.txt'    → Find files by name")
            addSystemMessage("  grep -r 'text' .        → Search file contents")
            addSystemMessage("  grep -rn 'TODO' .       → Search with line numbers")
            addSystemMessage("  which command            → Find where command is")
            addSystemMessage("")

        case "permissions", "permission", "chmod", "access":
            addSystemMessage("")
            addSystemMessage("🔐 Permissions:")
            addSystemMessage("────────────────────────────────────────")
            addSystemMessage("  chmod +x script.sh      → Make executable")
            addSystemMessage("  chmod 644 file          → Read/write for owner, read for others")
            addSystemMessage("  chmod 755 folder        → Full for owner, read/execute for others")
            addSystemMessage("  ls -la                  → See current permissions")
            addSystemMessage("")

        case "network", "internet", "web":
            addSystemMessage("")
            addSystemMessage("🌐 Network:")
            addSystemMessage("────────────────────────────────────────")
            addSystemMessage("  ping -c 3 google.com    → Check connectivity")
            addSystemMessage("  curl -I url             → Check a website")
            addSystemMessage("  ifconfig | grep inet    → Your IP address")
            addSystemMessage("  ssh user@host           → Connect to remote")
            addSystemMessage("")

        case "process", "processes", "running":
            addSystemMessage("")
            addSystemMessage("⚙️ Processes:")
            addSystemMessage("────────────────────────────────────────")
            addSystemMessage("  ps aux | head -20       → Show processes")
            addSystemMessage("  ps aux | grep name      → Find a process")
            addSystemMessage("  kill PID                → Stop a process")
            addSystemMessage("  kill -9 PID             → Force stop")
            addSystemMessage("")

        case "builtin", "builtins", "built-in", "neuroshell", "ns":
            addSystemMessage("")
            addSystemMessage("🧠 NeuroShell Built-in Commands:")
            addSystemMessage("────────────────────────────────────────")
            addSystemMessage("  help, ?, h, commands    → This help")
            addSystemMessage("  clear, cls, c           → Clear screen")
            addSystemMessage("  pwd, whereami, where    → Current directory")
            addSystemMessage("  history                 → Command history")
            addSystemMessage("  alias                   → Show shortcuts")
            addSystemMessage("  encourage               → Motivation boost")
            addSystemMessage("  breathe                 → Breathing exercise")
            addSystemMessage("  stuck                   → When you're stuck")
            addSystemMessage("  panic                   → Overwhelm support")
            addSystemMessage("  tips                    → Random tip")
            addSystemMessage("  cheat <topic>           → Quick reference")
            addSystemMessage("  man <command>           → Friendly manual")
            addSystemMessage("  explain <cmd>           → Break down a command")
            addSystemMessage("  version, about          → App info")
            addSystemMessage("  status, stats           → Session stats")
            addSystemMessage("  shortcuts, keys         → Keyboard shortcuts")
            addSystemMessage("  date, time              → Current time")
            addSystemMessage("  whoami                  → Your username")
            addSystemMessage("  reset                   → Reset session")
            addSystemMessage("")

        default:
            // Try man pages as fallback
            if let manual = friendlyManPages[lowered], !manual.isEmpty {
                addSystemMessage("")
                for line in manual {
                    addSystemMessage(line)
                }
                addSystemMessage("")
            } else {
                addSystemMessage("❓ I don't have specific help for '\(topic)'.")
                addSystemMessage("💡 Try:")
                addSystemMessage("   • man \(topic)     → Manual page")
                addSystemMessage("   • \(topic) --help  → Command's own help")
                addSystemMessage("   • explain \(topic)  → Break it down")
                addSystemMessage("")
                addSystemMessage("📚 Available help topics: git, files, navigation, search,")
                addSystemMessage("   permissions, network, processes, builtins")
            }
        }
    }

    private func showHistory() {
        if commandHistory.isEmpty {
            addSystemMessage("📜 No commands yet — you're just getting started!")
            return
        }

        addSystemMessage("")
        addSystemMessage("📜 Your recent commands:")
        addSystemMessage("────────────────────────────────────────")
        let recentHistory = commandHistory.suffix(20)
        for (index, cmd) in recentHistory.enumerated() {
            let num = commandHistory.count - recentHistory.count + index + 1
            addSystemMessage("  \(String(format: "%3d", num))  \(cmd)")
        }
        addSystemMessage("")
        addSystemMessage("💡 Press ↑/↓ to navigate through history")
        addSystemMessage("")
    }

    private func showEncouragement() {
        let messages = [
            "🌟 You're doing amazing! Every command you type is progress.",
            "💪 Remember: even experienced devs Google basic commands. You're not alone!",
            "🎉 You showed up and opened the terminal — that takes executive function! Be proud.",
            "💛 Your brain works differently, not wrongly. You've got this!",
            "🌈 Progress isn't always linear. Small steps still count!",
            "🧠 Fun fact: many brilliant engineers are neurodivergent. You're in great company!",
            "⭐ You don't have to be productive every second. Being here is enough.",
            "🌱 Learning is messy and that's perfectly okay. Keep going!",
            "💫 The terminal isn't judging you. Neither am I. You're doing great.",
            "🤗 It's okay to feel overwhelmed. Take a breath. One step at a time.",
            "🏆 The fact that you're learning terminal commands? That's badass.",
            "🌻 Your worth isn't measured by your output. You're already enough.",
            "🦋 Every expert was once a beginner. Every. Single. One.",
            "🎭 Imposter syndrome lies. You belong here.",
            "💖 Be as patient with yourself as you'd be with a friend learning this.",
        ]
        addCelebration(messages.randomElement() ?? messages[0])
    }

    private func showBreathingExercise() {
        addSystemMessage("")
        addSystemMessage("🫁 ═══ Quick Breathing Exercise ═══")
        addSystemMessage("")
        addSystemMessage("   Follow this pattern:")
        addSystemMessage("")
        addSystemMessage("   🌬️  Breathe IN  ............  4 seconds")
        addSystemMessage("   ⏸️  Hold        ............  4 seconds")
        addSystemMessage("   💨 Breathe OUT ............  6 seconds")
        addSystemMessage("   ⏸️  Hold        ............  2 seconds")
        addSystemMessage("")
        addSystemMessage("   Repeat 3-4 times. No rush.")
        addSystemMessage("")
        addSystemMessage("   You can also try the guided breathing")
        addSystemMessage("   exercise in the sidebar → 🫁")
        addSystemMessage("")
        addSystemMessage("   Remember: your body is part of the system too. 💛")
        addSystemMessage("")
    }

    private func showAliases() {
        addSystemMessage("")
        addSystemMessage("📝 Your Aliases (shortcuts):")
        addSystemMessage("────────────────────────────────────────")
        let sortedAliases = aliases.sorted(by: { $0.key < $1.key })
        for (name, target) in sortedAliases {
            addSystemMessage("  \(String(format: "%-12s", (name as NSString).utf8String!)) → \(target)")
        }
        addSystemMessage("")
        addSystemMessage("💡 Create custom alias: alias name='command'")
        addSystemMessage("💡 Remove alias: unalias name")
        addSystemMessage("")
    }

    private func handleAliasCommand(_ command: String) {
        // alias name='command' or alias name=command
        let stripped = command.dropFirst(6).trimmingCharacters(in: .whitespacesAndNewlines) // remove "alias "
        if let eqIndex = stripped.firstIndex(of: "=") {
            let name = String(stripped[stripped.startIndex..<eqIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            var value = String(stripped[stripped.index(after: eqIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            // Remove surrounding quotes
            if (value.hasPrefix("'") && value.hasSuffix("'")) || (value.hasPrefix("\"") && value.hasSuffix("\"")) {
                value = String(value.dropFirst().dropLast())
            }
            aliases[name] = value
            addSystemMessage("✅ Alias created: \(name) → \(value)")
        } else {
            addSystemMessage("💡 Usage: alias name='command'")
            addSystemMessage("   Example: alias gs='git status'")
        }
    }

    private func showVersion() {
        addSystemMessage("")
        addSystemMessage("🧠 NeuroShell v1.0.0")
        addSystemMessage("   The terminal that gets your brain")
        addSystemMessage("")
        addSystemMessage("   Built with 💛 for ADHD & AuDHD minds")
        addSystemMessage("   macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        addSystemMessage("   Shell: /bin/zsh")
        addSystemMessage("")
    }

    private func showRandomTip() {
        let tips = [
            "🎯 Use Tab to auto-complete commands and file names — saves typing AND typos!",
            "🎯 Press ↑ to recall your last command — no need to retype!",
            "🎯 'cd -' takes you back to where you just were — like browser back button",
            "🎯 Add 'man' before any command to learn about it (e.g., 'man grep')",
            "🎯 You can use * as a wildcard: ls *.txt shows all text files",
            "🎯 Ctrl+C cancels the current command — your emergency stop button",
            "🎯 Ctrl+L clears the screen — same as typing 'clear'",
            "🎯 Use 'open .' to open the current folder in Finder",
            "🎯 Chain commands with &&: mkdir test && cd test (both run in order)",
            "🎯 Use 'history' to see what you've done — great for remembering steps",
            "🎯 'pwd | pbcopy' copies your current path to clipboard",
            "🎯 You don't need to memorize everything. That's what 'help' is for!",
            "🎯 Start small. 'ls' and 'cd' are enough to explore your whole computer.",
            "🎯 Mistakes in the terminal are usually fixable. Don't be afraid to try things!",
            "🎯 If a command hangs, Ctrl+C will stop it. You're always in control.",
            "🎯 'cat file.txt | head -5' shows just the first 5 lines — great for long files",
            "🎯 Use the Task Chunker (sidebar) to break overwhelming tasks into tiny steps",
            "🎯 Set a 25-minute timer, pick ONE task, and tell yourself 'just this one thing'",
            "🎯 It's okay to use the mouse. The keyboard is faster, but the mouse still works!",
            "🎯 Write down what you're doing before you start — ADHD brains forget mid-task!",
        ]
        addSystemMessage("")
        addSystemMessage(tips.randomElement() ?? tips[0])
        addSystemMessage("")
    }

    private func showSessionStats() {
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        let minutes = Int(sessionDuration) / 60
        let seconds = Int(sessionDuration) % 60

        addSystemMessage("")
        addSystemMessage("📊 Session Stats:")
        addSystemMessage("────────────────────────────────────────")
        addSystemMessage("  ⏱️  Session duration: \(minutes)m \(seconds)s")
        addSystemMessage("  🔢 Commands entered: \(commandCount)")
        addSystemMessage("  📂 Current directory: \(shortenPath(currentDirectory))")
        addSystemMessage("  📜 History items: \(commandHistory.count)")
        addSystemMessage("  📝 Aliases defined: \(aliases.count)")
        addSystemMessage("  📄 Output lines: \(outputLines.count)")
        addSystemMessage("")

        if minutes > 45 {
            addSystemMessage("  ⚠️ You've been at it for a while! Consider taking a break. 🧘")
        } else if minutes > 25 {
            addSystemMessage("  💡 Solid session! Maybe a quick stretch? Your body will thank you.")
        } else {
            addSystemMessage("  ✨ Good pacing! You're doing great.")
        }
        addSystemMessage("")
    }

    private func showKeyboardShortcuts() {
        addSystemMessage("")
        addSystemMessage("⌨️  Keyboard Shortcuts:")
        addSystemMessage("────────────────────────────────────────")
        addSystemMessage("  ↑ / ↓        → Navigate command history")
        addSystemMessage("  Tab          → Auto-complete suggestion")
        addSystemMessage("  Ctrl + C     → Cancel running command")
        addSystemMessage("  Ctrl + L     → Clear screen")
        addSystemMessage("  Ctrl + A     → Jump to start of line")
        addSystemMessage("  Ctrl + E     → Jump to end of line")
        addSystemMessage("  Ctrl + U     → Clear the current line")
        addSystemMessage("  Ctrl + K     → Delete to end of line")
        addSystemMessage("  Escape       → Clear input")
        addSystemMessage("  Return       → Execute command")
        addSystemMessage("")
    }

    private func showEnvironment() {
        addSystemMessage("")
        addSystemMessage("🌍 Key Environment Info:")
        addSystemMessage("────────────────────────────────────────")
        addSystemMessage("  HOME:    \(FileManager.default.homeDirectoryForCurrentUser.path)")
        addSystemMessage("  USER:    \(NSUserName())")
        addSystemMessage("  SHELL:   /bin/zsh")
        addSystemMessage("  CWD:     \(currentDirectory)")

        // Show if common tools are available
        let tools = ["/opt/homebrew/bin/brew", "/usr/bin/git", "/usr/bin/python3", "/usr/local/bin/node"]
        var found: [String] = []
        for tool in tools {
            if FileManager.default.fileExists(atPath: tool) {
                let name = (tool as NSString).lastPathComponent
                found.append(name)
            }
        }
        if !found.isEmpty {
            addSystemMessage("  Tools:   \(found.joined(separator: ", "))")
        }
        addSystemMessage("")
    }

    private func showStuckHelp() {
        addSystemMessage("")
        addSystemMessage("🤔 Feeling stuck? That's completely okay! Let's figure this out.")
        addSystemMessage("────────────────────────────────────────")
        addSystemMessage("")
        addSystemMessage("  1️⃣  Where are you?")
        addSystemMessage("     → Type 'pwd' to see your current location")
        addSystemMessage("     → Type 'ls' to see what's around you")
        addSystemMessage("")
        addSystemMessage("  2️⃣  What were you trying to do?")
        addSystemMessage("     → Type 'history' to see your recent commands")
        addSystemMessage("     → Click 'Where was I?' in the top bar")
        addSystemMessage("")
        addSystemMessage("  3️⃣  What do you want to do next?")
        addSystemMessage("     → Type what you want in plain English")
        addSystemMessage("     → Use the Task Chunker (sidebar) to break it down")
        addSystemMessage("     → Type 'help <topic>' for guidance")
        addSystemMessage("")
        addSystemMessage("  4️⃣  Still stuck?")
        addSystemMessage("     → That's okay! Take a break. Come back fresh.")
        addSystemMessage("     → Type 'breathe' for a quick breathing exercise")
        addSystemMessage("     → Type 'encourage' for a pep talk 💛")
        addSystemMessage("")
    }

    private func showPanicHelp() {
        addSystemMessage("")
        addSystemMessage("🤗 ═══ Hey, I've got you. Let's slow down. ═══")
        addSystemMessage("")
        addSystemMessage("  First: Nothing is on fire. Computers are patient. 🖥️")
        addSystemMessage("")
        addSystemMessage("  🫁 Take 3 slow breaths:")
        addSystemMessage("     In... 2... 3... 4...")
        addSystemMessage("     Hold... 2... 3... 4...")
        addSystemMessage("     Out... 2... 3... 4... 5... 6...")
        addSystemMessage("")
        addSystemMessage("  ✅ Nothing you type here can break the internet.")
        addSystemMessage("  ✅ You can always undo, go back, or start over.")
        addSystemMessage("  ✅ 'rm' is the only risky command, and you can avoid it for now.")
        addSystemMessage("  ✅ Everything else is safe to experiment with.")
        addSystemMessage("")
        addSystemMessage("  When you're ready:")
        addSystemMessage("  • Type 'pwd' to see where you are")
        addSystemMessage("  • Type 'ls' to look around")
        addSystemMessage("  • Type 'help' for guidance")
        addSystemMessage("  • Type 'encourage' for support")
        addSystemMessage("")
        addSystemMessage("  You are safe. You are capable. You've got this. 💛")
        addSystemMessage("")
    }

    // MARK: - Lolcat / Rainbow Commands

    private func showLolcatHelp() {
        addSystemMessage("")
        addRainbowMessage("🌈 ═══ L O L C A T   M O D E ═══ 🌈")
        addSystemMessage("")
        addSystemMessage("Usage:")
        addSystemMessage("  lolcat <text>           → Rainbow-ify any text")
        addSystemMessage("  <command> | lolcat      → Pipe command output through rainbow")
        addSystemMessage("  rainbow test            → Show rainbow color test")
        addSystemMessage("  rainbow banner          → Show NeuroShell banner in rainbow")
        addSystemMessage("  rainbow themes          → List available color themes")
        addSystemMessage("  rainbow theme <name>    → Switch theme (e.g. rainbow theme fire)")
        addSystemMessage("  rainbow on / off        → Enable/disable rainbow mode")
        addSystemMessage("  nyan                    → Show nyan cat!")
        addSystemMessage("  pride                   → Show pride banner")
        addSystemMessage("  sparkle                 → Show sparkles ✨")
        addSystemMessage("  cowsay <text>           → Cow says your text (in rainbow!)")
        addSystemMessage("  figlet <text>           → Big ASCII text in rainbow")
        addSystemMessage("")
        if let renderer = lolcatRenderer {
            addSystemMessage("Current theme: \(renderer.currentTheme.emoji) \(renderer.currentTheme.rawValue)")
            addSystemMessage("")
        }
        addSystemMessage("Examples:")
        addSystemMessage("  lolcat Hello World!")
        addSystemMessage("  ls -la | lolcat")
        addSystemMessage("  git log --oneline | lolcat")
        addSystemMessage("  echo 'I am fabulous' | rainbow")
        addSystemMessage("  cat README.md | nyan")
        addSystemMessage("  rainbow theme vaporwave")
        addSystemMessage("  rainbow theme candy")
        addSystemMessage("")
        addRainbowMessage("✨ Everything is better in rainbow! ✨")
        addSystemMessage("")
    }

    private func showRainbowTest() {
        addSystemMessage("")
        addRainbowMessage("🌈 ═══════════════════════════════════════════════ 🌈")
        addRainbowMessage("   R A I N B O W   T E S T   P A T T E R N")
        addRainbowMessage("🌈 ═══════════════════════════════════════════════ 🌈")
        addRainbowMessage("")
        addRainbowLines([
            "████████████████████████████████████████████████",
            "████████████████████████████████████████████████",
            "▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓",
            "▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒",
            "░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░",
        ])
        addRainbowMessage("")
        addRainbowMessage("ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 !@#$%^&*()")
        addRainbowMessage("The quick brown fox jumps over the lazy dog 🦊🐕")
        addRainbowMessage("")
        addRainbowMessage(LolcatRenderer.randomSaying())
        addSystemMessage("")
    }

    private func showRainbowBanner() {
        addSystemMessage("")
        addRainbowLines(LolcatRenderer.neuroShellBanner)
        addRainbowMessage("")
        addRainbowMessage("  The terminal that gets your brain 🧠✨")
        addSystemMessage("")
    }

    private func showRainbowThemes() {
        addSystemMessage("")
        addRainbowMessage("🎨 Available Rainbow Themes:")
        addSystemMessage("────────────────────────────────────────")

        let currentTheme = lolcatRenderer?.currentTheme ?? .classic

        for themeInfo in LolcatRenderer.themeNames {
            let marker = themeInfo.theme == currentTheme ? " ◀ active" : ""
            addSystemMessage("  \(themeInfo.label)\(marker)")
        }

        addSystemMessage("")
        addSystemMessage("💡 Switch theme: rainbow theme <name>")
        addSystemMessage("   Example: rainbow theme fire")
        addSystemMessage("   Or change it in Settings → Lolcat tab")
        addSystemMessage("")
    }

    private func applyTheme(_ themeName: String) {
        addSystemMessage("")
        let lowered = themeName.lowercased()

        if let matched = LolcatRenderer.Theme.allCases.first(where: {
            $0.rawValue.lowercased().contains(lowered) ||
            $0.rawValue.lowercased().replacingOccurrences(of: " ", with: "") == lowered ||
            String(describing: $0).lowercased() == lowered
        }) {
            if let renderer = lolcatRenderer {
                renderer.currentTheme = matched
                addRainbowMessage("\(matched.emoji) Theme switched to: \(matched.rawValue)")
                addRainbowMessage("✨ All rainbow output now uses the \(matched.rawValue) theme!")
            } else {
                addErrorMessage("⚠️ Rainbow renderer not connected — theme can't be changed right now")
            }
        } else {
            addSystemMessage("❓ Unknown theme '\(themeName)'")
            addSystemMessage("   Try: rainbow themes — to see all available themes")
            addSystemMessage("   Hint: use part of the name, e.g. 'fire', 'ocean', 'trans', 'candy'")
        }
        addSystemMessage("")
    }

    private func showNyanCat() {
        addSystemMessage("")
        addRainbowLines([
            "░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░",
            "░░░░░░░░░░▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄░░░░░░░░░░░░░░░░░░░░░░░░░░",
            "░░░░░░░░▄▀░░░░░░░░░░░░▄░░░░░░░▀▄░░░░░░░░░░░░░░░░░░░░░░░░",
            "░░░░░░░░│░░▄░░░░▄░░░░░░░░░░░░░░░█░░░░░░░░░░░░░░░░░░░░░░░░",
            "░░░░░░░░│░░░░░░░░░░░░▄█▄▄░░▄░░░░█░▄▄▄░░░░░░░░░░░░░░░░░░░",
            "░░░░░░░░│░░░░░░░░▀░░░▀██░░░░░░░░▀▄▄▄▀▄▀▀▄▀▀▄▀▀▄▀▀▄▀▀▄░░░",
            "░░░░░░░░│░▄░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░",
            "░░░░░░░░▀░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░",
        ])
        addRainbowMessage("")
        addRainbowMessage("  ♪ ♫ Nyan nyan nyan nyan nyan nyan nyan ♫ ♪")
        addRainbowMessage("")
        addRainbowLines(LolcatRenderer.catFace)
        addRainbowMessage("")
        addRainbowMessage(LolcatRenderer.randomSaying())
        addSystemMessage("")
    }

    private func showPrideBanner() {
        addSystemMessage("")
        // Render each stripe of the classic pride flag
        let flagLines = [
            "  ████████████████████████████████████████████  ",
            "  ████████████████████████████████████████████  ",
            "  ████████████████████████████████████████████  ",
            "  ████████████████████████████████████████████  ",
            "  ████████████████████████████████████████████  ",
            "  ████████████████████████████████████████████  ",
        ]
        addRainbowLines(flagLines)
        addRainbowMessage("")
        addRainbowMessage("   🏳️‍🌈  You are valid. You are loved. You belong here.  🏳️‍🌈")
        addSystemMessage("")
    }

    private func showSparkles() {
        addSystemMessage("")
        addRainbowLines(LolcatRenderer.sparkles)
        addRainbowMessage("")
        addRainbowLines([
            "  ✨ ★ · ✦ · ★ ✨ · ✧ · ✨ ★ · ✦ · ★ ✨",
            "  · ✧ · ✨ SPARKLE MODE ACTIVATED ✨ · ✧ ·",
            "  ✨ ★ · ✦ · ★ ✨ · ✧ · ✨ ★ · ✦ · ★ ✨",
        ])
        addRainbowMessage("")
        addRainbowMessage(LolcatRenderer.randomSaying())
        addSystemMessage("")
    }

    private func showCowsay(_ text: String) {
        let maxLen = max(text.count, 2)
        let border = String(repeating: "─", count: maxLen + 2)
        let padded = text.padding(toLength: maxLen, withPad: " ", startingAt: 0)

        addSystemMessage("")
        addRainbowLines([
            " ┌\(border)┐",
            " │ \(padded) │",
            " └\(border)┘",
            "        \\   ^__^",
            "         \\  (oo)\\_______",
            "            (__)\\       )\\/\\",
            "                ||----w |",
            "                ||     ||",
        ])
        addSystemMessage("")
    }

    private func showFiglet(_ text: String) {
        // Simple block letter rendering for short text
        let blockLetters: [Character: [String]] = [
            "A": ["  █  ", " █ █ ", "█████", "█   █", "█   █"],
            "B": ["████ ", "█   █", "████ ", "█   █", "████ "],
            "C": [" ████", "█    ", "█    ", "█    ", " ████"],
            "D": ["████ ", "█   █", "█   █", "█   █", "████ "],
            "E": ["█████", "█    ", "████ ", "█    ", "█████"],
            "F": ["█████", "█    ", "████ ", "█    ", "█    "],
            "G": [" ████", "█    ", "█  ██", "█   █", " ████"],
            "H": ["█   █", "█   █", "█████", "█   █", "█   █"],
            "I": ["█████", "  █  ", "  █  ", "  █  ", "█████"],
            "J": ["█████", "   █ ", "   █ ", "█  █ ", " ██  "],
            "K": ["█  █ ", "█ █  ", "██   ", "█ █  ", "█  █ "],
            "L": ["█    ", "█    ", "█    ", "█    ", "█████"],
            "M": ["█   █", "██ ██", "█ █ █", "█   █", "█   █"],
            "N": ["█   █", "██  █", "█ █ █", "█  ██", "█   █"],
            "O": [" ███ ", "█   █", "█   █", "█   █", " ███ "],
            "P": ["████ ", "█   █", "████ ", "█    ", "█    "],
            "Q": [" ███ ", "█   █", "█ █ █", "█  █ ", " ██ █"],
            "R": ["████ ", "█   █", "████ ", "█ █  ", "█  ██"],
            "S": [" ████", "█    ", " ███ ", "    █", "████ "],
            "T": ["█████", "  █  ", "  █  ", "  █  ", "  █  "],
            "U": ["█   █", "█   █", "█   █", "█   █", " ███ "],
            "V": ["█   █", "█   █", "█   █", " █ █ ", "  █  "],
            "W": ["█   █", "█   █", "█ █ █", "██ ██", "█   █"],
            "X": ["█   █", " █ █ ", "  █  ", " █ █ ", "█   █"],
            "Y": ["█   █", " █ █ ", "  █  ", "  █  ", "  █  "],
            "Z": ["█████", "   █ ", "  █  ", " █   ", "█████"],
            " ": ["     ", "     ", "     ", "     ", "     "],
            "!": ["  █  ", "  █  ", "  █  ", "     ", "  █  "],
            "?": [" ███ ", "█   █", "  ██ ", "     ", "  █  "],
            "0": [" ███ ", "█  ██", "█ █ █", "██  █", " ███ "],
            "1": [" █   ", "██   ", " █   ", " █   ", "████ "],
            "2": [" ███ ", "█   █", "  ██ ", " █   ", "█████"],
            "3": [" ███ ", "█   █", "  ██ ", "█   █", " ███ "],
            "4": ["█   █", "█   █", "█████", "    █", "    █"],
            "5": ["█████", "█    ", "████ ", "    █", "████ "],
            "6": [" ████", "█    ", "████ ", "█   █", " ███ "],
            "7": ["█████", "    █", "   █ ", "  █  ", "  █  "],
            "8": [" ███ ", "█   █", " ███ ", "█   █", " ███ "],
            "9": [" ███ ", "█   █", " ████", "    █", "████ "],
        ]

        let upperText = text.uppercased().prefix(12) // Limit to 12 chars to avoid overflow
        var outputRows: [String] = ["", "", "", "", ""]

        for char in upperText {
            if let glyph = blockLetters[char] {
                for row in 0..<5 {
                    outputRows[row] += glyph[row] + " "
                }
            } else {
                // Unknown character — render as space
                for row in 0..<5 {
                    outputRows[row] += "     " + " "
                }
            }
        }

        addSystemMessage("")
        addRainbowLines(outputRows)
        addSystemMessage("")
    }

    private func showEmojiReference() {
        addSystemMessage("")
        addSystemMessage("NeuroShell Emoji Guide:")
        addSystemMessage("────────────────────────────────────────")
        addSystemMessage("  ❯         → Your input prompt")
        addSystemMessage("  📂        → Directory/folder info")
        addSystemMessage("  📄        → File info")
        addSystemMessage("  ✅        → Success!")
        addSystemMessage("  ❌        → Error occurred")
        addSystemMessage("  ⚠️        → Warning / heads up")
        addSystemMessage("  💡        → Helpful suggestion")
        addSystemMessage("  🧠        → NeuroShell system info")
        addSystemMessage("  🛑        → Process stopped")
        addSystemMessage("  ⏰        → Timeout")
        addSystemMessage("  🌟        → Encouragement")
        addSystemMessage("")
    }

    private func showCheatSheetIndex() {
        addSystemMessage("")
        addSystemMessage("📋 Cheat Sheets Available:")
        addSystemMessage("────────────────────────────────────────")
        addSystemMessage("  cheat git       → Git workflow")
        addSystemMessage("  cheat files     → File operations")
        addSystemMessage("  cheat nav       → Navigation")
        addSystemMessage("  cheat search    → Finding things")
        addSystemMessage("  cheat perms     → Permissions")
        addSystemMessage("  cheat pipes     → Pipes and redirection")
        addSystemMessage("  cheat npm       → Node.js / npm")
        addSystemMessage("  cheat python    → Python")
        addSystemMessage("  cheat brew      → Homebrew")
        addSystemMessage("")
    }

    private func showCheatSheet(for topic: String) {
        let lowered = topic.lowercased()

        switch lowered {
        case "git":
            addSystemMessage("")
            addSystemMessage("📋 GIT CHEAT SHEET")
            addSystemMessage("════════════════════════════════════════")
            addSystemMessage("")
            addSystemMessage("Daily Workflow:")
            addSystemMessage("  git status              → See what changed")
            addSystemMessage("  git add .               → Stage everything")
            addSystemMessage("  git commit -m 'message' → Save snapshot")
            addSystemMessage("  git push                → Upload to remote")
            addSystemMessage("")
            addSystemMessage("Branches:")
            addSystemMessage("  git branch              → List branches")
            addSystemMessage("  git checkout -b name    → Create + switch")
            addSystemMessage("  git checkout main       → Switch to main")
            addSystemMessage("  git merge branch        → Merge into current")
            addSystemMessage("")
            addSystemMessage("Undo / Fix:")
            addSystemMessage("  git stash               → Save work temporarily")
            addSystemMessage("  git stash pop           → Restore saved work")
            addSystemMessage("  git checkout -- file    → Discard file changes")
            addSystemMessage("  git reset HEAD file     → Unstage a file")
            addSystemMessage("")

        case "files", "file":
            addSystemMessage("")
            addSystemMessage("📋 FILES CHEAT SHEET")
            addSystemMessage("════════════════════════════════════════")
            addSystemMessage("")
            addSystemMessage("  cat file        → Read")
            addSystemMessage("  touch file      → Create empty")
            addSystemMessage("  cp a b          → Copy a → b")
            addSystemMessage("  mv a b          → Move/rename a → b")
            addSystemMessage("  rm file         → Delete (⚠️)")
            addSystemMessage("  mkdir dir       → New folder")
            addSystemMessage("  rm -r dir       → Delete folder (⚠️⚠️)")
            addSystemMessage("  head -n 10 file → First 10 lines")
            addSystemMessage("  tail -n 10 file → Last 10 lines")
            addSystemMessage("  wc -l file      → Count lines")
            addSystemMessage("")

        case "nav", "navigation":
            addSystemMessage("")
            addSystemMessage("📋 NAVIGATION CHEAT SHEET")
            addSystemMessage("════════════════════════════════════════")
            addSystemMessage("")
            addSystemMessage("  pwd             → Where am I?")
            addSystemMessage("  ls              → What's here?")
            addSystemMessage("  ls -la          → Everything with details")
            addSystemMessage("  cd folder       → Go into folder")
            addSystemMessage("  cd ..           → Go up one level")
            addSystemMessage("  cd ../..        → Go up two levels")
            addSystemMessage("  cd ~            → Go home")
            addSystemMessage("  cd -            → Go to previous dir")
            addSystemMessage("  open .          → Open in Finder")
            addSystemMessage("")

        case "search", "searching", "find", "grep":
            addSystemMessage("")
            addSystemMessage("📋 SEARCH CHEAT SHEET")
            addSystemMessage("════════════════════════════════════════")
            addSystemMessage("")
            addSystemMessage("By name:")
            addSystemMessage("  find . -name '*.txt'        → Find .txt files")
            addSystemMessage("  find . -name 'README*'      → Starts with README")
            addSystemMessage("  find . -type d -name test   → Find folders named test")
            addSystemMessage("")
            addSystemMessage("By content:")
            addSystemMessage("  grep 'text' file.txt        → In one file")
            addSystemMessage("  grep -r 'text' .            → In all files")
            addSystemMessage("  grep -rn 'text' .           → With line numbers")
            addSystemMessage("  grep -ri 'text' .           → Case insensitive")
            addSystemMessage("")

        case "perms", "permissions", "permission", "chmod":
            addSystemMessage("")
            addSystemMessage("📋 PERMISSIONS CHEAT SHEET")
            addSystemMessage("════════════════════════════════════════")
            addSystemMessage("")
            addSystemMessage("  chmod +x file       → Make executable")
            addSystemMessage("  chmod 644 file      → rw-r--r-- (typical file)")
            addSystemMessage("  chmod 755 folder    → rwxr-xr-x (typical folder)")
            addSystemMessage("  chmod 600 secret    → rw------- (private)")
            addSystemMessage("  ls -la              → See permissions")
            addSystemMessage("")
            addSystemMessage("  r=4  w=2  x=1  (add up for each: owner|group|others)")
            addSystemMessage("")

        case "pipes", "pipe", "redirect", "redirection":
            addSystemMessage("")
            addSystemMessage("📋 PIPES & REDIRECTION CHEAT SHEET")
            addSystemMessage("════════════════════════════════════════")
            addSystemMessage("")
            addSystemMessage("  cmd > file      → Output to file (overwrites!)")
            addSystemMessage("  cmd >> file     → Append to file")
            addSystemMessage("  cmd < file      → Read input from file")
            addSystemMessage("  cmd1 | cmd2     → Pipe output of cmd1 into cmd2")
            addSystemMessage("  cmd 2>&1        → Merge stderr into stdout")
            addSystemMessage("")
            addSystemMessage("  Common patterns:")
            addSystemMessage("  ls | grep txt           → Filter ls output")
            addSystemMessage("  cat file | sort | uniq  → Sort and deduplicate")
            addSystemMessage("  ps aux | grep python    → Find Python processes")
            addSystemMessage("  history | tail -20      → Last 20 commands")
            addSystemMessage("")

        case "npm", "node", "nodejs":
            addSystemMessage("")
            addSystemMessage("📋 NPM CHEAT SHEET")
            addSystemMessage("════════════════════════════════════════")
            addSystemMessage("")
            addSystemMessage("  npm init              → New project")
            addSystemMessage("  npm install           → Install dependencies")
            addSystemMessage("  npm install pkg       → Add a package")
            addSystemMessage("  npm install -D pkg    → Add dev dependency")
            addSystemMessage("  npm start             → Run start script")
            addSystemMessage("  npm test              → Run tests")
            addSystemMessage("  npm run build         → Build project")
            addSystemMessage("  npm list              → See installed")
            addSystemMessage("  npm outdated          → Check for updates")
            addSystemMessage("  npx command           → Run without installing")
            addSystemMessage("")

        case "python", "py":
            addSystemMessage("")
            addSystemMessage("📋 PYTHON CHEAT SHEET")
            addSystemMessage("════════════════════════════════════════")
            addSystemMessage("")
            addSystemMessage("  python3 script.py         → Run a script")
            addSystemMessage("  python3 -m venv myenv     → Create virtual env")
            addSystemMessage("  source myenv/bin/activate → Activate venv")
            addSystemMessage("  deactivate                → Leave venv")
            addSystemMessage("  pip3 install package      → Install package")
            addSystemMessage("  pip3 freeze > req.txt     → Save dependencies")
            addSystemMessage("  pip3 install -r req.txt   → Install from file")
            addSystemMessage("  python3 --version         → Check version")
            addSystemMessage("")

        case "brew", "homebrew":
            addSystemMessage("")
            addSystemMessage("📋 HOMEBREW CHEAT SHEET")
            addSystemMessage("════════════════════════════════════════")
            addSystemMessage("")
            addSystemMessage("  brew search name      → Search packages")
            addSystemMessage("  brew install name     → Install")
            addSystemMessage("  brew uninstall name   → Remove")
            addSystemMessage("  brew update           → Update Homebrew")
            addSystemMessage("  brew upgrade          → Upgrade packages")
            addSystemMessage("  brew list             → Installed packages")
            addSystemMessage("  brew info name        → Package details")
            addSystemMessage("  brew doctor           → Diagnose problems")
            addSystemMessage("  brew cleanup          → Remove old versions")
            addSystemMessage("")

        default:
            addSystemMessage("❓ No cheat sheet for '\(topic)'. Available: git, files, nav, search, perms, pipes, npm, python, brew")
        }
    }

    private func explainCommand(_ command: String) {
        let parts = command.components(separatedBy: " ")
        guard !parts.isEmpty else { return }

        addSystemMessage("")
        addSystemMessage("🔍 Breaking down: '\(command)'")
        addSystemMessage("────────────────────────────────────────")

        for (index, part) in parts.enumerated() {
            let explanation = explainPart(part, position: index, allParts: parts)
            if !explanation.isEmpty {
                addSystemMessage("  \(part)  →  \(explanation)")
            }
        }
        addSystemMessage("")
    }

    private func explainPart(_ part: String, position: Int, allParts: [String]) -> String {
        // Command names (position 0)
        if position == 0 {
            let explanations: [String: String] = [
                "ls": "List directory contents",
                "cd": "Change directory",
                "pwd": "Print working directory",
                "cat": "Display file contents",
                "cp": "Copy files",
                "mv": "Move or rename",
                "rm": "Delete files (⚠️ no undo!)",
                "mkdir": "Make a new directory",
                "touch": "Create an empty file",
                "grep": "Search for text in files",
                "find": "Find files by name/attributes",
                "chmod": "Change file permissions",
                "chown": "Change file ownership",
                "echo": "Print text to screen",
                "head": "Show beginning of file",
                "tail": "Show end of file",
                "wc": "Count words/lines/bytes",
                "sort": "Sort lines of text",
                "uniq": "Remove duplicate lines",
                "tar": "Archive/compress files",
                "curl": "Download from URL",
                "git": "Version control",
                "npm": "Node.js package manager",
                "pip": "Python package manager",
                "pip3": "Python 3 package manager",
                "brew": "Homebrew package manager",
                "sudo": "⚡ Run as administrator",
                "ssh": "Secure remote login",
                "scp": "Secure file copy",
                "man": "Show manual page",
                "which": "Find command location",
                "xargs": "Build commands from input",
                "awk": "Text processing",
                "sed": "Stream text editor",
                "nano": "Simple text editor",
                "vim": "Advanced text editor",
                "open": "Open with default app",
                "kill": "Stop a process",
                "ps": "Show processes",
                "df": "Show disk space",
                "du": "Show folder sizes",
                "ping": "Test network connection",
            ]
            return explanations[part] ?? "Command: \(part)"
        }

        // Common flags
        if part.hasPrefix("-") || part.hasPrefix("--") {
            let flagExplanations: [String: String] = [
                "-l": "long format (show details)",
                "-a": "show ALL files (including hidden)",
                "-la": "long format + all files",
                "-h": "human-readable sizes",
                "-r": "recursive (include subfolders)",
                "-R": "recursive (include subfolders)",
                "-f": "force (don't ask for confirmation)",
                "-v": "verbose (show what's happening)",
                "-i": "interactive (ask before each action)",
                "-n": "show line numbers",
                "-c": "count",
                "-w": "word count",
                "-p": "create parent directories",
                "-x": "extract",
                "-z": "use gzip compression",
                "-o": "output to file",
                "-e": "pattern/expression",
                "-d": "directory",
                "-s": "summary / silent",
                "-t": "sort by time",
                "-S": "sort by size",
                "-u": "unique only",
                "--help": "show help for this command",
                "--version": "show version",
                "--oneline": "one line per item",
                "--all": "show everything",
                "--force": "force the action",
                "--recursive": "include subfolders",
                "--verbose": "show details",
                "--dry-run": "preview without doing anything",
                "-m": "message follows",
                "-b": "branch name follows",
                "-g": "global",
                "-D": "dev dependency",
                "--staged": "show staged changes",
                "--cached": "same as --staged",
            ]
            return flagExplanations[part] ?? "option flag"
        }

        // Special characters
        switch part {
        case "|": return "PIPE: send output to next command"
        case ">": return "WRITE output to file (overwrites!)"
        case ">>": return "APPEND output to file"
        case "<": return "READ input from file"
        case "2>&1": return "include error messages in output"
        case "&&": return "AND: run next command if this succeeds"
        case "||": return "OR: run next command if this fails"
        case ".": return "current directory"
        case "..": return "parent directory"
        case "~": return "home directory"
        case "*": return "wildcard: matches anything"
        case "/": return "root directory"
        default: return ""
        }
    }

    private func showSystemInfo() async {
        addSystemMessage("")
        addSystemMessage("🖥️  System Information:")
        addSystemMessage("────────────────────────────────────────")
        addSystemMessage("  User:     \(NSUserName())")
        addSystemMessage("  Host:     \(ProcessInfo.processInfo.hostName)")
        addSystemMessage("  macOS:    \(ProcessInfo.processInfo.operatingSystemVersionString)")
        addSystemMessage("  CPU:      \(ProcessInfo.processInfo.processorCount) cores")

        let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        addSystemMessage("  Memory:   \(String(format: "%.1f", memoryGB)) GB")

        addSystemMessage("  Shell:    /bin/zsh")
        addSystemMessage("  CWD:      \(shortenPath(currentDirectory))")

        // Check for common dev tools
        let toolChecks: [(String, [String])] = [
            ("Homebrew", ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]),
            ("Git", ["/usr/bin/git", "/opt/homebrew/bin/git"]),
            ("Python3", ["/usr/bin/python3", "/opt/homebrew/bin/python3"]),
            ("Node.js", ["/usr/local/bin/node", "/opt/homebrew/bin/node"]),
            ("Ruby", ["/usr/bin/ruby", "/opt/homebrew/bin/ruby"]),
            ("Rust/Cargo", ["\(FileManager.default.homeDirectoryForCurrentUser.path)/.cargo/bin/cargo"]),
        ]

        var installedTools: [String] = []
        for (name, paths) in toolChecks {
            if paths.contains(where: { FileManager.default.fileExists(atPath: $0) }) {
                installedTools.append(name)
            }
        }

        if !installedTools.isEmpty {
            addSystemMessage("  Dev Tools: \(installedTools.joined(separator: ", "))")
        }
        addSystemMessage("")
    }

}
