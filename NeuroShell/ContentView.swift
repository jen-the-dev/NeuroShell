import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var timerService: TimerService
    @EnvironmentObject var hyperfocusGuard: HyperfocusGuard
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            ZStack {
                mainContent
                
                // Time alert overlay
                if timerService.showTimeAlert {
                    timeAlertOverlay
                }
                
                // Hyperfocus warning overlay
                if hyperfocusGuard.showWarning {
                    hyperfocusWarningOverlay
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        switch appState.selectedTab {
        case .terminal:
            TerminalView()
        case .taskChunker:
            TaskChunkerView()
        case .quickActions:
            QuickActionsView()
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
