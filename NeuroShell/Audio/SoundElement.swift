import SwiftUI

// MARK: - Sound Element
/// Represents a nature sound that can be mixed into the ambient soundscape
enum SoundElement: String, CaseIterable, Identifiable, Codable, Hashable {
    case rain
    case wind
    case ocean
    case thunder
    case birds
    case fire
    case forest
    case stream

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rain: return "Rain"
        case .wind: return "Wind"
        case .ocean: return "Ocean"
        case .thunder: return "Thunder"
        case .birds: return "Birds"
        case .fire: return "Fire"
        case .forest: return "Forest"
        case .stream: return "Stream"
        }
    }

    var icon: String {
        switch self {
        case .rain: return "cloud.rain.fill"
        case .wind: return "wind"
        case .ocean: return "water.waves"
        case .thunder: return "cloud.bolt.rain.fill"
        case .birds: return "bird.fill"
        case .fire: return "flame.fill"
        case .forest: return "leaf.fill"
        case .stream: return "drop.fill"
        }
    }

    var color: Color {
        switch self {
        case .rain: return .blue
        case .wind: return .gray
        case .ocean: return .cyan
        case .thunder: return .indigo
        case .birds: return .yellow
        case .fire: return .orange
        case .forest: return .green
        case .stream: return .teal
        }
    }

    var description: String {
        switch self {
        case .rain: return "Steady rainfall — calming and rhythmic"
        case .wind: return "Gentle breeze through open spaces"
        case .ocean: return "Rolling ocean waves on the shore"
        case .thunder: return "Distant rumbling thunder"
        case .birds: return "Birdsong in a quiet morning"
        case .fire: return "Crackling campfire warmth"
        case .forest: return "Rustling leaves and forest ambience"
        case .stream: return "Babbling brook flowing over stones"
        }
    }

    // MARK: - Noise Shaping Parameters
    /// Cutoff frequency for the element's spectral character
    var filterCutoff: Float {
        switch self {
        case .rain: return 3000
        case .wind: return 800
        case .ocean: return 600
        case .thunder: return 200
        case .birds: return 6000
        case .fire: return 4000
        case .forest: return 2000
        case .stream: return 5000
        }
    }

    /// Resonance / Q factor for band shaping
    var filterResonance: Float {
        switch self {
        case .rain: return 0.3
        case .wind: return 0.6
        case .ocean: return 0.4
        case .thunder: return 0.8
        case .birds: return 0.2
        case .fire: return 0.3
        case .forest: return 0.3
        case .stream: return 0.25
        }
    }

    /// Amplitude modulation rate (Hz) for natural variation
    var modulationRate: Float {
        switch self {
        case .rain: return 0.1
        case .wind: return 0.15
        case .ocean: return 0.08
        case .thunder: return 0.03
        case .birds: return 0.5
        case .fire: return 0.4
        case .forest: return 0.05
        case .stream: return 0.2
        }
    }
}
