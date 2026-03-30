import SwiftUI

struct LockCard: View {
    let widget: HomeKitWidget
    @ObservedObject var manager: HomeKitManager
    var onRemove: (() -> Void)?

    private var lock: LockAccessory? { widget.lock }
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
                        Text(lock?.roomName ?? "")
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

                if let lock {
                    if lock.isStale {
                        Spacer()
                        ProgressView().tint(accent)
                        Spacer()
                    } else {
                        Spacer()

                        // Lock icon
                        if #available(iOS 17.0, *) {
                            Image(systemName: lock.currentState.icon)
                                .font(.system(size: 44, weight: .light))
                                .foregroundColor(lock.currentState.isAlert ? DS.Color.danger : accent)
                                .symbolEffect(.bounce, value: lock.currentState.rawValue)
                        } else {
                            Image(systemName: lock.currentState.icon)
                                .font(.system(size: 44, weight: .light))
                                .foregroundColor(lock.currentState.isAlert ? DS.Color.danger : accent)
                        }

                        // State label
                        HStack(spacing: 6) {
                            if lock.currentState == .jammed {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(DS.Color.danger)
                            }
                            Text(lock.currentState.displayName)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(lock.currentState.isAlert ? DS.Color.danger : accent)
                        }

                        Spacer()

                        // Toggle button
                        Button {
                            withAnimation(DS.Animation.snappy) { manager.toggleLock(for: lock) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: lock.currentState == .secured ? "lock.open.fill" : "lock.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(lock.currentState == .secured ? "Unlock" : "Lock")
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
                    Text("No lock").font(.system(size: 14, design: .rounded)).foregroundColor(DS.Color.textTertiary)
                    Spacer()
                }
            }
        }
    }
}
