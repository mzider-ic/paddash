import SwiftUI
import HomeKit

// MARK: - Security System State

enum SecuritySystemState: Int {
    case stayArm = 0
    case awayArm = 1
    case nightArm = 2
    case disarmed = 3
    case triggered = 4

    var displayName: String {
        switch self {
        case .stayArm:   return "Home"
        case .awayArm:   return "Away"
        case .nightArm:  return "Night"
        case .disarmed:  return "Disarmed"
        case .triggered: return "Triggered"
        }
    }

    var icon: String {
        switch self {
        case .stayArm:   return "house.lodge.fill"
        case .awayArm:   return "figure.walk"
        case .nightArm:  return "moon.fill"
        case .disarmed:  return "lock.open.fill"
        case .triggered: return "light.beacon.max.fill"
        }
    }

    var isArmed: Bool {
        self != .disarmed && self != .triggered
    }
}

// MARK: - Security System Target State

enum SecuritySystemTargetState: Int {
    case stayArm = 0
    case awayArm = 1
    case nightArm = 2
    case disarmed = 3

    var displayName: String {
        switch self {
        case .stayArm:  return "Home"
        case .awayArm:  return "Away"
        case .nightArm: return "Night"
        case .disarmed: return "Disarmed"
        }
    }

    var icon: String {
        switch self {
        case .stayArm:  return "house.lodge.fill"
        case .awayArm:  return "figure.walk"
        case .nightArm: return "moon.fill"
        case .disarmed: return "lock.open.fill"
        }
    }
}

// MARK: - Security System Accessory Model

struct SecuritySystemAccessory: Identifiable {
    let id: UUID
    let accessory: HMAccessory
    let service: HMService
    var name: String
    var roomName: String
    var currentState: SecuritySystemState
    var targetState: SecuritySystemTargetState
    var isStale: Bool = true

    var currentStateCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeCurrentSecuritySystemState }
    }

    var targetStateCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeTargetSecuritySystemState }
    }
}
