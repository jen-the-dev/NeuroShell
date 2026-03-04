import Foundation

// MARK: - Mix Preset Element Entry
struct PresetElement: Codable, Hashable {
    let element: SoundElement
    let volume: Float
}

// MARK: - Mix Preset
/// A saved combination of sound elements with their volumes
struct MixPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var elements: [PresetElement]
    let createdAt: Date
    var isBuiltIn: Bool

    init(name: String, elements: [PresetElement], isBuiltIn: Bool = false) {
        self.id = UUID()
        self.name = name
        self.elements = elements
        self.createdAt = Date()
        self.isBuiltIn = isBuiltIn
    }

    // MARK: - Built-in Presets

    static let focusForest = MixPreset(
        name: "Focus Forest",
        elements: [
            PresetElement(element: .forest, volume: 0.7),
            PresetElement(element: .birds, volume: 0.4),
            PresetElement(element: .stream, volume: 0.5),
        ],
        isBuiltIn: true
    )

    static let oceanCalm = MixPreset(
        name: "Ocean Calm",
        elements: [
            PresetElement(element: .ocean, volume: 0.7),
            PresetElement(element: .wind, volume: 0.3),
        ],
        isBuiltIn: true
    )

    static let stormEnergy = MixPreset(
        name: "Storm Energy",
        elements: [
            PresetElement(element: .rain, volume: 0.6),
            PresetElement(element: .thunder, volume: 0.5),
            PresetElement(element: .wind, volume: 0.4),
        ],
        isBuiltIn: true
    )

    static let cozyFireside = MixPreset(
        name: "Cozy Fireside",
        elements: [
            PresetElement(element: .fire, volume: 0.7),
            PresetElement(element: .rain, volume: 0.3),
            PresetElement(element: .wind, volume: 0.2),
        ],
        isBuiltIn: true
    )

    static let builtInPresets: [MixPreset] = [focusForest, oceanCalm, stormEnergy, cozyFireside]
}
