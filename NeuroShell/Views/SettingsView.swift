import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lolcat: LolcatRenderer
    @EnvironmentObject var audioEngine: AudioMixEngine

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(colors: [.gray, .secondary], startPoint: .top, endPoint: .bottom)
                        )

                    Text("Settings")
                        .font(.system(size: 24, weight: .bold))

                    Text("Customize NeuroShell to work with your brain")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // Terminal Settings
                settingsSection("Terminal", icon: "terminal", color: .green) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Font Size")
                            Spacer()
                            Slider(value: $appState.preferences.terminalFontSize, in: 10...24, step: 1)
                                .frame(width: 200)
                            Text("\(Int(appState.preferences.terminalFontSize))pt")
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 35)
                        }

                        Toggle("Show command explanations while typing", isOn: $appState.preferences.showCommandExplanations)
                        Toggle("Auto-suggest task chunking for complex commands", isOn: $appState.preferences.autoChunkComplexCommands)
                    }
                }

                // ADHD Support Settings
                settingsSection("ADHD Support", icon: "brain", color: .purple) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Working memory display limit")
                            Spacer()
                            Picker("", selection: $appState.preferences.maxWorkingMemoryItems) {
                                Text("2 items").tag(2)
                                Text("3 items").tag(3)
                                Text("4 items").tag(4)
                                Text("5 items").tag(5)
                            }
                            .frame(width: 120)
                        }

                        Text("Fewer items = less overwhelming. Start small!")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Divider()

                        HStack {
                            Text("Hyperfocus limit")
                            Spacer()
                            Slider(value: Binding(
                                get: { Double(appState.preferences.hyperfocusLimitMinutes) },
                                set: { appState.preferences.hyperfocusLimitMinutes = Int($0) }
                            ), in: 15...120, step: 5)
                                .frame(width: 200)
                            Text("\(appState.preferences.hyperfocusLimitMinutes)m")
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 35)
                        }

                        HStack {
                            Text("Default break duration")
                            Spacer()
                            Slider(value: Binding(
                                get: { Double(appState.preferences.breakDurationMinutes) },
                                set: { appState.preferences.breakDurationMinutes = Int($0) }
                            ), in: 5...30, step: 5)
                                .frame(width: 200)
                            Text("\(appState.preferences.breakDurationMinutes)m")
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 35)
                        }
                    }
                }

                // Reminder Settings
                settingsSection("Reminders", icon: "bell.fill", color: .orange) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Time awareness alerts", isOn: $appState.preferences.enableTimeAlerts)
                        Toggle("Hydration reminders", isOn: $appState.preferences.enableHydrationReminders)
                        Toggle("Posture check-ins", isOn: $appState.preferences.enablePostureReminders)
                        Toggle("Encouragement messages", isOn: $appState.preferences.enableEncouragement)
                        Toggle("Sound effects", isOn: $appState.preferences.enableSoundEffects)

                        Divider()

                        HStack {
                            Text("Reminder interval")
                            Spacer()
                            Slider(value: Binding(
                                get: { Double(appState.preferences.reminderIntervalMinutes) },
                                set: { appState.preferences.reminderIntervalMinutes = Int($0) }
                            ), in: 5...60, step: 5)
                                .frame(width: 200)
                            Text("\(appState.preferences.reminderIntervalMinutes)m")
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 35)
                        }
                    }
                }

                // Lolcat / Rainbow Settings
                settingsSection("Lolcat / Rainbow", icon: "paintpalette.fill", color: .pink) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable rainbow effects", isOn: $lolcat.isEnabled)

                        Divider()

                        // Theme picker
                        HStack {
                            Text("Theme")
                            Spacer()
                            Picker("", selection: $lolcat.currentTheme) {
                                ForEach(LolcatRenderer.Theme.allCases) { theme in
                                    Text("\(theme.emoji) \(theme.rawValue)").tag(theme)
                                }
                            }
                            .frame(width: 200)
                        }

                        // Theme preview
                        HStack(spacing: 0) {
                            ForEach(0..<40, id: \.self) { i in
                                Rectangle()
                                    .fill(lolcat.colorForCharacter(at: i, lineOffset: 0, seed: 0))
                                    .frame(width: 6, height: 20)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                        Divider()

                        // Animation speed
                        HStack {
                            Text("Animation speed")
                            Spacer()
                            Slider(value: $lolcat.animationSpeed, in: 0...3, step: 0.25)
                                .frame(width: 200)
                            Text(lolcat.animationSpeed == 0 ? "off" : String(format: "%.1fx", lolcat.animationSpeed))
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 35)
                        }

                        Text("0 = static colors, higher = faster color wave")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Divider()

                        // Frequency (how fast colors cycle per character)
                        HStack {
                            Text("Color frequency")
                            Spacer()
                            Slider(value: $lolcat.frequency, in: 0.05...0.5, step: 0.01)
                                .frame(width: 200)
                            Text(String(format: "%.2f", lolcat.frequency))
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 35)
                        }

                        Text("How quickly colors cycle per character (lower = wider stripes)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        // Spread
                        HStack {
                            Text("Diagonal spread")
                            Spacer()
                            Slider(value: $lolcat.spread, in: 1...10, step: 0.5)
                                .frame(width: 200)
                            Text(String(format: "%.1f", lolcat.spread))
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 35)
                        }

                        Text("How much the rainbow shifts between lines")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Divider()

                        // Reset button
                        HStack {
                            Spacer()
                            Button("Reset to Defaults") {
                                lolcat.currentTheme = .classic
                                lolcat.animationSpeed = 1.0
                                lolcat.frequency = 0.15
                                lolcat.spread = 3.0
                                lolcat.saturation = 0.85
                                lolcat.brightness = 0.95
                                lolcat.isEnabled = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                // Sound Settings
                settingsSection("Sound", icon: "waveform", color: .teal) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Master Volume")
                            Spacer()
                            Slider(value: Binding(
                                get: { audioEngine.masterVolume },
                                set: { audioEngine.masterVolume = $0 }
                            ), in: 0...1, step: 0.05)
                                .frame(width: 200)
                            Text("\(Int(audioEngine.masterVolume * 100))%")
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 35)
                        }

                        Text("Ambient sounds play procedurally generated nature audio")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Divider()

                        if audioEngine.isPlaying {
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundColor(.teal)
                                Text("\(audioEngine.activeLayers.count) sound(s) playing")
                                    .font(.system(size: 13))
                                Spacer()
                                Button("Stop All") {
                                    audioEngine.clearAll()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        } else {
                            Text("No sounds playing")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Accessibility Settings
                settingsSection("Accessibility", icon: "accessibility", color: .blue) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Reduce motion", isOn: $appState.preferences.reducedMotion)
                        Text("Disables animations like the breathing circle")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Toggle("High contrast mode", isOn: $appState.preferences.highContrastMode)
                        Text("Increases text contrast for better readability")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                // Keyboard Shortcuts
                settingsSection("Keyboard Shortcuts", icon: "keyboard", color: .cyan) {
                    VStack(alignment: .leading, spacing: 8) {
                        shortcutRow("New Session", shortcut: "⌘N")
                        shortcutRow("Clear Terminal", shortcut: "⌘K")
                        shortcutRow("Take a Break", shortcut: "⌘⇧B")
                        shortcutRow("Where Was I?", shortcut: "⌘⇧W")
                        shortcutRow("Toggle Focus Mode", shortcut: "⌘⇧F")
                        shortcutRow("Settings", shortcut: "⌘,")
                    }
                }

                // About
                VStack(spacing: 8) {
                    Text("NeuroShell v2.0")
                        .font(.system(size: 14, weight: .medium))
                    Text("Made with 💛 for neurodivergent minds")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Your brain isn't broken — it's just wired differently.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.purple)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Settings Section
    private func settingsSection<Content: View>(_ title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }

            content()
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }

    private func shortcutRow(_ action: String, shortcut: String) -> some View {
        HStack {
            Text(action)
                .font(.system(size: 13))
            Spacer()
            Text(shortcut)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(4)
        }
    }
}
