import SwiftUI

struct SpeakerCard: View {
    let widget: HomeKitWidget
    @ObservedObject var manager: HomeKitManager
    var onRemove: (() -> Void)?

    private var speaker: SpeakerAccessory? { widget.speaker }
    private let accent = DS.Color.accentBlue

    var body: some View {
        DashCard {
            VStack(spacing: DS.Space.sm) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(widget.displayName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.Color.textSecondary)
                            .lineLimit(1)
                        Text(speaker?.roomName ?? "")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(DS.Color.textTertiary)
                    }
                    Spacer()
                    if let onRemove {
                        Button { withAnimation(DS.Animation.snappy) { onRemove() } } label: {
                            Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                                .foregroundColor(DS.Color.textTertiary).padding(6)
                                .background(DS.Color.surfaceRaised).clipShape(Circle())
                        }
                    }

                    // Mute toggle
                    if let speaker {
                        Button {
                            withAnimation(DS.Animation.snappy) { manager.toggleSpeakerMute(for: speaker) }
                        } label: {
                            Image(systemName: speaker.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(speaker.isMuted ? DS.Color.textTertiary : accent)
                                .padding(8)
                                .background(speaker.isMuted ? DS.Color.surfaceRaised : accent.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                }

                if let speaker {
                    if speaker.isStale {
                        Spacer()
                        ProgressView().tint(accent)
                        Spacer()
                    } else {
                        Spacer()

                        // Speaker icon
                        Image(systemName: speaker.isMuted ? "speaker.slash.fill" : volumeIcon(for: speaker.volume))
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(speaker.isMuted ? DS.Color.textTertiary : accent)

                        // Volume label
                        VStack(spacing: 2) {
                            Text(speaker.isMuted ? "Muted" : "\(speaker.volume)%")
                                .font(.system(size: 22, weight: .light, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(speaker.isMuted ? DS.Color.textTertiary : accent)
                        }

                        Spacer()

                        // Volume slider
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.fill")
                                .font(.system(size: 11))
                                .foregroundColor(DS.Color.textTertiary)
                            Slider(
                                value: Binding(
                                    get: { Double(speaker.volume) },
                                    set: { manager.setSpeakerVolume(for: speaker, value: Int($0)) }
                                ),
                                in: 0...100,
                                step: 1
                            )
                            .tint(accent)
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 11))
                                .foregroundColor(DS.Color.textTertiary)
                        }
                    }
                } else {
                    Spacer()
                    Text("No speaker").font(.system(size: 14, design: .rounded)).foregroundColor(DS.Color.textTertiary)
                    Spacer()
                }
            }
        }
    }

    private func volumeIcon(for volume: Int) -> String {
        switch volume {
        case 0:       return "speaker.fill"
        case 1...33:  return "speaker.wave.1.fill"
        case 34...66: return "speaker.wave.2.fill"
        default:      return "speaker.wave.3.fill"
        }
    }
}
