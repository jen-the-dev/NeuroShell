import SwiftUI

// MARK: - Element Card
/// Individual card for a sound element in the mixer grid.
/// Shows icon, name, and active state. Tap to toggle. Active state shows volume slider.
struct ElementCard: View {
    let element: SoundElement
    let isActive: Bool
    let isDisabled: Bool // true when max layers reached and this element is inactive
    let volume: Float
    let onToggle: () -> Void
    let onVolumeChange: (Float) -> Void

    @State private var localVolume: Float

    init(element: SoundElement, isActive: Bool, isDisabled: Bool, volume: Float,
         onToggle: @escaping () -> Void, onVolumeChange: @escaping (Float) -> Void) {
        self.element = element
        self.isActive = isActive
        self.isDisabled = isDisabled
        self.volume = volume
        self.onToggle = onToggle
        self.onVolumeChange = onVolumeChange
        _localVolume = State(initialValue: volume > 0 ? volume : 0.6)
    }

    var body: some View {
        VStack(spacing: 10) {
            // Icon
            ZStack {
                Circle()
                    .fill(isActive ? element.color.opacity(0.2) : Color.gray.opacity(0.08))
                    .frame(width: 56, height: 56)

                if isActive {
                    Circle()
                        .stroke(element.color.opacity(0.5), lineWidth: 2)
                        .frame(width: 56, height: 56)
                }

                Image(systemName: element.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isActive ? element.color : .secondary)
            }

            // Name
            Text(element.displayName)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? .primary : .secondary)

            // Volume slider (only when active)
            if isActive {
                Slider(
                    value: $localVolume,
                    in: 0...1,
                    step: 0.05
                )
                .tint(element.color)
                .frame(height: 20)
                .onChange(of: localVolume) { newValue in
                    onVolumeChange(newValue)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? element.color.opacity(0.06) : Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? element.color.opacity(0.3) : Color.clear, lineWidth: 1.5)
        }
        .opacity(isDisabled ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isDisabled || isActive {
                onToggle()
            }
        }
        .onAppear {
            localVolume = volume
        }
        .onChange(of: volume) { newValue in
            localVolume = newValue
        }
        .help(element.description)
    }
}
