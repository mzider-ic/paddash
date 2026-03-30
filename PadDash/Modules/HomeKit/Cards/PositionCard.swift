import SwiftUI

struct PositionCard: View {
    let widget: HomeKitWidget
    @ObservedObject var manager: HomeKitManager
    var onRemove: (() -> Void)?

    private var position: PositionAccessory? { widget.position }
    private let accent = DS.Color.accentIndigo

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
                        Text(position?.roomName ?? "")
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

                if let pos = position {
                    if pos.isStale {
                        Spacer()
                        ProgressView().tint(accent)
                        Spacer()
                    } else {
                        Spacer()

                        // Icon for the kind
                        Image(systemName: pos.kind.icon)
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(accent)

                        // Position label
                        VStack(spacing: 2) {
                            Text("\(pos.currentPosition)%")
                                .font(.system(size: 24, weight: .light, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(accent)
                            Text(pos.currentPosition == 0 ? "Closed" : pos.currentPosition == 100 ? "Open" : "Partial")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(DS.Color.textTertiary)
                        }

                        Spacer()

                        // Position slider
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.to.line")
                                .font(.system(size: 11))
                                .foregroundColor(DS.Color.textTertiary)
                            Slider(
                                value: Binding(
                                    get: { Double(pos.targetPosition) },
                                    set: { manager.setTargetPosition(for: pos, value: Int($0)) }
                                ),
                                in: 0...100,
                                step: 1
                            )
                            .tint(accent)
                            Image(systemName: "arrow.up.to.line")
                                .font(.system(size: 11))
                                .foregroundColor(DS.Color.textTertiary)
                        }
                    }
                } else {
                    Spacer()
                    Text("No device").font(.system(size: 14, design: .rounded)).foregroundColor(DS.Color.textTertiary)
                    Spacer()
                }
            }
        }
    }
}
