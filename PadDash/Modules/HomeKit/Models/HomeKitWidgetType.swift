import SwiftUI

// MARK: - HomeKit Widget Type

enum HomeKitWidgetType: String, CaseIterable, Identifiable {
    // Existing
    case lightDimmer
    case thermostat
    case humidity
    case garageDoor

    // Controllable devices
    case lock
    case fan
    case switchToggle
    case outlet
    case windowCovering
    case valve
    case securitySystem
    case door
    case window
    case speaker

    // Sensors
    case temperatureSensor
    case motionSensor
    case contactSensor
    case leakSensor
    case airQualitySensor
    case carbonMonoxideSensor
    case carbonDioxideSensor
    case occupancySensor
    case lightSensor
    case smokeSensor

    var id: String { rawValue }

    // MARK: - Categories (for grouped picker)

    enum Category: String, CaseIterable {
        case lighting        = "Lighting"
        case climate         = "Climate"
        case accessSecurity  = "Access & Security"
        case switchesOutlets = "Switches & Outlets"
        case positionControl = "Position Controls"
        case water           = "Water"
        case media           = "Media"
        case sensors         = "Sensors"
    }

    var category: Category {
        switch self {
        case .lightDimmer:                                                     return .lighting
        case .thermostat, .humidity, .fan:                                      return .climate
        case .lock, .garageDoor, .securitySystem:                              return .accessSecurity
        case .switchToggle, .outlet:                                           return .switchesOutlets
        case .door, .window, .windowCovering:                                  return .positionControl
        case .valve:                                                           return .water
        case .speaker:                                                         return .media
        case .temperatureSensor, .motionSensor, .contactSensor, .leakSensor,
             .airQualitySensor, .carbonMonoxideSensor, .carbonDioxideSensor,
             .occupancySensor, .lightSensor, .smokeSensor:                     return .sensors
        }
    }

    static var groupedByCategory: [(category: Category, types: [HomeKitWidgetType])] {
        Category.allCases.compactMap { cat in
            let types = allCases.filter { $0.category == cat }
            return types.isEmpty ? nil : (category: cat, types: types)
        }
    }

    var displayName: String {
        switch self {
        case .lightDimmer:          return "Light Dimmer"
        case .thermostat:           return "Thermostat"
        case .humidity:             return "Humidity"
        case .garageDoor:           return "Garage Door"
        case .lock:                 return "Lock"
        case .fan:                  return "Fan"
        case .switchToggle:         return "Switch"
        case .outlet:               return "Outlet"
        case .windowCovering:       return "Blinds"
        case .valve:                return "Valve"
        case .securitySystem:       return "Security"
        case .door:                 return "Door"
        case .window:               return "Window"
        case .speaker:              return "Speaker"
        case .temperatureSensor:    return "Temperature"
        case .motionSensor:         return "Motion"
        case .contactSensor:        return "Contact"
        case .leakSensor:           return "Leak"
        case .airQualitySensor:     return "Air Quality"
        case .carbonMonoxideSensor: return "CO"
        case .carbonDioxideSensor:  return "CO\u{2082}"
        case .occupancySensor:      return "Occupancy"
        case .lightSensor:          return "Light Level"
        case .smokeSensor:          return "Smoke"
        }
    }

    var icon: String {
        switch self {
        case .lightDimmer:          return "lightbulb.fill"
        case .thermostat:           return "thermometer.medium"
        case .humidity:             return "humidity.fill"
        case .garageDoor:           return "door.garage.closed"
        case .lock:                 return "lock.fill"
        case .fan:                  return "fan.fill"
        case .switchToggle:         return "light.switch.2"
        case .outlet:               return "powerplug.fill"
        case .windowCovering:       return "blinds.vertical.closed"
        case .valve:                return "spigot.fill"
        case .securitySystem:       return "shield.lefthalf.filled"
        case .door:                 return "door.left.hand.closed"
        case .window:               return "window.vertical.closed"
        case .speaker:              return "hifispeaker.fill"
        case .temperatureSensor:    return "thermometer.medium"
        case .motionSensor:         return "figure.walk.motion"
        case .contactSensor:        return "door.left.hand.open"
        case .leakSensor:           return "drop.triangle.fill"
        case .airQualitySensor:     return "aqi.medium"
        case .carbonMonoxideSensor: return "carbon.monoxide.cloud.fill"
        case .carbonDioxideSensor:  return "carbon.dioxide.cloud.fill"
        case .occupancySensor:      return "person.fill"
        case .lightSensor:          return "sun.max.fill"
        case .smokeSensor:          return "smoke.fill"
        }
    }

    var description: String {
        switch self {
        case .lightDimmer:          return "Control brightness and power for a light"
        case .thermostat:           return "View and set temperature for a thermostat"
        case .humidity:             return "View humidity across all sensors in your home"
        case .garageDoor:           return "Open, close, and monitor a garage door"
        case .lock:                 return "Lock or unlock a door lock"
        case .fan:                  return "Control power, speed, and direction"
        case .switchToggle:         return "Toggle a smart switch on or off"
        case .outlet:               return "Control a smart outlet"
        case .windowCovering:       return "Adjust blinds or shade position"
        case .valve:                return "Open or close a valve or sprinkler"
        case .securitySystem:       return "Monitor and arm your security system"
        case .door:                 return "Control a motorised door position"
        case .window:               return "Control a motorised window position"
        case .speaker:              return "Adjust volume and mute a speaker"
        case .temperatureSensor:    return "Monitor ambient temperature"
        case .motionSensor:         return "Detect motion in a room"
        case .contactSensor:        return "Monitor door or window open/closed"
        case .leakSensor:           return "Alert when water leak is detected"
        case .airQualitySensor:     return "Monitor indoor air quality level"
        case .carbonMonoxideSensor: return "Alert when CO is detected"
        case .carbonDioxideSensor:  return "Monitor CO\u{2082} levels"
        case .occupancySensor:      return "Detect room occupancy"
        case .lightSensor:          return "Monitor ambient light level"
        case .smokeSensor:          return "Alert when smoke is detected"
        }
    }

    var accent: Color {
        switch self {
        case .lightDimmer:                                  return DS.Color.accentAmber
        case .thermostat:                                   return DS.Color.accentBlue
        case .humidity:                                     return DS.Color.accentMint
        case .garageDoor:                                   return DS.Color.danger
        case .lock, .securitySystem:                        return DS.Color.accentPurple
        case .fan, .valve:                                  return DS.Color.accentGreen
        case .switchToggle, .outlet:                        return DS.Color.accentAmber
        case .door, .window, .windowCovering:               return DS.Color.accentIndigo
        case .speaker:                                      return DS.Color.accentBlue
        case .temperatureSensor, .motionSensor,
             .contactSensor, .occupancySensor,
             .lightSensor, .airQualitySensor:               return DS.Color.accentTeal
        case .leakSensor, .smokeSensor,
             .carbonMonoxideSensor, .carbonDioxideSensor:   return DS.Color.danger
        }
    }

    /// Whether this widget type requires selecting a specific accessory
    var requiresAccessorySelection: Bool {
        switch self {
        case .humidity: return false
        default:        return true
        }
    }

    /// The SensorType this widget type maps to, if it's a sensor widget
    var sensorType: SensorType? {
        switch self {
        case .temperatureSensor:    return .temperature
        case .motionSensor:         return .motion
        case .contactSensor:        return .contact
        case .leakSensor:           return .leak
        case .airQualitySensor:     return .airQuality
        case .carbonMonoxideSensor: return .carbonMonoxide
        case .carbonDioxideSensor:  return .carbonDioxide
        case .occupancySensor:      return .occupancy
        case .lightSensor:          return .lightLevel
        case .smokeSensor:          return .smoke
        default:                    return nil
        }
    }
}

// MARK: - HomeKit Widget

struct HomeKitWidget: Identifiable {
    let id: UUID
    let type: HomeKitWidgetType
    var light: LightAccessory
    var thermostat: ThermostatAccessory?
    var garageDoor: GarageDoorAccessory?
    var lock: LockAccessory?
    var fan: FanAccessory?
    var switchDevice: SwitchAccessory?
    var position: PositionAccessory?
    var valve: ValveAccessory?
    var securitySystem: SecuritySystemAccessory?
    var speaker: SpeakerAccessory?
    var sensor: SensorAccessory?
    var customName: String?  // Local-only rename

    /// Display name: custom name if set, otherwise the accessory name
    var displayName: String {
        if let custom = customName, !custom.isEmpty { return custom }
        switch type {
        case .lightDimmer:                               return light.name
        case .thermostat:                                return thermostat?.name ?? "Thermostat"
        case .humidity:                                  return "Humidity"
        case .garageDoor:                                return garageDoor?.name ?? "Garage Door"
        case .lock:                                      return lock?.name ?? "Lock"
        case .fan:                                       return fan?.name ?? "Fan"
        case .switchToggle, .outlet:                     return switchDevice?.name ?? "Switch"
        case .door, .window, .windowCovering:            return position?.name ?? type.displayName
        case .valve:                                     return valve?.name ?? "Valve"
        case .securitySystem:                            return securitySystem?.name ?? "Security"
        case .speaker:                                   return speaker?.name ?? "Speaker"
        case .temperatureSensor, .motionSensor,
             .contactSensor, .leakSensor,
             .airQualitySensor, .carbonMonoxideSensor,
             .carbonDioxideSensor, .occupancySensor,
             .lightSensor, .smokeSensor:                 return sensor?.name ?? type.displayName
        }
    }

    var roomName: String {
        switch type {
        case .lightDimmer:                               return light.roomName
        case .thermostat:                                return thermostat?.roomName ?? ""
        case .humidity:                                  return ""
        case .garageDoor:                                return garageDoor?.roomName ?? ""
        case .lock:                                      return lock?.roomName ?? ""
        case .fan:                                       return fan?.roomName ?? ""
        case .switchToggle, .outlet:                     return switchDevice?.roomName ?? ""
        case .door, .window, .windowCovering:            return position?.roomName ?? ""
        case .valve:                                     return valve?.roomName ?? ""
        case .securitySystem:                            return securitySystem?.roomName ?? ""
        case .speaker:                                   return speaker?.roomName ?? ""
        case .temperatureSensor, .motionSensor,
             .contactSensor, .leakSensor,
             .airQualitySensor, .carbonMonoxideSensor,
             .carbonDioxideSensor, .occupancySensor,
             .lightSensor, .smokeSensor:                 return sensor?.roomName ?? ""
        }
    }

    /// Reference ID for persistence
    var referenceID: String {
        switch type {
        case .lightDimmer:                               return light.id.uuidString
        case .thermostat:                                return thermostat?.id.uuidString ?? ""
        case .humidity:                                  return "humidity"
        case .garageDoor:                                return garageDoor?.id.uuidString ?? ""
        case .lock:                                      return lock?.id.uuidString ?? ""
        case .fan:                                       return fan?.id.uuidString ?? ""
        case .switchToggle, .outlet:                     return switchDevice?.id.uuidString ?? ""
        case .door, .window, .windowCovering:            return position?.id.uuidString ?? ""
        case .valve:                                     return valve?.id.uuidString ?? ""
        case .securitySystem:                            return securitySystem?.id.uuidString ?? ""
        case .speaker:                                   return speaker?.id.uuidString ?? ""
        case .temperatureSensor, .motionSensor,
             .contactSensor, .leakSensor,
             .airQualitySensor, .carbonMonoxideSensor,
             .carbonDioxideSensor, .occupancySensor,
             .lightSensor, .smokeSensor:                 return sensor?.id.uuidString ?? ""
        }
    }
}
