import SwiftUI

struct FanCard: View {
    let widget: HomeKitWidget
    @ObservedObject var manager: HomeKitManager
    var onRemove: (() -> Void)?

    private var fan: FanAccessory? { widget.fan }
    private let accent = DS.Color.accentGreen

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
                        Text(fan?.roomName ?? "")
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

                    // Power toggle
                    if let fan {
                        Button {
                            withAnimation(DS.Animation.snappy) { manager.toggleFanPower(for: fan) }
                        } label: {
                            Image(systemName: "power")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(fan.isOn ? accent : DS.Color.textTertiary)
                                .padding(8)
                                .background(fan.isOn ? accent.opacity(0.15) : DS.Color.surfaceRaised)
                                .clipShape(Circle())
                        }
                    }
                }

                if let fan {
                    if fan.isStale {
                        Spacer()
                        ProgressView().tint(accent)
                        Spacer()
                    } else {
                        Spacer()

                        // Fan icon with rotation hint
                        if #available(iOS 18.0, *) {
                            Image(systemName: "fan.fill")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(fan.isOn ? accent : DS.Color.textTertiary)
                                .symbolEffect(.rotate, isActive: fan.isOn)
                        } else {
                            Image(systemName: "fan.fill")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(fan.isOn ? accent : DS.Color.textTertiary)
                        }

                        // Speed label
                        Text(fan.isOn ? "\(fan.rotationSpeed)%" : "Off")
                            .font(.system(size: 22, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(fan.isOn ? accent : DS.Color.textTertiary)

                        Spacer()

                        // Speed slider
                        HStack(spacing: 8) {
                            Image(systemName: "wind")
                                .font(.system(size: 11))
                                .foregroundColor(DS.Color.textTertiary)
                            Slider(
                                value: Binding(
                                    get: { Double(fan.rotationSpeed) },
                                    set: { manager.setFanSpeed(for: fan, value: Int($0)) }
                                ),
                                in: 0...100,
                                step: 1
                            )
                            .tint(accent)
                        }

                        // Direction toggle
                        Button {
                            manager.toggleFanDirection(for: fan)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: fan.rotationDirection == 0 ? "arrow.clockwise" : "arrow.counterclockwise")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(fan.rotationDirection == 0 ? "Clockwise" : "Counter-CW")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        }
                    }
                } else {
                    Spacer()
                    Text("No fan").font(.system(size: 14, design: .rounded)).foregroundColor(DS.Color.textTertiary)
                    Spacer()
                }
            }
        }
    }
}
