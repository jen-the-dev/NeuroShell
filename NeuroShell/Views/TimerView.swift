import SwiftUI

struct TimerView: View {
    @EnvironmentObject var timerService: TimerService
    @EnvironmentObject var appState: AppState
    
    @State private var customBreakMinutes: Double = 10
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom)
                        )
                    
                    Text("Time Awareness")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("Because time blindness is real — let me help you keep track")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Current Status
                statusCard
                
                // Break Controls
                breakCard
                
                // Session Stats
                statsCard
                
                // Reminders Config
                remindersCard
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Status Card
    private var statusCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Session")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(timerService.formattedElapsed)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(timerService.currentPhase.color)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: timerService.currentPhase.icon)
                        Text(timerService.currentPhase.rawValue)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(timerService.currentPhase.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(timerService.currentPhase.color.opacity(0.15))
                    .cornerRadius(8)
                    
                    if timerService.isOnBreak {
                        Text("⏳ \(timerService.formattedBreakRemaining)")
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Progress indicator for the session
            if !timerService.isOnBreak {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Time until suggested break")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(max(0, appState.preferences.hyperfocusLimitMinutes - timerService.elapsedMinutes)) min left")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(
                        value: min(Double(timerService.elapsedMinutes), Double(appState.preferences.hyperfocusLimitMinutes)),
                        total: Double(appState.preferences.hyperfocusLimitMinutes)
                    )
                    .tint(progressColor)
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }
    
    private var progressColor: Color {
        let ratio = Double(timerService.elapsedMinutes) / Double(appState.preferences.hyperfocusLimitMinutes)
        if ratio < 0.5 { return .green }
        if ratio < 0.75 { return .yellow }
        if ratio < 0.9 { return .orange }
        return .red
    }
    
    // MARK: - Break Card
    private var breakCard: some View {
        VStack(spacing: 16) {
            Text("Break Controls")
                .font(.headline)
            
            if timerService.isOnBreak {
                VStack(spacing: 12) {
                    Text("☕ You're on a break! Enjoy it!")
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("Time remaining: \(timerService.formattedBreakRemaining)")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                    
                    Text("Ideas for your break:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        breakIdea("💧", "Drink some water")
                        breakIdea("🚶", "Stand up and stretch")
                        breakIdea("👀", "Look at something far away (20-20-20 rule)")
                        breakIdea("🫁", "Try the breathing exercise")
                        breakIdea("🧘", "Do a quick body scan")
                    }
                    
                    Button("End Break Early") {
                        timerService.endBreak()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(spacing: 12) {
                    Text("Your brain works better with breaks!")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        breakButton(minutes: 5, emoji: "☕", label: "Quick")
                        breakButton(minutes: 10, emoji: "🧘", label: "Normal")
                        breakButton(minutes: 15, emoji: "🌿", label: "Long")
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Custom break:")
                            .font(.system(size: 12))
                        Slider(value: $customBreakMinutes, in: 1...30, step: 1)
                        Text("\(Int(customBreakMinutes)) min")
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 45)
                        Button("Start") {
                            timerService.startBreak(minutes: Int(customBreakMinutes))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }
    
    private func breakButton(minutes: Int, emoji: String, label: String) -> some View {
        Button(action: {
            timerService.startBreak(minutes: minutes)
            appState.selectedTab = .breathing
        }) {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.system(size: 24))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                Text("\(minutes) min")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    private func breakIdea(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Text(emoji)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Stats Card
    private var statsCard: some View {
        VStack(spacing: 12) {
            Text("Session Stats")
                .font(.headline)
            
            HStack(spacing: 20) {
                statItem(value: timerService.formattedTotalSession, label: "Total Time", icon: "clock", color: .blue)
                statItem(value: "\(timerService.elapsedMinutes)m", label: "Current Stretch", icon: "timer", color: .green)
            }
            
            HStack {
                Button("Reset Session") {
                    timerService.resetSession()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button(timerService.currentPhase == .paused ? "Resume" : "Pause") {
                    if timerService.currentPhase == .paused {
                        timerService.resumeSession()
                    } else {
                        timerService.pauseSession()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }
    
    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }
    
    // MARK: - Reminders Card
    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminder Settings")
                .font(.headline)
            
            Toggle("Time awareness alerts", isOn: $appState.preferences.enableTimeAlerts)
            Toggle("Hydration reminders", isOn: $appState.preferences.enableHydrationReminders)
            Toggle("Posture check-ins", isOn: $appState.preferences.enablePostureReminders)
            Toggle("Encouragement messages", isOn: $appState.preferences.enableEncouragement)
            
            HStack {
                Text("Reminder interval:")
                Slider(value: Binding(
                    get: { Double(appState.preferences.reminderIntervalMinutes) },
                    set: { appState.preferences.reminderIntervalMinutes = Int($0) }
                ), in: 5...60, step: 5)
                Text("\(appState.preferences.reminderIntervalMinutes) min")
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 45)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }
}
