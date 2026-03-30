import SwiftUI

struct SwitchCard: View {
    let widget: HomeKitWidget
    @ObservedObject var manager: HomeKitManager
    var onRemove: (() -> Void)?

    private var switchDevice: SwitchAccessory? { widget.switchDevice }
    private let accent = DS.Color.accentAmber

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
                        Text(switchDevice?.roomName ?? "")
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
                }

                if let device = switchDevice {
                    if device.isStale {
                        Spacer()
                        ProgressView().tint(accent)
                        Spacer()
                    } else {
                        Spacer()

                        // Icon
                        Image(systemName: device.kind == .outlet ? "powerplug.fill" : "switch.2")
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(device.isOn ? accent : DS.Color.textTertiary)

                        // State label
                        VStack(spacing: 2) {
                            Text(device.isOn ? "On" : "Off")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(device.isOn ? accent : DS.Color.textTertiary)

                            // In Use badge for outlets
                            if device.kind == .outlet, let inUse = device.outletInUse {
                                Text(inUse ? "In Use" : "Idle")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(inUse ? accent.opacity(0.8) : DS.Color.textTertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(inUse ? accent.opacity(0.1) : DS.Color.surfaceRaised)
                                    .clipShape(Capsule())
                            }
                        }

                        Spacer()

                        // Toggle button
                        Button {
                            withAnimation(DS.Animation.snappy) { manager.toggleSwitchPower(for: device) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "power")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(device.isOn ? "Turn Off" : "Turn On")
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
                    Text("No switch").font(.system(size: 14, design: .rounded)).foregroundColor(DS.Color.textTertiary)
                    Spacer()
                }
            }
        }
    }
}
