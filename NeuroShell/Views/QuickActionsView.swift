import SwiftUI

struct QuickActionsView: View {
    @EnvironmentObject var terminalService: TerminalService
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var contextMemory: ContextMemory
    
    @State private var searchText: String = ""
    
    let categories: [(name: String, icon: String, color: Color, actions: [(name: String, command: String, description: String, icon: String)])] = [
        (
            name: "Getting Around",
            icon: "arrow.right.circle.fill",
            color: .blue,
            actions: [
                ("Where Am I?", "pwd", "Show your current directory", "mappin"),
                ("What's Here?", "ls -la", "List everything in this folder", "folder"),
                ("Go Home", "cd ~", "Go to your home directory", "house"),
                ("Go Back", "cd ..", "Go up one directory level", "arrow.up"),
                ("Show Tree", "find . -maxdepth 2 -type d | head -20", "See folder structure", "tree"),
            ]
        ),
        (
            name: "File Stuff",
            icon: "doc.fill",
            color: .green,
            actions: [
                ("New File", "touch ", "Create a new empty file (add name)", "doc.badge.plus"),
                ("New Folder", "mkdir ", "Create a new folder (add name)", "folder.badge.plus"),
                ("File Sizes", "du -sh * | sort -h", "See how big everything is", "chart.bar"),
                ("Find Files", "find . -name \"*\" -type f | head -20", "Search for files", "magnifyingglass"),
                ("Disk Space", "df -h", "Check available disk space", "externaldrive"),
            ]
        ),
        (
            name: "Git Basics",
            icon: "arrow.triangle.branch",
            color: .orange,
            actions: [
                ("Status", "git status", "What's changed?", "questionmark.circle"),
                ("Show Changes", "git diff", "See exactly what changed", "doc.text.magnifyingglass"),
                ("Stage All", "git add .", "Prepare all changes for commit", "plus.circle"),
                ("Recent History", "git log --oneline -10", "See last 10 commits", "clock"),
                ("Current Branch", "git branch --show-current", "Which branch am I on?", "arrow.triangle.branch"),
                ("All Branches", "git branch -a", "See all branches", "list.bullet"),
            ]
        ),
        (
            name: "System Info",
            icon: "gearshape.fill",
            color: .purple,
            actions: [
                ("My Username", "whoami", "Who am I logged in as?", "person"),
                ("Date & Time", "date", "What time is it?", "clock"),
                ("Running Apps", "ps aux | head -15", "See what's running", "cpu"),
                ("Memory Usage", "vm_stat | head -5", "Check memory", "memorychip"),
                ("Network Check", "ping -c 2 google.com", "Am I connected?", "wifi"),
                ("IP Address", "ifconfig en0 | grep inet | head -1", "What's my IP?", "network"),
            ]
        ),
        (
            name: "Helpful Shortcuts",
            icon: "star.fill",
            color: .yellow,
            actions: [
                ("Open Finder Here", "open .", "Open current folder in Finder", "folder"),
                ("Open VS Code", "code . 2>/dev/null || echo 'VS Code not found'", "Open in VS Code", "chevron.left.forwardslash.chevron.right"),
                ("Count Files", "find . -type f | wc -l", "How many files in here?", "number"),
                ("Recent Files", "ls -lt | head -10", "Recently modified files", "clock.arrow.circlepath"),
                ("Clear Screen", "clear", "Fresh start!", "sparkles"),
            ]
        ),
    ]
    
    var filteredCategories: [(name: String, icon: String, color: Color, actions: [(name: String, command: String, description: String, icon: String)])] {
        if searchText.isEmpty { return categories }
        return categories.compactMap { category in
            let filtered = category.actions.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.command.localizedCaseInsensitiveContains(searchText)
            }
            if filtered.isEmpty { return nil }
            return (category.name, category.icon, category.color, filtered)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
                        )
                    
                    Text("Quick Actions")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("No need to remember commands — just tap what you want to do")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search actions...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)
                
                // Where Was I? Card
                whereWasICard
                
                // Action Categories
                ForEach(filteredCategories, id: \.name) { category in
                    categorySection(category)
                }
                
                // Context Notes
                contextNotesSection
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Where Was I Card
    private var whereWasICard: some View {
        Button(action: {
            let summary = contextMemory.whereWasI()
            terminalService.addSystemMessage(summary)
            appState.selectedTab = .terminal
        }) {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 24))
                    .foregroundColor(.cyan)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("🤔 Where Was I?")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Get a summary of what you were doing")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.cyan)
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cyan.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Category Section
    private func categorySection(_ category: (name: String, icon: String, color: Color, actions: [(name: String, command: String, description: String, icon: String)])) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .foregroundColor(category.color)
                Text(category.name)
                    .font(.headline)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(category.actions, id: \.name) { action in
                    actionButton(action, color: category.color)
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }
    
    private func actionButton(_ action: (name: String, command: String, description: String, icon: String), color: Color) -> some View {
        Button(action: {
            Task {
                await terminalService.executeCommand(action.command)
            }
            contextMemory.addCommand(action.command)
            appState.selectedTab = .terminal
        }) {
            VStack(spacing: 6) {
                Image(systemName: action.icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                Text(action.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                Text(action.description)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .background(color.opacity(0.06))
            .cornerRadius(10)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.15), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Context Notes
    private var contextNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.orange)
                Text("Quick Notes")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    contextMemory.addNote("New note...")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Note")
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if contextMemory.contextNotes.isEmpty {
                Text("No notes yet. Add notes to remember things between sessions!")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(contextMemory.contextNotes) { note in
                    HStack {
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                        }
                        Text(note.text)
                            .font(.system(size: 12))
                        Spacer()
                        Button(action: { contextMemory.toggleNotePin(note) }) {
                            Image(systemName: note.isPinned ? "pin.slash" : "pin")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        Button(action: { contextMemory.removeNote(note) }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .cornerRadius(6)
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }
}
