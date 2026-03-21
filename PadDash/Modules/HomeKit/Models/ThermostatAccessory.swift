import SwiftUI
import HomeKit

// MARK: - Thermostat Accessory Model

struct ThermostatAccessory: Identifiable {
    let id: UUID
    let accessory: HMAccessory
    let service: HMService
    var name: String
    var roomName: String
    var currentTemperature: Double  // Celsius from HomeKit
    var targetTemperature: Double   // Celsius from HomeKit
    var currentMode: ThermostatMode
    var targetMode: ThermostatMode
    var isStale: Bool = true

    // MARK: - Characteristics

    var currentTemperatureCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeCurrentTemperature }
    }

    var targetTemperatureCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeTargetTemperature }
    }

    var currentHeatingCoolingCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeCurrentHeatingCooling }
    }

    var targetHeatingCoolingCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeTargetHeatingCooling }
    }

    // MARK: - Display Helpers

    /// Convert Celsius to Fahrenheit for display
    static func celsiusToFahrenheit(_ celsius: Double) -> Double {
        celsius * 9.0 / 5.0 + 32.0
    }

    /// Format temperature for display (Fahrenheit)
    func displayCurrentTemp() -> String {
        let f = Self.celsiusToFahrenheit(currentTemperature)
        return String(format: "%.0f", f)
    }

    func displayTargetTemp() -> String {
        let f = Self.celsiusToFahrenheit(targetTemperature)
        return String(format: "%.0f", f)
    }
}

// MARK: - Thermostat Mode

enum ThermostatMode: Int {
    case off = 0
    case heat = 1
    case cool = 2
    case auto = 3

    var displayName: String {
        switch self {
        case .off:  return "Off"
        case .heat: return "Heat"
        case .cool: return "Cool"
        case .auto: return "Auto"
        }
    }

    var icon: String {
        switch self {
        case .off:  return "power"
        case .heat: return "flame.fill"
        case .cool: return "snowflake"
        case .auto: return "arrow.left.arrow.right"
        }
    }

    var accent: Color {
        switch self {
        case .off:  return DS.Color.textTertiary
        case .heat: return DS.Color.accentAmber
        case .cool: return DS.Color.accentBlue
        case .auto: return DS.Color.accentMint
        }
    }

    static func from(heatingCoolingValue: Int) -> ThermostatMode {
        ThermostatMode(rawValue: heatingCoolingValue) ?? .off
    }
}
