import SwiftUI

@main
struct NeuroShellApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var terminalService = TerminalService()
    @StateObject private var timerService = TimerService()
    @StateObject private var hyperfocusGuard = HyperfocusGuard()
    @StateObject private var contextMemory = ContextMemory()
    @StateObject private var suggestionEngine = CommandSuggestionEngine()
    @StateObject private var lolcat = LolcatRenderer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(terminalService)
                .environmentObject(timerService)
                .environmentObject(hyperfocusGuard)
                .environmentObject(contextMemory)
                .environmentObject(suggestionEngine)
                .environmentObject(lolcat)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    terminalService.lolcatRenderer = lolcat
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Session") {
                    appState.selectedTab = .taskChunker
                }
                .keyboardShortcut("n")

                Button("Clear Terminal") {
                    terminalService.outputLines.removeAll()
                }
                .keyboardShortcut("k")

                Divider()

                Button("Take a Break") {
                    timerService.startBreak()
                    appState.selectedTab = .breathing
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Button("Where Was I?") {
                    let summary = contextMemory.whereWasI()
                    terminalService.addSystemMessage(summary)
                    appState.selectedTab = .terminal
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
            }

            CommandGroup(after: .sidebar) {
                Button("Toggle Focus Mode") {
                    appState.focusModeEnabled.toggle()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(lolcat)
        }
    }
}
