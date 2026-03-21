import SwiftUI

// MARK: - Timer Finished Overlay (multi-alert container)

struct TimerFinishedOverlay: View {
    var alertingSlots: [TimerSlotVM]

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture {} // block pass-through

            // Horizontally laid-out alert cards
            HStack(spacing: DS.Space.md) {
                ForEach(alertingSlots) { slot in
                    TimerFinishedCard(vm: slot)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                }
            }
            .padding(.horizontal, DS.Space.xl)
        }
        .animation(DS.Animation.snappy, value: alertingSlots.map(\.id))
    }
}

// MARK: - Individual Alert Card

private struct TimerFinishedCard: View {
    @ObservedObject var vm: TimerSlotVM

    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var bellBounce: CGFloat = 0
    @State private var contentOpacity: Double = 0
    @State private var glowOpacity: Double = 0

    var body: some View {
        ZStack {
            // Pulsing glow behind the card
            Circle()
                .fill(vm.accent.opacity(0.12))
                .frame(width: 280, height: 280)
                .scaleEffect(pulseScale)
                .opacity(glowOpacity)

            VStack(spacing: DS.Space.md) {

                // Animated bell icon
                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(vm.accent)
                    .symbolRenderingMode(.hierarchical)
                    .rotationEffect(.degrees(bellBounce))
                    .shadow(color: vm.accent.opacity(0.6), radius: 16)

                // Title
                VStack(spacing: 4) {
                    Text("Time's Up!")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Color.textPrimary)

                    Text(vm.timer.label)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(DS.Color.textSecondary)
                }

                // Ring showing completed state
                ZStack {
                    Circle()
                        .stroke(DS.Color.border, lineWidth: 5)
                        .frame(width: 96, height: 96)

                    Circle()
                        .trim(from: 0, to: 1)
                        .stroke(vm.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 96, height: 96)
                        .rotationEffect(.degrees(-90))

                    Text("00:00")
                        .font(.system(size: 22, weight: .thin, design: .monospaced))
                        .foregroundColor(vm.accent)
                }
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

                // Duration completed
                Text(formattedDuration(vm.timer.totalSeconds))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(DS.Color.textTertiary)

                // Action buttons
                VStack(spacing: DS.Space.xs) {

                    // Repeat (primary)
                    Button {
                        withAnimation(DS.Animation.snappy) {
                            vm.repeatTimer()
                        }
                    } label: {
                        Label("Repeat", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.Color.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(vm.accent)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                            .shadow(color: vm.accent.opacity(0.4), radius: 10, x: 0, y: 4)
                    }

                    // Dismiss
                    Button {
                        withAnimation(DS.Animation.snappy) {
                            vm.dismissAlert()
                        }
                    } label: {
                        Label("Dismiss", systemImage: "xmark")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DS.Color.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                    .stroke(DS.Color.borderStrong, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(DS.Space.lg)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(DS.Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                            .stroke(vm.accent.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: vm.accent.opacity(0.2), radius: 30, x: 0, y: 12)
            )
            .opacity(contentOpacity)
        }
        .onAppear { startAnimations() }
    }

    // MARK: - Animations

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.35)) {
            contentOpacity = 1
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.1)) {
            ringScale = 1.0
            ringOpacity = 1
        }

        withAnimation(
            .easeInOut(duration: 0.12)
            .repeatCount(12, autoreverses: true)
            .delay(0.2)
        ) {
            bellBounce = 18
        }

        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.3)) {
            pulseScale = 1.15
            glowOpacity = 1
        }
    }

    // MARK: - Helpers

    private func formattedDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%dh %02dm completed", h, m)
        } else if m > 0 && s > 0 {
            return String(format: "%dm %ds completed", m, s)
        } else if m > 0 {
            return String(format: "%dm completed", m)
        }
        return String(format: "%ds completed", s)
    }
}
