import Foundation

// MARK: - Preset Store
/// Manages saved mix presets with UserDefaults persistence
@MainActor
class PresetStore: ObservableObject {
    @Published var presets: [MixPreset] = []

    private let storageKey = "NeuroShell.savedPresets"

    init() {
        loadPresets()
    }

    // MARK: - All Presets (built-in + user)
    var allPresets: [MixPreset] {
        MixPreset.builtInPresets + presets
    }

    // MARK: - Save / Load

    func savePreset(name: String, from engine: AudioMixEngine) {
        let elements = engine.activeLayers.map {
            PresetElement(element: $0.element, volume: $0.volume)
        }
        let preset = MixPreset(name: name, elements: elements)
        presets.insert(preset, at: 0)
        persistPresets()
    }

    func deletePreset(_ preset: MixPreset) {
        guard !preset.isBuiltIn else { return }
        presets.removeAll { $0.id == preset.id }
        persistPresets()
    }

    func renamePreset(_ preset: MixPreset, to newName: String) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].name = newName
        persistPresets()
    }

    // MARK: - Persistence

    private func persistPresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadPresets() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([MixPreset].self, from: data) else {
            return
        }
        presets = decoded
    }
}
