import SwiftUI

struct TerminalView: View {
    @EnvironmentObject var terminalService: TerminalService
    @EnvironmentObject var suggestionEngine: CommandSuggestionEngine
    @EnvironmentObject var hyperfocusGuard: HyperfocusGuard
    @EnvironmentObject var contextMemory: ContextMemory
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lolcat: LolcatRenderer

    @State private var inputText: String = ""
    @State private var suggestions: [CommandSuggestionEngine.CommandSuggestion] = []
    @State private var showExplanation: Bool = false
    @State private var currentExplanation: String = ""
    @State private var rainbowPhase: Double = 0
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            topBar

            // Context Breadcrumbs
            if !appState.focusModeEnabled {
                contextBar
            }

            // Terminal Output
            terminalOutput

            // Suggestions
            if !suggestions.isEmpty && !inputText.isEmpty {
                suggestionsBar
            }

            // Command Explanation
            if showExplanation && !currentExplanation.isEmpty {
                explanationBar
            }

            // Input Area
            inputArea
        }
        .background(Color(nsColor: .init(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)))
        .onTapGesture {
            isInputFocused = true
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle().fill(.red).frame(width: 12, height: 12)
                Circle().fill(.yellow).frame(width: 12, height: 12)
                Circle().fill(.green).frame(width: 12, height: 12)
            }
            .padding(.leading, 12)

            Spacer()

            Text("📂 \(shortenedPath(terminalService.currentDirectory))")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.gray)

            Spacer()

            HStack(spacing: 8) {
                if terminalService.isRunning {
                    ProgressView()
                        .scaleEffect(0.5)

                    Button(action: { terminalService.cancelCurrentProcess() }) {
                        Image(systemName: "stop.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .help("Cancel running command")
                }

                Button(action: {
                    let summary = contextMemory.whereWasI()
                    terminalService.addSystemMessage(summary)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                        Text("Where was I?")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
                .help("Remind you of what you were doing")
            }
            .padding(.trailing, 12)
        }
        .frame(height: 36)
        .background(Color(nsColor: .init(red: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)))
    }

    // MARK: - Context Bar
    private var contextBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Current goal
                if !contextMemory.currentGoal.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.system(size: 10))
                        Text(contextMemory.currentGoal)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(6)
                }

                // Working memory slots
                ForEach(contextMemory.workingMemorySlots) { slot in
                    HStack(spacing: 4) {
                        Image(systemName: slot.category.icon)
                            .font(.system(size: 10))
                        Text("\(slot.label): \(slot.value)")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .foregroundColor(slot.category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(slot.category.color.opacity(0.1))
                    .cornerRadius(6)
                }

                // Add memory slot button
                Button(action: {
                    contextMemory.addMemorySlot(label: "Note", value: "...", category: .note)
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "plus.circle")
                        Text("Remember")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(height: 32)
        .background(Color(nsColor: .init(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)))
    }

    // MARK: - Terminal Output
    private var terminalOutput: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(terminalService.outputLines) { line in
                        terminalLineView(line)
                            .id(line.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: terminalService.outputLines.count) { _, _ in
                if let lastLine = terminalService.outputLines.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastLine.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func terminalLineView(_ line: TerminalLine) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if line.type == .rainbow {
                RainbowTextView(
                    line.text,
                    fontSize: CGFloat(appState.preferences.terminalFontSize),
                    lineOffset: Double(terminalService.outputLines.firstIndex(where: { $0.id == line.id }) ?? 0),
                    seed: line.rainbowSeed,
                    bold: false,
                    animated: lolcat.animationSpeed > 0
                )
            } else if line.type == .celebration && lolcat.isEnabled {
                RainbowTextView(
                    line.text,
                    fontSize: CGFloat(appState.preferences.terminalFontSize),
                    lineOffset: Double(terminalService.outputLines.firstIndex(where: { $0.id == line.id }) ?? 0),
                    seed: line.rainbowSeed,
                    bold: true,
                    animated: lolcat.animationSpeed > 0
                )
            } else {
                Text(line.text)
                    .font(.system(size: CGFloat(appState.preferences.terminalFontSize), design: .monospaced))
                    .foregroundColor(colorForLineType(line.type))
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(.vertical, 1)
    }

    private func colorForLineType(_ type: TerminalLine.LineType) -> Color {
        switch type {
        case .input: return .cyan
        case .output: return .white
        case .error: return .red
        case .system: return .gray
        case .suggestion: return .yellow
        case .celebration: return .green
        case .rainbow: return .white // fallback, not actually used for rainbow
        }
    }

    // MARK: - Suggestions Bar
    private var suggestionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    Button(action: {
                        inputText = suggestion.command
                        isInputFocused = true
                    }) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.command)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.cyan)
                            Text(suggestion.description)
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.cyan.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(height: 52)
        .background(Color(nsColor: .init(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)))
    }

    // MARK: - Explanation Bar
    private var explanationBar: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
            Text(currentExplanation)
                .font(.system(size: 12))
                .foregroundColor(.yellow.opacity(0.9))
            Spacer()
            Button(action: { showExplanation = false }) {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.08))
    }

    // MARK: - Input Area
    private var inputArea: some View {
        HStack(spacing: 8) {
            Text("❯")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(terminalService.isRunning ? .orange : .cyan)

            TerminalTextField(
                text: $inputText,
                isRunning: terminalService.isRunning,
                fontSize: CGFloat(appState.preferences.terminalFontSize),
                onSubmit: {
                    executeCurrentInput()
                },
                onArrowUp: {
                    if let prev = terminalService.previousHistoryItem() {
                        inputText = prev
                    }
                },
                onArrowDown: {
                    if let next = terminalService.nextHistoryItem() {
                        inputText = next
                    }
                },
                onTab: {
                    // Auto-complete: pick the first suggestion
                    if let first = suggestions.first {
                        inputText = first.command
                    }
                },
                onCtrlC: {
                    if terminalService.isRunning {
                        terminalService.cancelCurrentProcess()
                    } else {
                        inputText = ""
                        terminalService.addSystemMessage("^C")
                    }
                },
                onCtrlL: {
                    terminalService.outputLines.removeAll()
                }
            )
            .focused($isInputFocused)
            .onChange(of: inputText) { _, newValue in
                updateSuggestions(for: newValue)
                if appState.preferences.showCommandExplanations {
                    updateExplanation(for: newValue)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isInputFocused = true
                }
            }

            if !inputText.isEmpty {
                Button(action: { inputText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

            Button(action: { executeCurrentInput() }) {
                Image(systemName: "return")
                    .foregroundColor(inputText.isEmpty ? .gray : .cyan)
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty || terminalService.isRunning)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .init(red: 0.13, green: 0.13, blue: 0.15, alpha: 1.0)))
    }

    // MARK: - Actions
    private func executeCurrentInput() {
        let command = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        guard !terminalService.isRunning else {
            terminalService.addSystemMessage("⏳ A command is already running. Wait for it to finish or press Ctrl+C to cancel.")
            return
        }

        inputText = ""
        suggestions = []
        showExplanation = false

        // Track in context and hyperfocus
        contextMemory.addCommand(command)
        hyperfocusGuard.trackCommand(command)
        appState.addToHistory(command)

        Task {
            await terminalService.executeCommand(command)
            contextMemory.currentWorkingDirectory = terminalService.currentDirectory
        }

        // Re-focus the input
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isInputFocused = true
        }
    }

    private func updateSuggestions(for input: String) {
        suggestions = suggestionEngine.getSuggestions(
            forInput: input,
            currentDir: terminalService.currentDirectory,
            recentCommands: contextMemory.recentCommands
        )
    }

    private func updateExplanation(for input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            showExplanation = false
            return
        }
        currentExplanation = suggestionEngine.explainCommand(trimmed)
        showExplanation = true
    }

    private func shortenedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home {
            return "~"
        } else if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

// MARK: - Custom NSTextField Wrapper for Keyboard Events
/// SwiftUI's TextField doesn't expose arrow key events or modifier key combos.
/// We need an NSViewRepresentable that wraps NSTextField to handle:
///   - Arrow Up / Arrow Down for history navigation
///   - Tab for auto-completion
///   - Ctrl+C for cancel
///   - Ctrl+L for clear
///   - Enter/Return for command execution
struct TerminalTextField: NSViewRepresentable {
    @Binding var text: String
    var isRunning: Bool
    var fontSize: CGFloat
    var onSubmit: () -> Void
    var onArrowUp: () -> Void
    var onArrowDown: () -> Void
    var onTab: () -> Void
    var onCtrlC: () -> Void
    var onCtrlL: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let textField = TerminalNSTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = "Type a command or describe what you want to do..."
        textField.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textField.textColor = NSColor.white
        textField.backgroundColor = NSColor.clear
        textField.isBordered = false
        textField.isBezeled = false
        textField.focusRingType = .none
        textField.drawsBackground = false
        textField.cell?.wraps = false
        textField.cell?.isScrollable = true
        textField.lineBreakMode = .byClipping
        textField.allowsEditingTextAttributes = false

        // Wire up keyboard event callbacks
        textField.onArrowUp = onArrowUp
        textField.onArrowDown = onArrowDown
        textField.onTab = onTab
        textField.onCtrlC = onCtrlC
        textField.onCtrlL = onCtrlL

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Only update text if it actually changed (prevents cursor jumping)
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        // Update font size if preference changed
        nsView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        // Update placeholder when running
        if isRunning {
            nsView.placeholderString = "⏳ Running... (Ctrl+C to cancel)"
        } else {
            nsView.placeholderString = "Type a command or describe what you want to do..."
        }

        // Update callbacks in case closures changed
        if let termField = nsView as? TerminalNSTextField {
            termField.onArrowUp = onArrowUp
            termField.onArrowDown = onArrowDown
            termField.onTab = onTab
            termField.onCtrlC = onCtrlC
            termField.onCtrlL = onCtrlL
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TerminalTextField

        init(_ parent: TerminalTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }

            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                parent.onArrowUp()
                return true
            }

            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onArrowDown()
                return true
            }

            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                parent.onTab()
                return true
            }

            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                // Escape key
                parent.text = ""
                return true
            }

            return false
        }
    }
}

// MARK: - Custom NSTextField subclass for key event interception
/// Intercepts raw key events that NSTextFieldDelegate doesn't cover,
/// particularly Ctrl+key combinations.
class TerminalNSTextField: NSTextField {
    var onArrowUp: (() -> Void)?
    var onArrowDown: (() -> Void)?
    var onTab: (() -> Void)?
    var onCtrlC: (() -> Void)?
    var onCtrlL: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        // Check for control key modifier
        if event.modifierFlags.contains(.control) {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "c":
                onCtrlC?()
                return
            case "l":
                onCtrlL?()
                return
            case "a":
                // Ctrl+A: move to beginning of line
                if let editor = currentEditor() {
                    editor.moveToBeginningOfLine(nil)
                }
                return
            case "e":
                // Ctrl+E: move to end of line
                if let editor = currentEditor() {
                    editor.moveToEndOfLine(nil)
                }
                return
            case "u":
                // Ctrl+U: clear the line
                self.stringValue = ""
                if let delegate = self.delegate as? TerminalTextField.Coordinator {
                    delegate.parent.text = ""
                }
                return
            case "k":
                // Ctrl+K: delete from cursor to end of line
                if let editor = currentEditor() {
                    editor.deleteToEndOfLine(nil)
                    if let delegate = self.delegate as? TerminalTextField.Coordinator {
                        delegate.parent.text = self.stringValue
                    }
                }
                return
            default:
                break
            }
        }

        super.keyDown(with: event)
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        // Move cursor to end when focused
        if let editor = currentEditor() {
            editor.moveToEndOfDocument(nil)
        }
        return result
    }
}
