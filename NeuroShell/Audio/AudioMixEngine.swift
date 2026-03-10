import AVFoundation
import Combine
import SwiftUI

// MARK: - Audio Layer
/// Represents one active sound layer in the mix
struct AudioLayer: Identifiable {
    let id = UUID()
    let element: SoundElement
    let generator: NoiseGenerator
    let mixerNode: AVAudioMixerNode
    var volume: Float
}

// MARK: - Audio Mix Engine
/// Manages procedural ambient soundscape mixing with AVAudioEngine.
/// Supports up to 4 simultaneous sound layers — like Endel's Nature elements.
@MainActor
class AudioMixEngine: ObservableObject {
    static let maxLayers = 4

    @Published var activeLayers: [AudioLayer] = []
    @Published var masterVolume: Float = 0.7 {
        didSet { engine.mainMixerNode.outputVolume = masterVolume }
    }
    @Published var isPlaying: Bool = false

    private let engine = AVAudioEngine()

    init() {
        engine.mainMixerNode.outputVolume = masterVolume
    }

    // MARK: - Layer Management

    /// Add a sound element as a new layer. Returns false if at max capacity.
    @discardableResult
    func addElement(_ element: SoundElement) -> Bool {
        guard activeLayers.count < Self.maxLayers else { return false }
        guard !activeLayers.contains(where: { $0.element == element }) else { return false }

        let generator = NoiseGenerator(element: element)
        let mixerNode = AVAudioMixerNode()
        mixerNode.outputVolume = 0.6

        engine.attach(generator.sourceNode)
        engine.attach(mixerNode)

        let format = generator.sourceNode.outputFormat(forBus: 0)
        engine.connect(generator.sourceNode, to: mixerNode, format: format)
        engine.connect(mixerNode, to: engine.mainMixerNode, format: format)

        let layer = AudioLayer(element: element, generator: generator, mixerNode: mixerNode, volume: 0.6)
        activeLayers.append(layer)

        // Auto-start if we were playing
        if isPlaying {
            tryStart()
        }

        return true
    }

    /// Remove a sound element layer
    func removeElement(_ element: SoundElement) {
        guard let index = activeLayers.firstIndex(where: { $0.element == element }) else { return }
        let layer = activeLayers[index]

        engine.disconnectNodeOutput(layer.generator.sourceNode)
        engine.disconnectNodeOutput(layer.mixerNode)
        engine.detach(layer.generator.sourceNode)
        engine.detach(layer.mixerNode)

        activeLayers.remove(at: index)

        if activeLayers.isEmpty {
            stop()
        }
    }

    /// Toggle an element on/off
    @discardableResult
    func toggleElement(_ element: SoundElement) -> Bool {
        if activeLayers.contains(where: { $0.element == element }) {
            removeElement(element)
            return false
        } else {
            return addElement(element)
        }
    }

    /// Check if an element is currently active
    func isActive(_ element: SoundElement) -> Bool {
        activeLayers.contains(where: { $0.element == element })
    }

    // MARK: - Volume Control

    /// Set volume for a specific element (0.0 – 1.0)
    func setVolume(_ volume: Float, for element: SoundElement) {
        guard let index = activeLayers.firstIndex(where: { $0.element == element }) else { return }
        activeLayers[index].volume = volume
        activeLayers[index].mixerNode.outputVolume = volume
    }

    /// Get current volume for an element
    func volume(for element: SoundElement) -> Float {
        activeLayers.first(where: { $0.element == element })?.volume ?? 0
    }

    // MARK: - Transport Controls

    func play() {
        guard !activeLayers.isEmpty else { return }
        tryStart()
        isPlaying = true
    }

    func pause() {
        engine.pause()
        isPlaying = false
    }

    func stop() {
        engine.stop()
        isPlaying = false
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Remove all layers and stop
    func clearAll() {
        let elements = activeLayers.map(\.element)
        for element in elements {
            removeElement(element)
        }
        stop()
    }

    // MARK: - Load Preset

    func loadPreset(_ preset: MixPreset) {
        clearAll()
        for entry in preset.elements {
            addElement(entry.element)
            setVolume(entry.volume, for: entry.element)
        }
        play()
    }

    // MARK: - Private

    private func tryStart() {
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("AudioMixEngine: failed to start — \(error.localizedDescription)")
            }
        }
    }
}
