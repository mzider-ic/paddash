import SwiftUI

// MARK: - Arc Progress Ring

struct ArcRing: View {
    var progress: Double       // 0…1
    var accent: Color
    var isUrgent: Bool
    var size: CGFloat

    private var strokeWidth: CGFloat { size * 0.07 }
    private var radius: CGFloat      { (size - strokeWidth) / 2 }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(DS.Color.border, lineWidth: strokeWidth)
                .frame(width: size, height: size)

            // Fill
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                .stroke(
                    isUrgent ? DS.Color.danger : accent,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(DS.Animation.tick, value: progress)

            // Glow when urgent
            if isUrgent {
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                    .stroke(DS.Color.danger.opacity(0.35), lineWidth: strokeWidth * 2.5)
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 8)
                    .animation(DS.Animation.tick, value: progress)
            }
        }
    }
}

// MARK: - Dot cap at leading edge

struct RingEndDot: View {
    var progress: Double
    var accent: Color
    var ringSize: CGFloat
    var strokeWidth: CGFloat

    var body: some View {
        let angle = Angle.degrees(360 * progress - 90)
        let r = (ringSize - strokeWidth) / 2
        let x = cos(angle.radians) * r
        let y = sin(angle.radians) * r

        Circle()
            .fill(accent)
            .frame(width: strokeWidth, height: strokeWidth)
            .offset(x: x, y: y)
    }
}
