import SwiftUI

// MARK: - HomeKit Widget Type

enum HomeKitWidgetType: String, CaseIterable, Identifiable {
    case lightDimmer
    case thermostat
    case humidity

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lightDimmer: return "Light Dimmer"
        case .thermostat:  return "Thermostat"
        case .humidity:    return "Humidity"
        }
    }

    var icon: String {
        switch self {
        case .lightDimmer: return "lightbulb.fill"
        case .thermostat:  return "thermometer.medium"
        case .humidity:    return "humidity.fill"
        }
    }

    var description: String {
        switch self {
        case .lightDimmer: return "Control brightness and power for a light"
        case .thermostat:  return "View and set temperature for a thermostat"
        case .humidity:    return "View humidity across all sensors in your home"
        }
    }

    var accent: Color {
        switch self {
        case .lightDimmer: return DS.Color.accentAmber
        case .thermostat:  return DS.Color.accentBlue
        case .humidity:    return DS.Color.accentMint
        }
    }

    /// Whether this widget type requires selecting a specific accessory
    var requiresAccessorySelection: Bool {
        switch self {
        case .lightDimmer, .thermostat: return true
        case .humidity: return false
        }
    }
}

// MARK: - HomeKit Widget

struct HomeKitWidget: Identifiable {
    let id: UUID
    let type: HomeKitWidgetType
    var light: LightAccessory
    var thermostat: ThermostatAccessory?
    var customName: String?  // Local-only rename

    /// Display name: custom name if set, otherwise the accessory name
    var displayName: String {
        if let custom = customName, !custom.isEmpty { return custom }
        switch type {
        case .lightDimmer: return light.name
        case .thermostat:  return thermostat?.name ?? "Thermostat"
        case .humidity:    return "Humidity"
        }
    }

    var roomName: String {
        switch type {
        case .lightDimmer: return light.roomName
        case .thermostat:  return thermostat?.roomName ?? ""
        case .humidity:    return ""
        }
    }

    /// Reference ID for persistence (light ID, thermostat ID, or "humidity")
    var referenceID: String {
        switch type {
        case .lightDimmer: return light.id.uuidString
        case .thermostat:  return thermostat?.id.uuidString ?? ""
        case .humidity:    return "humidity"
        }
    }
}
