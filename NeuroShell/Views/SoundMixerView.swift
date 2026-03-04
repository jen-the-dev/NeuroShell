import SwiftUI

// MARK: - Sound Mixer View
/// Endel-inspired ambient sound mixer — select up to 4 nature elements to create a soundscape.
struct SoundMixerView: View {
    @EnvironmentObject var audioEngine: AudioMixEngine
    @EnvironmentObject var presetStore: PresetStore

    @State private var showSaveSheet: Bool = false
    @State private var newPresetName: String = ""
    @State private var showMaxLayerAlert: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                header

                // Presets
                presetsSection

                // Element Grid
                elementGrid

                // Transport + Master Volume
                if !audioEngine.activeLayers.isEmpty {
                    transportControls
                    nowPlayingBar
                }

                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Maximum Layers", isPresented: $showMaxLayerAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can mix up to 4 sounds at once. Remove one to add another.")
        }
        .sheet(isPresented: $showSaveSheet) {
            savePresetSheet
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(colors: [.teal, .cyan], startPoint: .top, endPoint: .bottom)
                )

            Text("Sound Mixer")
                .font(.system(size: 24, weight: .bold))

            Text("Create your focus soundscape — pick up to 4 elements")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }

    // MARK: - Presets Section
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Presets")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                if !audioEngine.activeLayers.isEmpty {
                    Button(action: { showSaveSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                            Text("Save Mix")
                        }
                        .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presetStore.allPresets) { preset in
                        presetButton(preset)
                    }
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }

    private func presetButton(_ preset: MixPreset) -> some View {
        Button(action: { audioEngine.loadPreset(preset) }) {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(preset.elements, id: \.element) { entry in
                        Image(systemName: entry.element.icon)
                            .font(.system(size: 12))
                            .foregroundColor(entry.element.color)
                    }
                }

                Text(preset.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .windowBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !preset.isBuiltIn {
                Button("Delete", role: .destructive) {
                    presetStore.deletePreset(preset)
                }
            }
        }
    }

    // MARK: - Element Grid
    private var elementGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Elements")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(SoundElement.allCases) { element in
                    let isActive = audioEngine.isActive(element)
                    let atMax = audioEngine.activeLayers.count >= AudioMixEngine.maxLayers
                    ElementCard(
                        element: element,
                        isActive: isActive,
                        isDisabled: atMax && !isActive,
                        volume: audioEngine.volume(for: element),
                        onToggle: {
                            if !isActive && atMax {
                                showMaxLayerAlert = true
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    audioEngine.toggleElement(element)
                                    if audioEngine.isActive(element) && !audioEngine.isPlaying {
                                        audioEngine.play()
                                    }
                                }
                            }
                        },
                        onVolumeChange: { volume in
                            audioEngine.setVolume(volume, for: element)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Transport Controls
    private var transportControls: some View {
        VStack(spacing: 16) {
            // Play / Pause / Stop
            HStack(spacing: 20) {
                Button(action: { audioEngine.togglePlayback() }) {
                    Image(systemName: audioEngine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.teal)
                }
                .buttonStyle(.plain)

                Button(action: {
                    withAnimation { audioEngine.clearAll() }
                }) {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Master volume
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Slider(
                    value: Binding(
                        get: { audioEngine.masterVolume },
                        set: { audioEngine.masterVolume = $0 }
                    ),
                    in: 0...1,
                    step: 0.05
                )
                .tint(.teal)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text("\(Int(audioEngine.masterVolume * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 35)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }

    // MARK: - Now Playing Bar
    private var nowPlayingBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Now Playing")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                if audioEngine.isPlaying {
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.teal)
                                .frame(width: 3, height: CGFloat.random(in: 6...14))
                        }
                    }
                    .frame(height: 14)
                }

                Spacer()

                Text("\(audioEngine.activeLayers.count)/\(AudioMixEngine.maxLayers) layers")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            ForEach(audioEngine.activeLayers) { layer in
                HStack(spacing: 10) {
                    Image(systemName: layer.element.icon)
                        .font(.system(size: 14))
                        .foregroundColor(layer.element.color)
                        .frame(width: 20)

                    Text(layer.element.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 60, alignment: .leading)

                    Slider(
                        value: Binding(
                            get: { layer.volume },
                            set: { audioEngine.setVolume($0, for: layer.element) }
                        ),
                        in: 0...1
                    )
                    .tint(layer.element.color)

                    Text("\(Int(layer.volume * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 30)

                    Button(action: {
                        withAnimation { audioEngine.removeElement(layer.element) }
                    }) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
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

    // MARK: - Save Preset Sheet
    private var savePresetSheet: some View {
        VStack(spacing: 16) {
            Text("Save Current Mix")
                .font(.headline)

            TextField("Preset name", text: $newPresetName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            HStack(spacing: 8) {
                ForEach(audioEngine.activeLayers) { layer in
                    HStack(spacing: 4) {
                        Image(systemName: layer.element.icon)
                            .font(.system(size: 12))
                            .foregroundColor(layer.element.color)
                        Text(layer.element.displayName)
                            .font(.system(size: 11))
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") { showSaveSheet = false }
                    .buttonStyle(.bordered)
                Button("Save") {
                    let name = newPresetName.isEmpty ? "My Mix" : newPresetName
                    presetStore.savePreset(name: name, from: audioEngine)
                    newPresetName = ""
                    showSaveSheet = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .disabled(audioEngine.activeLayers.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 320)
    }
}
