import Combine
import SwiftUI

// MARK: - Screenshot Previews
// Open this file in Xcode and use the Canvas (⌥⌘P) to render each preview.
// Right-click the canvas preview and choose "Export..." to save as PNG.
// Recommended: use a 1280×800 window frame for App Store screenshots.

// Helper to inject all required environment objects for previews
private struct PreviewContainer<Content: View>: View {
    let content: Content
    @StateObject private var appState = AppState()
    @StateObject private var terminalService = TerminalService()
    @StateObject private var timerService = TimerService()
    @StateObject private var hyperfocusGuard = HyperfocusGuard()
    @StateObject private var contextMemory = ContextMemory()
    @StateObject private var suggestionEngine = CommandSuggestionEngine()
    @StateObject private var lolcat = LolcatRenderer()
    @StateObject private var audioEngine = AudioMixEngine()
    @StateObject private var presetStore = PresetStore()

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environmentObject(appState)
            .environmentObject(terminalService)
            .environmentObject(timerService)
            .environmentObject(hyperfocusGuard)
            .environmentObject(contextMemory)
            .environmentObject(suggestionEngine)
            .environmentObject(lolcat)
            .environmentObject(audioEngine)
            .environmentObject(presetStore)
    }
}

// MARK: - 1. Full App (Terminal Tab)
struct Screenshot_Terminal: PreviewProvider {
    static var previews: some View {
        PreviewContainer {
            ContentView()
        }
        .frame(width: 1280, height: 800)
        .preferredColorScheme(.dark)
        .previewDisplayName("Terminal")
    }
}

// MARK: - 2. Sound Mixer
struct Screenshot_SoundMixer: PreviewProvider {
    static var previews: some View {
        PreviewContainer {
            SoundMixerView()
        }
        .frame(width: 1280, height: 800)
        .preferredColorScheme(.dark)
        .previewDisplayName("Sound Mixer")
    }
}

// MARK: - 3. Task Chunker
struct Screenshot_TaskChunker: PreviewProvider {
    static var previews: some View {
        PreviewContainer {
            TaskChunkerView()
        }
        .frame(width: 1280, height: 800)
        .preferredColorScheme(.dark)
        .previewDisplayName("Task Chunker")
    }
}

// MARK: - 4. Breathing Exercise
struct Screenshot_Breathing: PreviewProvider {
    static var previews: some View {
        PreviewContainer {
            BreathingExerciseView()
        }
        .frame(width: 1280, height: 800)
        .preferredColorScheme(.dark)
        .previewDisplayName("Breathing Exercise")
    }
}

// MARK: - 5. Timer & Breaks
struct Screenshot_Timer: PreviewProvider {
    static var previews: some View {
        PreviewContainer {
            TimerView()
        }
        .frame(width: 1280, height: 800)
        .preferredColorScheme(.dark)
        .previewDisplayName("Timer & Breaks")
    }
}

// MARK: - 6. Quick Actions
struct Screenshot_QuickActions: PreviewProvider {
    static var previews: some View {
        PreviewContainer {
            QuickActionsView()
        }
        .frame(width: 1280, height: 800)
        .preferredColorScheme(.dark)
        .previewDisplayName("Quick Actions")
    }
}

// MARK: - 7. Settings
struct Screenshot_Settings: PreviewProvider {
    static var previews: some View {
        PreviewContainer {
            SettingsView()
        }
        .frame(width: 1280, height: 800)
        .preferredColorScheme(.dark)
        .previewDisplayName("Settings")
    }
}
