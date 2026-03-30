import SwiftUI

struct SensorCard: View {
    let widget: HomeKitWidget
    @ObservedObject var manager: HomeKitManager
    var onRemove: (() -> Void)?

    private var sensor: SensorAccessory? { widget.sensor }
    private let accent = DS.Color.accentTeal

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
                        Text(sensor?.roomName ?? "")
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

                if let sensor {
                    if sensor.isStale {
                        Spacer()
                        ProgressView().tint(accent)
                        Spacer()
                    } else {
                        Spacer()

                        // Alert styling for danger sensors
                        let isAlert = sensor.isAlerted
                        let displayAccent = isAlert ? DS.Color.danger : accent

                        // Sensor icon
                        if #available(iOS 17.0, *) {
                            Image(systemName: sensor.sensorType.icon)
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(displayAccent)
                                .symbolEffect(.pulse, isActive: isAlert)
                        } else {
                            Image(systemName: sensor.sensorType.icon)
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(displayAccent)
                                
                        }

                        // Primary value — large for numeric, medium for boolean
                        if sensor.sensorType.isBooleanSensor {
                            Text(sensor.displayValue)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(displayAccent)
                        } else {
                            Text(sensor.displayValue)
                                .font(.system(size: 28, weight: .light, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(displayAccent)
                        }

                        // Secondary value (CO/CO2 level)
                        if let secondary = sensor.secondaryValue, sensor.sensorType.secondaryCharacteristicType != nil {
                            Text(String(format: "%.0f ppm", secondary))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(DS.Color.textTertiary)
                        }

                        // Sensor type label
                        Text(sensor.sensorType.displayName)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(DS.Color.textTertiary)

                        Spacer()

                        // Alert banner for danger sensors
                        if isAlert {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                Text(alertMessage(for: sensor.sensorType))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(DS.Color.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(DS.Color.danger.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        }
                    }
                } else {
                    Spacer()
                    Text("No sensor").font(.system(size: 14, design: .rounded)).foregroundColor(DS.Color.textTertiary)
                    Spacer()
                }
            }
        }
    }

    private func alertMessage(for type: SensorType) -> String {
        switch type {
        case .leak:           return "Leak Detected!"
        case .smoke:          return "Smoke Detected!"
        case .carbonMonoxide: return "CO Detected!"
        case .carbonDioxide:  return "CO\u{2082} Detected!"
        default:              return "Alert"
        }
    }
}
