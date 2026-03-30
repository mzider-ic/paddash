import SwiftUI

// MARK: - Garage Door Card

struct GarageDoorCard: View {
    let widget: HomeKitWidget
    @ObservedObject var manager: HomeKitManager
    var onRemove: (() -> Void)?

    private var garageDoor: GarageDoorAccessory? { widget.garageDoor }
    private let accent = DS.Color.danger

    @State private var doorPosition: CGFloat = 0.0 // 0 = closed, 1 = open

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
                        Text(garageDoor?.roomName ?? "")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(DS.Color.textTertiary)
                    }
                    Spacer()

                    if let onRemove {
                        Button {
                            withAnimation(DS.Animation.snappy) { onRemove() }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(DS.Color.textTertiary)
                                .padding(6)
                                .background(DS.Color.surfaceRaised)
                                .clipShape(Circle())
                        }
                    }
                }

                if let door = garageDoor {
                    if door.isStale {
                        Spacer()
                        ProgressView()
                            .tint(accent)
                        Spacer()
                    } else {
                        // Animated garage door illustration
                        GarageDoorIllustration(
                            doorPosition: doorPosition,
                            currentState: door.currentState,
                            obstructionDetected: door.obstructionDetected,
                            accent: accent
                        )

                        // State text
                        HStack(spacing: 6) {
                            if door.obstructionDetected {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(DS.Color.accentAmber)
                            }
                            Text(door.obstructionDetected
                                 ? "Obstruction"
                                 : door.currentState.displayName)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(
                                    door.obstructionDetected ? DS.Color.accentAmber : accent
                                )
                        }

                        // Open/Close button
                        Button {
                            manager.toggleGarageDoor(for: door)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: buttonIcon(for: door))
                                    .font(.system(size: 13, weight: .semibold))
                                Text(buttonLabel(for: door))
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
                    Text("No garage door")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(DS.Color.textTertiary)
                    Spacer()
                }
            }
            .onChange(of: garageDoor?.currentState) { newState in
                guard let state = newState else { return }
                animateDoorPosition(to: state)
            }
            .onAppear {
                if let state = garageDoor?.currentState {
                    switch state {
                    case .open:    doorPosition = 1.0
                    case .closed:  doorPosition = 0.0
                    case .opening: doorPosition = 0.5
                    case .closing: doorPosition = 0.5
                    case .stopped: doorPosition = 0.5
                    }
                }
            }
        }
    }

    // MARK: - Animation Logic

    private func animateDoorPosition(to state: GarageDoorState) {
        switch state {
        case .open:
            withAnimation(DS.Animation.snappy) {
                doorPosition = 1.0
            }
        case .closed:
            withAnimation(DS.Animation.snappy) {
                doorPosition = 0.0
            }
        case .opening:
            withAnimation(.linear(duration: 15)) {
                doorPosition = 1.0
            }
        case .closing:
            withAnimation(.linear(duration: 15)) {
                doorPosition = 0.0
            }
        case .stopped:
            break
        }
    }

    // MARK: - Button Helpers

    private func buttonLabel(for door: GarageDoorAccessory) -> String {
        switch door.currentState {
        case .open, .opening:  return "Close"
        case .closed, .closing, .stopped: return "Open"
        }
    }

    private func buttonIcon(for door: GarageDoorAccessory) -> String {
        switch door.currentState {
        case .open, .opening:  return "arrow.down.to.line"
        case .closed, .closing, .stopped: return "arrow.up.to.line"
        }
    }
}

// MARK: - Garage Door Illustration

struct GarageDoorIllustration: View {
    var doorPosition: CGFloat // 0 = closed, 1 = open
    var currentState: GarageDoorState
    var obstructionDetected: Bool
    var accent: Color

    private let segmentCount = 4

    var body: some View {
        GeometryReader { geo in
            let frameWidth = geo.size.width * 0.55
            let frameHeight = geo.size.height * 0.85
            let xOffset = (geo.size.width - frameWidth) / 2
            let yOffset = (geo.size.height - frameHeight) / 2
            let doorHeight = frameHeight * (1.0 - doorPosition)

            Canvas { context, size in
                let frameRect = CGRect(
                    x: xOffset,
                    y: yOffset,
                    width: frameWidth,
                    height: frameHeight
                )

                // Ground line
                let groundY = yOffset + frameHeight
                let groundPath = Path { p in
                    p.move(to: CGPoint(x: xOffset - 10, y: groundY))
                    p.addLine(to: CGPoint(x: xOffset + frameWidth + 10, y: groundY))
                }
                context.stroke(groundPath, with: .color(DS.Color.textTertiary), lineWidth: 2)

                // Garage frame (left, right, top)
                let framePath = Path { p in
                    p.move(to: CGPoint(x: frameRect.minX, y: frameRect.maxY))
                    p.addLine(to: CGPoint(x: frameRect.minX, y: frameRect.minY))
                    p.addLine(to: CGPoint(x: frameRect.maxX, y: frameRect.minY))
                    p.addLine(to: CGPoint(x: frameRect.maxX, y: frameRect.maxY))
                }
                context.stroke(framePath, with: .color(DS.Color.textTertiary), lineWidth: 2)

                // Door panel (slides down from top)
                if doorHeight > 1 {
                    let doorRect = CGRect(
                        x: frameRect.minX + 2,
                        y: frameRect.maxY - doorHeight,
                        width: frameWidth - 4,
                        height: doorHeight
                    )

                    // Door fill
                    let doorFill = currentState.isTransitional
                        ? accent.opacity(0.2)
                        : (doorPosition < 0.5 ? DS.Color.surfaceRaised : accent.opacity(0.08))
                    context.fill(Path(doorRect), with: .color(doorFill))

                    // Door border
                    context.stroke(
                        Path(doorRect),
                        with: .color(DS.Color.border),
                        lineWidth: 1
                    )

                    // Segment lines
                    if doorHeight > 20 {
                        for i in 1..<segmentCount {
                            let segY = doorRect.minY + doorRect.height * CGFloat(i) / CGFloat(segmentCount)
                            let segPath = Path { p in
                                p.move(to: CGPoint(x: doorRect.minX + 4, y: segY))
                                p.addLine(to: CGPoint(x: doorRect.maxX - 4, y: segY))
                            }
                            context.stroke(segPath, with: .color(DS.Color.border), lineWidth: 1)
                        }
                    }

                    // Small handle on door center
                    if doorHeight > 30 {
                        let handleWidth: CGFloat = 12
                        let handleHeight: CGFloat = 4
                        let handleRect = CGRect(
                            x: doorRect.midX - handleWidth / 2,
                            y: doorRect.midY - handleHeight / 2,
                            width: handleWidth,
                            height: handleHeight
                        )
                        context.fill(
                            Path(roundedRect: handleRect, cornerRadius: 2),
                            with: .color(DS.Color.textTertiary)
                        )
                    }
                }
            }

            // Obstruction warning overlay
            if obstructionDetected {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DS.Color.accentAmber)
                    .position(x: geo.size.width / 2, y: yOffset + frameHeight - 20)
            }
        }
        .aspectRatio(1.2, contentMode: .fit)
    }
}
