import SwiftUI

struct ValveCard: View {
    let widget: HomeKitWidget
    @ObservedObject var manager: HomeKitManager
    var onRemove: (() -> Void)?

    private var valve: ValveAccessory? { widget.valve }
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
                        Text(valve?.roomName ?? "")
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

                if let valve {
                    if valve.isStale {
                        Spacer()
                        ProgressView().tint(accent)
                        Spacer()
                    } else {
                        Spacer()

                        // Valve type icon
                        Image(systemName: valve.valveType.icon)
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(valve.isActive ? accent : DS.Color.textTertiary)

                        // State labels
                        VStack(spacing: 4) {
                            Text(valve.isActive ? "Active" : "Inactive")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(valve.isActive ? accent : DS.Color.textTertiary)

                            if valve.inUse {
                                Text("Water Flowing")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(DS.Color.accentBlue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(DS.Color.accentBlue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }

                        Spacer()

                        // Toggle button
                        Button {
                            withAnimation(DS.Animation.snappy) { manager.toggleValve(for: valve) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: valve.isActive ? "stop.fill" : "play.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(valve.isActive ? "Close Valve" : "Open Valve")
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
                    Text("No valve").font(.system(size: 14, design: .rounded)).foregroundColor(DS.Color.textTertiary)
                    Spacer()
                }
            }
        }
    }
}
