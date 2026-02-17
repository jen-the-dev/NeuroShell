import SwiftUI

struct BreathingExerciseView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var isBreathing: Bool = false
    @State private var breathPhase: BreathPhase = .ready
    @State private var circleScale: CGFloat = 0.5
    @State private var phaseTimer: Timer?
    @State private var cycleCount: Int = 0
    @State private var selectedPattern: BreathingPattern = .box
    
    enum BreathPhase: String {
        case ready = "Ready when you are"
        case breatheIn = "Breathe In..."
        case holdIn = "Hold..."
        case breatheOut = "Breathe Out..."
        case holdOut = "Hold still..."
        case complete = "Great job! 🌟"
        
        var color: Color {
            switch self {
            case .ready: return .gray
            case .breatheIn: return .cyan
            case .holdIn: return .blue
            case .breatheOut: return .purple
            case .holdOut: return .indigo
            case .complete: return .green
            }
        }
    }
    
    enum BreathingPattern: String, CaseIterable, Identifiable {
        case box = "Box Breathing"
        case calm = "4-7-8 Calming"
        case energize = "Energizing"
        case quick = "Quick Reset"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .box: return "Equal parts: 4-4-4-4. Great for focus and calm."
            case .calm: return "In 4, hold 7, out 8. Deep relaxation."
            case .energize: return "Quick in, slow out. Helps with motivation."
            case .quick: return "3 breaths. Fast reset when overwhelmed."
            }
        }
        
        var phases: [(phase: BreathPhase, duration: TimeInterval)] {
            switch self {
            case .box:
                return [(.breatheIn, 4), (.holdIn, 4), (.breatheOut, 4), (.holdOut, 4)]
            case .calm:
                return [(.breatheIn, 4), (.holdIn, 7), (.breatheOut, 8)]
            case .energize:
                return [(.breatheIn, 2), (.breatheOut, 4)]
            case .quick:
                return [(.breatheIn, 3), (.breatheOut, 3)]
            }
        }
        
        var totalCycles: Int {
            switch self {
            case .box: return 4
            case .calm: return 3
            case .energize: return 5
            case .quick: return 3
            }
        }
        
        var emoji: String {
            switch self {
            case .box: return "🟦"
            case .calm: return "🌊"
            case .energize: return "⚡"
            case .quick: return "🔄"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 8) {
                Text("🫁")
                    .font(.system(size: 40))
                
                Text("Breathing Space")
                    .font(.system(size: 24, weight: .bold))
                
                Text("A moment to reset your nervous system")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            // Pattern Picker
            if !isBreathing {
                patternPicker
            }
            
            // Breathing Circle
            breathingCircle
            
            // Controls
            controls
            
            // Affirmation
            if breathPhase == .complete || !isBreathing {
                affirmationSection
            }
            
            Spacer()
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    breathPhase.color.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Pattern Picker
    private var patternPicker: some View {
        VStack(spacing: 12) {
            Text("Choose a pattern:")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                ForEach(BreathingPattern.allCases) { pattern in
                    Button(action: { selectedPattern = pattern }) {
                        VStack(spacing: 6) {
                            Text(pattern.emoji)
                                .font(.system(size: 24))
                            Text(pattern.rawValue)
                                .font(.system(size: 11, weight: .medium))
                            Text(pattern.description)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(selectedPattern == pattern ? pattern.phases.first!.phase.color.opacity(0.15) : Color.clear)
                        .cornerRadius(10)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedPattern == pattern ? pattern.phases.first!.phase.color.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }
    
    // MARK: - Breathing Circle
    private var breathingCircle: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(breathPhase.color.opacity(0.2), lineWidth: 3)
                .frame(width: 220, height: 220)
            
            // Animated circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [breathPhase.color.opacity(0.6), breathPhase.color.opacity(0.2)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 110
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(circleScale)
                .animation(
                    appState.preferences.reducedMotion ? .none :
                        .easeInOut(duration: currentPhaseDuration),
                    value: circleScale
                )
            
            // Phase text
            VStack(spacing: 8) {
                Text(breathPhase.rawValue)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                
                if isBreathing {
                    Text("Cycle \(cycleCount + 1) of \(selectedPattern.totalCycles)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(height: 240)
    }
    
    private var currentPhaseDuration: TimeInterval {
        selectedPattern.phases.first(where: { $0.phase == breathPhase })?.duration ?? 4
    }
    
    // MARK: - Controls
    private var controls: some View {
        HStack(spacing: 16) {
            if isBreathing {
                Button(action: stopBreathing) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red.opacity(0.8))
            } else {
                Button(action: startBreathing) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Breathing")
                    }
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .controlSize(.large)
            }
        }
    }
    
    // MARK: - Affirmation
    private var affirmationSection: some View {
        VStack(spacing: 8) {
            let affirmations = [
                "You are exactly where you need to be right now.",
                "Your brain is unique and that is a strength.",
                "It's okay to need a moment. Everyone does.",
                "You showed up today. That counts for a lot.",
                "Progress isn't always visible. You're still growing.",
                "Be gentle with yourself — you're doing your best.",
                "This moment of pause is productive too.",
                "Your worth isn't measured by your productivity."
            ]
            
            Text(affirmations[cycleCount % affirmations.count])
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Breathing Logic
    private func startBreathing() {
        isBreathing = true
        cycleCount = 0
        runBreathingCycle()
    }
    
    private func runBreathingCycle() {
        let phases = selectedPattern.phases
        var totalDelay: TimeInterval = 0
        
        for phaseInfo in phases {
            let capturedDelay = totalDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + capturedDelay) {
                guard self.isBreathing else { return }
                self.breathPhase = phaseInfo.phase
                
                // Animate circle
                if phaseInfo.phase == .breatheIn {
                    self.circleScale = 1.0
                } else if phaseInfo.phase == .breatheOut {
                    self.circleScale = 0.5
                }
            }
            totalDelay += phaseInfo.duration
        }
        
        // After one complete cycle
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
            guard self.isBreathing else { return }
            self.cycleCount += 1
            
            if self.cycleCount < self.selectedPattern.totalCycles {
                self.runBreathingCycle()
            } else {
                self.completeBreathing()
            }
        }
    }
    
    private func completeBreathing() {
        breathPhase = .complete
        isBreathing = false
        circleScale = 0.7
    }
    
    private func stopBreathing() {
        isBreathing = false
        breathPhase = .ready
        circleScale = 0.5
        phaseTimer?.invalidate()
    }
}
