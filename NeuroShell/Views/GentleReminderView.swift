import SwiftUI

struct GentleReminderView: View {
    let reminder: GentleReminder
    let onDismiss: () -> Void
    let onAction: (() -> Void)?
    
    init(reminder: GentleReminder, onDismiss: @escaping () -> Void, onAction: (() -> Void)? = nil) {
        self.reminder = reminder
        self.onDismiss = onDismiss
        self.onAction = onAction
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(reminder.type.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: reminder.type.icon)
                    .font(.system(size: 16))
                    .foregroundColor(reminder.type.color)
            }
            
            // Message
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.message)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                
                Text(timeAgo(from: reminder.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Actions
            VStack(spacing: 4) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                if let action = onAction {
                    Button(action: action) {
                        Text("Act")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(reminder.type.color)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: reminder.type.color.opacity(0.1), radius: 5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(reminder.type.color.opacity(0.2), lineWidth: 1)
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins) min ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
    }
}

// MARK: - Reminder Toast
struct ReminderToast: View {
    let message: String
    let type: GentleReminder.ReminderType
    @Binding var isShowing: Bool
    
    var body: some View {
        if isShowing {
            VStack {
                Spacer()
                
                HStack(spacing: 10) {
                    Image(systemName: type.icon)
                        .font(.system(size: 16))
                        .foregroundColor(type.color)
                    
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isShowing = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                // Auto-dismiss after 8 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isShowing = false
                    }
                }
            }
        }
    }
}
