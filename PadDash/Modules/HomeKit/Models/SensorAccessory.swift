import SwiftUI
import HomeKit

// MARK: - Sensor Type

enum SensorType: String, CaseIterable, Codable {
    case temperature
    case motion
    case contact
    case leak
    case airQuality
    case carbonMonoxide
    case carbonDioxide
    case occupancy
    case lightLevel
    case smoke

    var serviceType: String {
        switch self {
        case .temperature:     return HMServiceTypeTemperatureSensor
        case .motion:          return HMServiceTypeMotionSensor
        case .contact:         return HMServiceTypeContactSensor
        case .leak:            return HMServiceTypeLeakSensor
        case .airQuality:      return HMServiceTypeAirQualitySensor
        case .carbonMonoxide:  return HMServiceTypeCarbonMonoxideSensor
        case .carbonDioxide:   return HMServiceTypeCarbonDioxideSensor
        case .occupancy:       return HMServiceTypeOccupancySensor
        case .lightLevel:      return HMServiceTypeLightSensor
        case .smoke:           return HMServiceTypeSmokeSensor
        }
    }

    var primaryCharacteristicType: String {
        switch self {
        case .temperature:     return HMCharacteristicTypeCurrentTemperature
        case .motion:          return HMCharacteristicTypeMotionDetected
        case .contact:         return HMCharacteristicTypeContactState
        case .leak:            return HMCharacteristicTypeLeakDetected
        case .airQuality:      return HMCharacteristicTypeAirQuality
        case .carbonMonoxide:  return HMCharacteristicTypeCarbonMonoxideDetected
        case .carbonDioxide:   return HMCharacteristicTypeCarbonDioxideDetected
        case .occupancy:       return HMCharacteristicTypeOccupancyDetected
        case .lightLevel:      return HMCharacteristicTypeCurrentLightLevel
        case .smoke:           return HMCharacteristicTypeSmokeDetected
        }
    }

    /// Secondary characteristic for sensors that report a level in addition to a detected/not flag
    var secondaryCharacteristicType: String? {
        switch self {
        case .carbonMonoxide: return HMCharacteristicTypeCarbonMonoxideLevel
        case .carbonDioxide:  return HMCharacteristicTypeCarbonDioxideLevel
        default:              return nil
        }
    }

    var displayName: String {
        switch self {
        case .temperature:     return "Temperature"
        case .motion:          return "Motion"
        case .contact:         return "Contact"
        case .leak:            return "Leak"
        case .airQuality:      return "Air Quality"
        case .carbonMonoxide:  return "CO"
        case .carbonDioxide:   return "CO\u{2082}"
        case .occupancy:       return "Occupancy"
        case .lightLevel:      return "Light Level"
        case .smoke:           return "Smoke"
        }
    }

    var icon: String {
        switch self {
        case .temperature:     return "thermometer.medium"
        case .motion:          return "figure.walk.motion"
        case .contact:         return "door.left.hand.open"
        case .leak:            return "drop.triangle.fill"
        case .airQuality:      return "aqi.medium"
        case .carbonMonoxide:  return "carbon.monoxide.cloud.fill"
        case .carbonDioxide:   return "carbon.dioxide.cloud.fill"
        case .occupancy:       return "person.fill"
        case .lightLevel:      return "sun.max.fill"
        case .smoke:           return "smoke.fill"
        }
    }

    var unit: String {
        switch self {
        case .temperature:     return "°"
        case .lightLevel:      return " lux"
        case .carbonMonoxide:  return " ppm"
        case .carbonDioxide:   return " ppm"
        default:               return ""
        }
    }

    /// Whether this sensor type represents an alert/danger condition
    var isAlertType: Bool {
        switch self {
        case .leak, .smoke, .carbonMonoxide, .carbonDioxide:
            return true
        default:
            return false
        }
    }

    /// Whether the sensor value is boolean-style (detected/not)
    var isBooleanSensor: Bool {
        switch self {
        case .motion, .contact, .leak, .occupancy, .smoke, .carbonMonoxide, .carbonDioxide:
            return true
        case .temperature, .airQuality, .lightLevel:
            return false
        }
    }

    /// Format a primary value for display
    func formatPrimaryValue(_ value: Double?) -> String {
        guard let value else { return "—" }
        switch self {
        case .temperature:
            let fahrenheit = value * 9.0 / 5.0 + 32.0
            return String(format: "%.0f°", fahrenheit)
        case .lightLevel:
            return String(format: "%.0f lux", value)
        case .airQuality:
            let level = Int(value)
            switch level {
            case 1:  return "Excellent"
            case 2:  return "Good"
            case 3:  return "Fair"
            case 4:  return "Inferior"
            case 5:  return "Poor"
            default: return "Unknown"
            }
        case .motion:
            return value > 0 ? "Motion" : "Clear"
        case .contact:
            return value > 0 ? "Open" : "Closed"
        case .leak:
            return value > 0 ? "Leak!" : "Dry"
        case .occupancy:
            return value > 0 ? "Occupied" : "Empty"
        case .smoke:
            return value > 0 ? "Smoke!" : "Clear"
        case .carbonMonoxide:
            return value > 0 ? "Detected!" : "Normal"
        case .carbonDioxide:
            return value > 0 ? "Detected!" : "Normal"
        }
    }

    /// Whether the current value represents an alert state
    func isAlerted(_ value: Double?) -> Bool {
        guard let value else { return false }
        switch self {
        case .leak, .smoke:          return value > 0
        case .carbonMonoxide:        return value > 0
        case .carbonDioxide:         return value > 0
        default:                     return false
        }
    }
}

// MARK: - Sensor Accessory Model

struct SensorAccessory: Identifiable {
    let id: UUID
    let accessory: HMAccessory
    let service: HMService
    let sensorType: SensorType
    var name: String
    var roomName: String
    var primaryValue: Double?
    var secondaryValue: Double?   // Level for CO/CO2
    var isStale: Bool = true

    var primaryCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == sensorType.primaryCharacteristicType }
    }

    var secondaryCharacteristic: HMCharacteristic? {
        guard let type = sensorType.secondaryCharacteristicType else { return nil }
        return service.characteristics.first { $0.characteristicType == type }
    }

    var displayValue: String {
        sensorType.formatPrimaryValue(primaryValue)
    }

    var isAlerted: Bool {
        sensorType.isAlerted(primaryValue)
    }
}
