import SwiftUI

// MARK: - Timer Card

struct TimerCard: View {
    @ObservedObject var vm: TimerSlotVM
    var canRemove: Bool = false
    var onRemove: (() -> Void)?
    @State private var pulsing = false

    private let ringSize: CGFloat = 200

    var body: some View {
        DashCard {
            VStack(spacing: DS.Space.md) {

                // Label + action buttons
                HStack {
                    Text(vm.timer.label)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.Color.textSecondary)
                    Spacer()

                    if canRemove {
                        Button {
                            onRemove?()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DS.Color.textTertiary)
                                .padding(8)
                                .background(DS.Color.surfaceRaised)
                                .clipShape(Circle())
                        }
                    }

                    Button {
                        vm.isEditingDuration = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DS.Color.textSecondary)
                            .padding(8)
                            .background(DS.Color.surfaceRaised)
                            .clipShape(Circle())
                    }
                }

                // Ring + time display
                ZStack {
                    ArcRing(
                        progress: vm.timer.progress,
                        accent: vm.timer.accent,
                        isUrgent: vm.timer.isUrgent,
                        size: ringSize
                    )

                    VStack(spacing: 4) {
                        Text(vm.timer.formattedTime)
                            .font(.system(size: 42, weight: .thin, design: .monospaced))
                            .foregroundColor(
                                vm.timer.isUrgent ? DS.Color.danger : DS.Color.textPrimary
                            )
                            .scaleEffect(pulsing && vm.timer.isUrgent ? 1.04 : 1.0)
                            .animation(
                                vm.timer.isUrgent
                                    ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                                    : .default,
                                value: pulsing
                            )

                        stateLabel
                    }
                }
                .frame(width: ringSize, height: ringSize)
                .onAppear { pulsing = true }

                // Control row
                controlRow
            }
        }
        .sheet(isPresented: $vm.isEditingDuration) {
            DurationPickerSheet(vm: vm)
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - State label
    @ViewBuilder
    private var stateLabel: some View {
        switch vm.timer.state {
        case .idle:
            Text("READY")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(DS.Color.textTertiary)
                .tracking(2)
        case .running:
            Text("RUNNING")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(vm.timer.accent.opacity(0.8))
                .tracking(2)
        case .paused:
            Text("PAUSED")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(DS.Color.accentAmber.opacity(0.8))
                .tracking(2)
        case .finished:
            Text("DONE ✓")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(DS.Color.success)
                .tracking(2)
        }
    }

    // MARK: - Controls
    private var controlRow: some View {
        HStack(spacing: DS.Space.sm) {

            // Reset
            Button {
                withAnimation(DS.Animation.snappy) { vm.reset() }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DS.Color.textSecondary)
                    .frame(width: 48, height: 48)
                    .background(DS.Color.surfaceRaised)
                    .clipShape(Circle())
            }

            // Primary: play / pause
            Button {
                withAnimation(DS.Animation.snappy) {
                    if vm.timer.state == .running {
                        vm.pause()
                    } else {
                        vm.start()
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(vm.timer.accent)
                        .frame(width: 64, height: 64)
                        .shadow(color: vm.timer.accent.opacity(0.45), radius: 12, x: 0, y: 4)

                    Image(systemName: vm.timer.state == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(DS.Color.background)
                        .offset(x: vm.timer.state == .running ? 0 : 2)
                }
            }
            .disabled(vm.timer.state == .finished && vm.timer.remainingSeconds == 0)

            // Spacer mirror for layout balance
            Spacer().frame(width: 48, height: 48)
        }
        .frame(maxWidth: .infinity)
    }
}
