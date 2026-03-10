import Combine
import Foundation
import SwiftUI

// MARK: - Lolcat Renderer
/// Renders text in glorious rainbow colors, because terminals should be fun!
/// Supports multiple rainbow themes, animation, and per-character coloring.
class LolcatRenderer: ObservableObject {

    // MARK: - Rainbow Themes
    enum Theme: String, CaseIterable, Identifiable {
        case classic = "Classic Rainbow"
        case pastel = "Pastel Dream"
        case neon = "Neon Glow"
        case sunset = "Sunset"
        case ocean = "Ocean Wave"
        case forest = "Enchanted Forest"
        case bisexual = "Bi Pride"
        case trans = "Trans Pride"
        case nonbinary = "Nonbinary Pride"
        case lesbian = "Lesbian Pride"
        case pride = "Rainbow Pride"
        case vaporwave = "Vaporwave"
        case fire = "Fire"
        case ice = "Ice"
        case candy = "Candy"

        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .classic: return "🌈"
            case .pastel: return "🧁"
            case .neon: return "💡"
            case .sunset: return "🌅"
            case .ocean: return "🌊"
            case .forest: return "🌲"
            case .bisexual: return "💖"
            case .trans: return "🏳️‍⚧️"
            case .nonbinary: return "💛"
            case .lesbian: return "🧡"
            case .pride: return "🏳️‍🌈"
            case .vaporwave: return "📼"
            case .fire: return "🔥"
            case .ice: return "🧊"
            case .candy: return "🍬"
            }
        }
    }

    @Published var isEnabled: Bool = true
    @Published var currentTheme: Theme = .classic
    @Published var animationSpeed: Double = 1.0 // 0.0 = static, higher = faster
    @Published var frequency: Double = 0.15 // How quickly colors cycle per character
    @Published var spread: Double = 3.0 // Diagonal spread factor across lines
    @Published var saturation: Double = 0.85
    @Published var brightness: Double = 0.95

    // MARK: - Static Rainbow Color Calculation

    /// Get the rainbow color for a specific character position
    /// - Parameters:
    ///   - charIndex: Character position in the line
    ///   - lineOffset: Line offset for diagonal rainbow effect (classic lolcat)
    ///   - seed: Per-line seed for variation
    ///   - animationPhase: Animation phase offset (0.0 - 1.0, changes over time)
    /// - Returns: A Color for this character
    func colorForCharacter(
        at charIndex: Int,
        lineOffset: Double = 0,
        seed: Double = 0,
        animationPhase: Double = 0
    ) -> Color {
        switch currentTheme {
        case .classic:
            return classicRainbow(charIndex: charIndex, lineOffset: lineOffset, seed: seed, phase: animationPhase)
        case .pastel:
            return pastelRainbow(charIndex: charIndex, lineOffset: lineOffset, seed: seed, phase: animationPhase)
        case .neon:
            return neonRainbow(charIndex: charIndex, lineOffset: lineOffset, seed: seed, phase: animationPhase)
        case .sunset:
            return gradientTheme(charIndex: charIndex, lineOffset: lineOffset, seed: seed, phase: animationPhase,
                                 colors: [.red, .orange, .yellow, .orange, .red, .pink])
        case .ocean:
            return gradientTheme(charIndex: charIndex, lineOffset: lineOffset, seed: seed, phase: animationPhase,
                                 colors: [.cyan, .blue, .indigo, .blue, .teal, .cyan])
        case .forest:
            return gradientTheme(charIndex: charIndex, lineOffset: lineOffset, seed: seed, phase: animationPhase,
                                 colors: [.green, .mint, .teal, .green, .yellow, .green])
        case .bisexual:
            return gradientTheme(charIndex: charIndex, lineOffset: lineOffset, seed: seed, phase: animationPhase,
                                 colors: [
                                    Color(red: 0.84, green: 0.0, blue: 0.44),
                                    Color(red: 0.84, green: 0.0, blue: 0.44),
                                    Color(red: 0.61, green: 0.31, blue: 0.64),
                                    Color(red: 0.0, green: 0.22, blue: 0.66),
                                    Color(red: 0.0, green: 0.22, blue: 0.66),
                                 ])
        case .trans:
            return gradientTheme(charIndex: charIndex, lineOffset: lineOffset, seed: seed, phase: animationPhase,
                                 colors: [
                                    Color(red: 0.36, green: 0.81, blue: 0.98),
                                    Color(red: 0.96, green: 0.66, blue: 0.72),
                                    .white,
                                    Color(red: 0.96, green: 0.66, blue: 0.72),
                                    Color(red: 0.36, green: 0.81, blue: 0.98),
                                 ])
        case .nonbinary:
            return gradientTheme(charIndex: charIndex, lineOffset: lineOffset, seed: seed, phase: animationPhase,
                                 colors: [
                                    Color(red: 0.99, green: 0.95, blue: 0.21),
                                    .white,
                                    Color(red: 0.61, green: 0.35, blue: 0.82),
                                    Color(red: 0.18, green: 0.18, blue: 0.18),
                                 ])
        case .lesbian:
            return gradientTheme(charIndex: charIndex, lineOffset: lineOffset, seed: seed, phase: animationPhase,
                                 colors: [
                                    Color(red: 0.83, green: 0.18, blue: 0.0),
                                    Color(red: 0.98, green: 0.60, blue: 0.32),
                                    .white,
                                    Color(red: 0.82, green: 0.39, blue: 0.60),
                                    Color(red: 0.64, green: 0.03, blue: 0.35),
                                 ])
        case .pride:
            return gradientTheme(charIndex: charIndex, lineOffset: lineOffset, seed: seed, phase: animationPhase,
                                 colors: [.red, .orange, .yellow, .green, .blue, .purple])
        case .vaporwave:
            return gradientTheme(charIndex: charIndex, lineOffset: lineOffset, seed: seed, phase: animationPhase,
                                 colors: [
                                    Color(red: 1.0, green: 0.44, blue: 0.78),
                                    Color(red: 0.47, green: 0.32, blue: 1.0),
                                    Color(red: 0.0, green: 0.89, blue: 1.0),
                                    Color(red: 0.47, green: 0.32, blue: 1.0),
                                    Color(red: 1.0, green: 0.44, blue: 0.78),
                                 ])
        case .fire:
            return gradientTheme(charIndex: charIndex, lineOffset: lineOffset, seed: seed, phase: animationPhase,
                                 colors: [
                                    Color(red: 1.0, green: 1.0, blue: 0.0),
                                    Color(red: 1.0, green: 0.65, blue: 0.0),
                                    Color(red: 1.0, green: 0.27, blue: 0.0),
                                    Color(red: 0.8, green: 0.0, blue: 0.0),
                                    Color(red: 1.0, green: 0.27, blue: 0.0),
                                    Color(red: 1.0, green: 0.65, blue: 0.0),
                                 ])
        case .ice:
            return gradientTheme(charIndex: charIndex, lineOffset: lineOffset, seed: seed, phase: animationPhase,
                                 colors: [
                                    .white,
                                    Color(red: 0.75, green: 0.9, blue: 1.0),
                                    Color(red: 0.4, green: 0.75, blue: 1.0),
                                    Color(red: 0.6, green: 0.85, blue: 1.0),
                                    .white,
                                 ])
        case .candy:
            return gradientTheme(charIndex: charIndex, lineOffset: lineOffset, seed: seed, phase: animationPhase,
                                 colors: [
                                    Color(red: 1.0, green: 0.4, blue: 0.7),
                                    Color(red: 0.6, green: 0.8, blue: 1.0),
                                    Color(red: 1.0, green: 0.85, blue: 0.4),
                                    Color(red: 0.6, green: 1.0, blue: 0.6),
                                    Color(red: 0.8, green: 0.6, blue: 1.0),
                                    Color(red: 1.0, green: 0.4, blue: 0.7),
                                 ])
        }
    }

    // MARK: - Theme Implementations

    private func classicRainbow(charIndex: Int, lineOffset: Double, seed: Double, phase: Double) -> Color {
        let hue = (Double(charIndex) * frequency + lineOffset * frequency / spread + seed + phase)
            .truncatingRemainder(dividingBy: 1.0)
        let adjustedHue = hue < 0 ? hue + 1.0 : hue
        return Color(hue: adjustedHue, saturation: saturation, brightness: brightness)
    }

    private func pastelRainbow(charIndex: Int, lineOffset: Double, seed: Double, phase: Double) -> Color {
        let hue = (Double(charIndex) * frequency + lineOffset * frequency / spread + seed + phase)
            .truncatingRemainder(dividingBy: 1.0)
        let adjustedHue = hue < 0 ? hue + 1.0 : hue
        return Color(hue: adjustedHue, saturation: 0.45, brightness: 1.0)
    }

    private func neonRainbow(charIndex: Int, lineOffset: Double, seed: Double, phase: Double) -> Color {
        let hue = (Double(charIndex) * frequency + lineOffset * frequency / spread + seed + phase)
            .truncatingRemainder(dividingBy: 1.0)
        let adjustedHue = hue < 0 ? hue + 1.0 : hue
        return Color(hue: adjustedHue, saturation: 1.0, brightness: 1.0)
    }

    private func gradientTheme(charIndex: Int, lineOffset: Double, seed: Double, phase: Double, colors: [Color]) -> Color {
        guard colors.count >= 2 else { return colors.first ?? .white }

        let position = (Double(charIndex) * frequency + lineOffset * frequency / spread + seed + phase)
            .truncatingRemainder(dividingBy: 1.0)
        let adjustedPos = position < 0 ? position + 1.0 : position

        let scaledPos = adjustedPos * Double(colors.count - 1)
        let lowerIndex = Int(scaledPos) % colors.count
        let upperIndex = (lowerIndex + 1) % colors.count
        let fraction = scaledPos - Double(Int(scaledPos))

        return interpolateColor(from: colors[lowerIndex], to: colors[upperIndex], fraction: fraction)
    }

    // MARK: - Color Interpolation

    private func interpolateColor(from: Color, to: Color, fraction: Double) -> Color {
        let fromComponents = NSColor(from).usingColorSpace(.sRGB) ?? NSColor.white
        let toComponents = NSColor(to).usingColorSpace(.sRGB) ?? NSColor.white

        let r = fromComponents.redComponent + (toComponents.redComponent - fromComponents.redComponent) * fraction
        let g = fromComponents.greenComponent + (toComponents.greenComponent - fromComponents.greenComponent) * fraction
        let b = fromComponents.blueComponent + (toComponents.blueComponent - fromComponents.blueComponent) * fraction

        return Color(red: r, green: g, blue: b)
    }

    // MARK: - Text Rendering

    /// Build a SwiftUI Text view with per-character rainbow coloring
    func rainbowText(
        _ string: String,
        fontSize: CGFloat = 14,
        lineOffset: Double = 0,
        seed: Double = 0,
        animationPhase: Double = 0,
        bold: Bool = false
    ) -> Text {
        var result = Text("")

        for (index, char) in string.enumerated() {
            let color = colorForCharacter(
                at: index,
                lineOffset: lineOffset,
                seed: seed,
                animationPhase: animationPhase
            )

            var charText = Text(String(char))
                .foregroundColor(color)
                .font(.system(size: fontSize, weight: bold ? .bold : .regular, design: .monospaced))

            if bold {
                charText = charText.bold()
            }

            result = result + charText
        }

        return result
    }

    /// Build an NSAttributedString with rainbow coloring (useful for AppKit interop)
    func rainbowAttributedString(
        _ string: String,
        fontSize: CGFloat = 14,
        lineOffset: Double = 0,
        seed: Double = 0,
        animationPhase: Double = 0
    ) -> NSAttributedString {
        let attributed = NSMutableAttributedString()
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        for (index, char) in string.enumerated() {
            let color = colorForCharacter(
                at: index,
                lineOffset: lineOffset,
                seed: seed,
                animationPhase: animationPhase
            )

            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor(color),
                .font: font,
            ]

            attributed.append(NSAttributedString(string: String(char), attributes: attrs))
        }

        return attributed
    }

    // MARK: - ASCII Art

    /// Classic lolcat-style nyan cat ASCII art
    static let nyanCatFrames: [[String]] = [
        [
            "┌───────────────────────┐",
            "│ ╭━━━━━━━━━━━━━━━━━━╮  │",
            "│ ┃  ╭╮   ╭╮        ┃  │",
            "│ ┃  ┃╰━━━╯┃  ◕  ◕  ┃  │",
            "│ ┃  ╰━━━━━╯  ╰▽╯   ┃  │",
            "│ ┃   ╭╮╭╮    ╭╮╭╮  ┃  │",
            "│ ╰━━━╯╰╯╰━━━━╯╰╯╰━╯  │",
            "└───────────────────────┘",
        ],
        [
            "┌───────────────────────┐",
            "│ ╭━━━━━━━━━━━━━━━━━━╮  │",
            "│ ┃  ╭╮   ╭╮        ┃  │",
            "│ ┃  ┃╰━━━╯┃  ◕  ◕  ┃  │",
            "│ ┃  ╰━━━━━╯  ╰△╯   ┃  │",
            "│ ┃  ╭╮╭╮    ╭╮╭╮   ┃  │",
            "│ ╰━━╯╰╯╰━━━━╯╰╯╰━━╯  │",
            "└───────────────────────┘",
        ],
    ]

    static let rainbowBanner: [String] = [
        "██╗      ██████╗ ██╗      ██████╗ █████╗ ████████╗",
        "██║     ██╔═══██╗██║     ██╔════╝██╔══██╗╚══██╔══╝",
        "██║     ██║   ██║██║     ██║     ███████║   ██║   ",
        "██║     ██║   ██║██║     ██║     ██╔══██║   ██║   ",
        "███████╗╚██████╔╝███████╗╚██████╗██║  ██║   ██║   ",
        "╚══════╝ ╚═════╝ ╚══════╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   ",
    ]

    static let neuroShellBanner: [String] = [
        "███╗   ██╗███████╗██╗   ██╗██████╗  ██████╗ ",
        "████╗  ██║██╔════╝██║   ██║██╔══██╗██╔═══██╗",
        "██╔██╗ ██║█████╗  ██║   ██║██████╔╝██║   ██║",
        "██║╚██╗██║██╔══╝  ██║   ██║██╔══██╗██║   ██║",
        "██║ ╚████║███████╗╚██████╔╝██║  ██║╚██████╔╝",
        "╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ",
        "███████╗██╗  ██╗███████╗██╗     ██╗     ",
        "██╔════╝██║  ██║██╔════╝██║     ██║     ",
        "███████╗███████║█████╗  ██║     ██║     ",
        "╚════██║██╔══██║██╔══╝  ██║     ██║     ",
        "███████║██║  ██║███████╗███████╗███████╗",
        "╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝",
    ]

    static let catFace: [String] = [
        "  /\\_/\\  ",
        " ( o.o ) ",
        "  > ^ <  ",
        " /|   |\\ ",
        "(_|   |_)",
    ]

    static let sparkles: [String] = [
        "    ✦  ·  ✧  .  ✦    ",
        "  ·    ✧    ·    ✦   ",
        "    ✦    .    ✧    · ",
        "  ✧  ·    ✦  .    ✧ ",
        "    ·  ✦    ✧  ·    ✦",
    ]

    // MARK: - Fun Sayings for lolcat mode
    static let funSayings: [String] = [
        "✨ Everything is better in rainbow! ✨",
        "🌈 You have unlocked: MAXIMUM VIBES",
        "🦄 Warning: excessive fabulousness detected",
        "🏳️‍🌈 Living in full color!",
        "💅 Terminal just got a glow-up",
        "🎨 Who says terminals have to be boring?",
        "🌟 Sparkle mode: ACTIVATED",
        "✨ Your code is now 200% more magical",
        "🦋 Butterfly mode: engaged",
        "🍭 Sweet sweet rainbow bytes",
        "🌈 ROY G. BIV says hi",
        "✨ *gay hacker sounds* ✨",
        "🎪 Welcome to the rainbow terminal circus!",
        "💖 Serotonin boost: DELIVERED",
        "🌈 The dopamine your ADHD brain ordered has arrived",
    ]

    // MARK: - Helpers

    /// Generate a random fun saying
    static func randomSaying() -> String {
        funSayings.randomElement() ?? funSayings[0]
    }

    /// Get the list of available theme names for display
    static var themeNames: [(theme: Theme, label: String)] {
        Theme.allCases.map { ($0, "\($0.emoji) \($0.rawValue)") }
    }
}

// MARK: - Rainbow Text SwiftUI View
/// A view that renders text with animated rainbow colors
struct RainbowTextView: View {
    let text: String
    let fontSize: CGFloat
    let lineOffset: Double
    let seed: Double
    let bold: Bool
    let animated: Bool

    @EnvironmentObject var lolcat: LolcatRenderer
    @State private var animationPhase: Double = 0

    init(
        _ text: String,
        fontSize: CGFloat = 14,
        lineOffset: Double = 0,
        seed: Double = 0,
        bold: Bool = false,
        animated: Bool = true
    ) {
        self.text = text
        self.fontSize = fontSize
        self.lineOffset = lineOffset
        self.seed = seed
        self.bold = bold
        self.animated = animated
    }

    var body: some View {
        lolcat.rainbowText(
            text,
            fontSize: fontSize,
            lineOffset: lineOffset,
            seed: seed,
            animationPhase: animationPhase,
            bold: bold
        )
        .textSelection(.enabled)
        .onAppear {
            if animated && lolcat.animationSpeed > 0 {
                startAnimation()
            }
        }
    }

    private func startAnimation() {
        guard lolcat.animationSpeed > 0 else { return }
        let duration = 4.0 / max(lolcat.animationSpeed, 0.1)
        withAnimation(
            .linear(duration: duration)
            .repeatForever(autoreverses: false)
        ) {
            animationPhase = 1.0
        }
    }
}

// MARK: - Static Rainbow Text (no EnvironmentObject needed)
/// A simpler rainbow text view that doesn't need the LolcatRenderer in environment
struct StaticRainbowText: View {
    let text: String
    let fontSize: CGFloat
    let seed: Double
    let saturation: Double
    let brightness: Double

    @State private var phase: Double = 0

    init(
        _ text: String,
        fontSize: CGFloat = 14,
        seed: Double = 0,
        saturation: Double = 0.85,
        brightness: Double = 0.95
    ) {
        self.text = text
        self.fontSize = fontSize
        self.seed = seed
        self.saturation = saturation
        self.brightness = brightness
    }

    var body: some View {
        buildText()
            .textSelection(.enabled)
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }

    private func buildText() -> Text {
        var result = Text("")
        let freq = 0.15

        for (index, char) in text.enumerated() {
            let hue = (Double(index) * freq + seed + phase)
                .truncatingRemainder(dividingBy: 1.0)
            let adjustedHue = hue < 0 ? hue + 1.0 : hue
            let color = Color(hue: adjustedHue, saturation: saturation, brightness: brightness)

            let charText = Text(String(char))
                .foregroundColor(color)
                .font(.system(size: fontSize, design: .monospaced))

            result = result + charText
        }

        return result
    }
}
