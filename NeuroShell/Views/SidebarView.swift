import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var timerService: TimerService
    @EnvironmentObject var hyperfocusGuard: HyperfocusGuard
    
    var body: some View {
        VStack(spacing: 0) {
            // App Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NeuroShell")
                            .font(.system(size: 18, weight: .bold))
                        Text("Terminal for your brain")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 12)
            }
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal)
            
            // Navigation Items
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(AppState.SidebarTab.allCases) { tab in
                        sidebarButton(for: tab)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 12)
            }
            
            Spacer()
            
            Divider()
                .padding(.horizontal)
            
            // Status Footer
            VStack(spacing: 8) {
                // Timer Status
                HStack {
                    Circle()
                        .fill(timerService.currentPhase.color)
                        .frame(width: 8, height: 8)
                    Text(timerService.formattedElapsed)
                        .font(.system(size: 11, design: .monospaced))
                    Spacer()
                    Text(timerService.currentPhase.rawValue)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                // Hyperfocus Indicator
                HStack {
                    Image(systemName: hyperfocusGuard.hyperfocusLevel.icon)
                        .font(.system(size: 10))
                        .foregroundColor(hyperfocusGuard.hyperfocusLevel.color)
                    Text(hyperfocusGuard.hyperfocusLevel.rawValue)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                // Mood Check
                HStack {
                    ForEach(AppState.Mood.allCases, id: \.self) { mood in
                        Button(action: {
                            withAnimation {
                                appState.currentMood = mood
                            }
                        }) {
                            Text(mood.emoji)
                                .font(.system(size: appState.currentMood == mood ? 18 : 14))
                                .opacity(appState.currentMood == mood ? 1.0 : 0.5)
                        }
                        .buttonStyle(.plain)
                        .help(mood.rawValue)
                    }
                }
                .padding(.top, 4)
                
                if appState.currentMood == .struggling || appState.currentMood == .overwhelmed {
                    Text(appState.currentMood.supportMessage)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }
            }
            .padding(12)
        }
        .background(.ultraThinMaterial)
    }
    
    private func sidebarButton(for tab: AppState.SidebarTab) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.selectedTab = tab
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14))
                    .foregroundColor(appState.selectedTab == tab ? tab.color : .secondary)
                    .frame(width: 20)
                
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: appState.selectedTab == tab ? .semibold : .regular))
                    .foregroundColor(appState.selectedTab == tab ? .primary : .secondary)
                
                Spacer()
                
                if tab == .timer && timerService.isOnBreak {
                    Text("☕")
                        .font(.system(size: 12))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if appState.selectedTab == tab {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(tab.color.opacity(0.15))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
