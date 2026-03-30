import SwiftUI

struct SecuritySystemCard: View {
    let widget: HomeKitWidget
    @ObservedObject var manager: HomeKitManager
    var onRemove: (() -> Void)?

    private var security: SecuritySystemAccessory? { widget.securitySystem }
    private let accent = DS.Color.accentPurple

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
                        Text(security?.roomName ?? "")
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

                if let system = security {
                    if system.isStale {
                        Spacer()
                        ProgressView().tint(accent)
                        Spacer()
                    } else {
                        // Triggered alert
                        if system.currentState == .triggered {
                            HStack(spacing: 6) {
                                Image(systemName: "light.beacon.max.fill")
                                    .font(.system(size: 14))
                                Text("ALARM TRIGGERED")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(DS.Color.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(DS.Color.danger.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        }

                        Spacer()

                        // State icon
                        Image(systemName: system.currentState.icon)
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(system.currentState == .triggered ? DS.Color.danger : accent)

                        // State label
                        Text(system.currentState.displayName)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(system.currentState == .triggered ? DS.Color.danger : accent)

                        Spacer()

                        // Arm mode buttons
                        HStack(spacing: 6) {
                            armButton(.stayArm, current: system)
                            armButton(.awayArm, current: system)
                            armButton(.nightArm, current: system)
                            armButton(.disarmed, current: system)
                        }
                    }
                } else {
                    Spacer()
                    Text("No system").font(.system(size: 14, design: .rounded)).foregroundColor(DS.Color.textTertiary)
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private func armButton(_ target: SecuritySystemTargetState, current system: SecuritySystemAccessory) -> some View {
        let isActive = system.currentState.rawValue == target.rawValue
        Button {
            manager.setSecuritySystemMode(for: system, mode: target)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: target.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(target.displayName)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
            }
            .foregroundColor(isActive ? accent : DS.Color.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isActive ? accent.opacity(0.15) : DS.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
        }
    }
}
