import SwiftUI

struct TaskChunkerView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var terminalService: TerminalService
    @EnvironmentObject var suggestionEngine: CommandSuggestionEngine
    
    @State private var taskDescription: String = ""
    @State private var sessionName: String = ""
    @State private var generatedChunks: [TaskChunk] = []
    @State private var showingChunks: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom)
                        )
                    
                    Text("Task Chunker")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("Break big scary tasks into small friendly steps")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Input Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("What do you want to accomplish?")
                        .font(.headline)
                    
                    Text("Describe it in your own words — no technical jargon needed!")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $taskDescription)
                        .font(.system(size: 14))
                        .frame(minHeight: 80, maxHeight: 120)
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Quick task templates
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Or pick a common task:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            templateButton("Deploy a project", icon: "paperplane")
                            templateButton("Set up new project", icon: "plus.rectangle")
                            templateButton("Merge git branches", icon: "arrow.triangle.branch")
                            templateButton("Debug an error", icon: "ladybug")
                            templateButton("Backup files", icon: "externaldrive")
                            templateButton("Install something", icon: "arrow.down.circle")
                        }
                    }
                    
                    HStack {
                        TextField("Session name (optional)", text: $sessionName)
                            .textFieldStyle(.roundedBorder)
                        
                        Button(action: generateChunks) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Break It Down!")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(taskDescription.isEmpty)
                    }
                }
                .padding(20)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                }
                
                // Generated Chunks
                if showingChunks && !generatedChunks.isEmpty {
                    chunksSection
                }
                
                // Active Sessions
                if !appState.sessions.isEmpty {
                    activeSessionsSection
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Template Button
    private func templateButton(_ title: String, icon: String) -> some View {
        Button(action: {
            taskDescription = title
            generateChunks()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Chunks Section
    private var chunksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Steps")
                    .font(.headline)
                
                Spacer()
                
                // Progress
                let completed = generatedChunks.filter { $0.isCompleted }.count
                Text("\(completed)/\(generatedChunks.count) done")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                // Progress bar
                ProgressView(value: Double(completed), total: Double(generatedChunks.count))
                    .frame(width: 100)
                    .tint(.green)
            }
            
            // Estimated time
            let totalMinutes = generatedChunks.reduce(0) { $0 + $1.estimatedMinutes }
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                Text("Estimated total: ~\(totalMinutes) minutes")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            ForEach(Array(generatedChunks.enumerated()), id: \.element.id) { index, chunk in
                chunkRow(chunk, index: index)
            }
            
            HStack {
                Button(action: {
                    appState.createSession(
                        name: sessionName.isEmpty ? taskDescription : sessionName,
                        chunks: generatedChunks
                    )
                }) {
                    HStack {
                        Image(systemName: "bookmark")
                        Text("Save as Session")
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: {
                    generatedChunks.removeAll()
                    showingChunks = false
                    taskDescription = ""
                    sessionName = ""
                }) {
                    Text("Start Over")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }
    
    // MARK: - Chunk Row
    private func chunkRow(_ chunk: TaskChunk, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number / completion
            ZStack {
                Circle()
                    .fill(chunk.isCompleted ? Color.green : Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                if chunk.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chunk.title)
                        .font(.system(size: 14, weight: .semibold))
                        .strikethrough(chunk.isCompleted)
                    
                    Text(chunk.difficulty.emoji)
                    
                    Spacer()
                    
                    Text("~\(chunk.estimatedMinutes) min")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Text(chunk.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                if !chunk.command.isEmpty && !chunk.command.hasPrefix("#") {
                    HStack {
                        Text(chunk.command)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.1))
                            .cornerRadius(4)
                        
                        Button(action: {
                            // Run this command in terminal
                            Task {
                                await terminalService.executeCommand(chunk.command)
                            }
                            markChunkComplete(chunk)
                            appState.selectedTab = .terminal
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                Text("Run")
                            }
                            .font(.system(size: 11))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.small)
                    }
                }
            }
            
            // Mark complete button
            if !chunk.isCompleted {
                Button(action: { markChunkComplete(chunk) }) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .help("Mark as done")
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(chunk.isCompleted ? Color.green.opacity(0.05) : Color(nsColor: .windowBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(chunk.isCompleted ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        }
    }
    
    // MARK: - Active Sessions
    private var activeSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved Sessions")
                .font(.headline)
            
            ForEach(appState.sessions) { session in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.name)
                            .font(.system(size: 14, weight: .medium))
                        Text("\(session.completedChunks)/\(session.chunks.count) steps • ~\(session.totalEstimatedMinutes) min")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    ProgressView(value: session.progress)
                        .frame(width: 80)
                        .tint(session.progress == 1.0 ? .green : .blue)
                    
                    Button("Resume") {
                        generatedChunks = session.chunks
                        sessionName = session.name
                        taskDescription = session.name
                        showingChunks = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .windowBackgroundColor))
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }
    
    // MARK: - Actions
    private func generateChunks() {
        generatedChunks = suggestionEngine.chunkComplexCommand(taskDescription)
        showingChunks = true
    }
    
    private func markChunkComplete(_ chunk: TaskChunk) {
        if let index = generatedChunks.firstIndex(where: { $0.id == chunk.id }) {
            withAnimation {
                generatedChunks[index].isCompleted = true
            }
            
            // Celebrate!
            let allDone = generatedChunks.allSatisfy { $0.isCompleted }
            if allDone {
                terminalService.addCelebration("🎉🎊🌟 ALL STEPS COMPLETE! You did it! Take a moment to feel proud! 🌟🎊🎉")
            } else {
                let celebrations = ["✨ Step done!", "🎯 Nice one!", "💪 Keep going!", "⭐ One more down!"]
                terminalService.addCelebration(celebrations.randomElement() ?? "✨ Done!")
            }
        }
    }
}
