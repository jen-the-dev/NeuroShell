import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var timerService: TimerService
    @EnvironmentObject var hyperfocusGuard: HyperfocusGuard
    @EnvironmentObject var audioEngine: AudioMixEngine

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar row
            toolbarRow
            Divider()

            // Main content area with overlays
            ZStack {
                mainContent

                if timerService.showTimeAlert {
                    timeAlertOverlay
                }

                if hyperfocusGuard.showWarning {
                    hyperfocusWarningOverlay
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    // MARK: - Toolbar Row
    private var toolbarRow: some View {
        HStack(spacing: 12) {
            // Tab picker
            HStack(spacing: 2) {
                ForEach(AppState.AppTab.allCases) { tab in
                    Button(action: { appState.selectedTab = tab }) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11))
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(appState.selectedTab == tab ? tab.color.opacity(0.15) : Color.clear)
                        )
                        .foregroundColor(appState.selectedTab == tab ? tab.color : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Now-playing indicator (sound mixer)
            if audioEngine.isPlaying {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 10))
                        .foregroundColor(.teal)
                    Text("\(audioEngine.activeLayers.count) sounds")
                        .font(.system(size: 10))
                        .foregroundColor(.teal)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.teal.opacity(0.1))
                .cornerRadius(4)
                .onTapGesture { appState.selectedTab = .soundMixer }
            }

            // Timer badge
            if timerService.currentPhase == .working && timerService.elapsedMinutes > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 10))
                    Text(timerService.formattedElapsed)
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundColor(timerService.elapsedMinutes > appState.preferences.hyperfocusLimitMinutes ? .orange : .purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(4)
                .onTapGesture { appState.selectedTab = .timer }
            }

            // Mood picker
            Menu {
                ForEach(AppState.Mood.allCases, id: \.rawValue) { mood in
                    Button("\(mood.emoji) \(mood.rawValue)") {
                        appState.currentMood = mood
                    }
                }
            } label: {
                Text(appState.currentMood.emoji)
                    .font(.system(size: 16))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
            .help(appState.currentMood.supportMessage)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Main Content
    @ViewBuilder
    private var mainContent: some View {
        switch appState.selectedTab {
        case .terminal:
            TerminalView()
        case .taskChunker:
            TaskChunkerView()
        case .quickActions:
            QuickActionsView()
        case .soundMixer:
            SoundMixerView()
        case .timer:
            TimerView()
        case .breathing:
            BreathingExerciseView()
        case .settings:
            SettingsView()
        }
    }

    // MARK: - Time Alert Overlay
    private var timeAlertOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    Text(timerService.timeAlertMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding()

                    HStack(spacing: 12) {
                        Button("Got it!") {
                            withAnimation(.easeOut(duration: 0.3)) {
                                timerService.dismissTimeAlert()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)

                        Button("Take a Break") {
                            timerService.startBreak()
                            timerService.dismissTimeAlert()
                            appState.selectedTab = .breathing
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(20)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 20)
                }
                .frame(maxWidth: 400)
                .padding(24)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: timerService.showTimeAlert)
    }

    // MARK: - Hyperfocus Warning Overlay
    private var hyperfocusWarningOverlay: some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                        Text("Hyperfocus Check-in")
                            .font(.headline)
                    }

                    Text(hyperfocusGuard.warningMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button("I'm fine, thanks!") {
                            withAnimation {
                                hyperfocusGuard.dismissWarning()
                            }
                        }
                        .buttonStyle(.bordered)

                        Button("Take a Break") {
                            hyperfocusGuard.dismissWarning()
                            timerService.startBreak()
                            appState.selectedTab = .breathing
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                }
                .padding(20)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .shadow(color: .orange.opacity(0.3), radius: 15)
                }
                .frame(maxWidth: 400)
                .padding(24)
            }
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: hyperfocusGuard.showWarning)
    }
}
