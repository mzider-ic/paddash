import SwiftUI
import HomeKit

// MARK: - Garage Door State

enum GarageDoorState: Int {
    case open = 0
    case closed = 1
    case opening = 2
    case closing = 3
    case stopped = 4

    var displayName: String {
        switch self {
        case .open:    return "Open"
        case .closed:  return "Closed"
        case .opening: return "Opening"
        case .closing: return "Closing"
        case .stopped: return "Stopped"
        }
    }

    var icon: String {
        switch self {
        case .open:    return "door.garage.open"
        case .closed:  return "door.garage.closed"
        case .opening: return "door.garage.open"
        case .closing: return "door.garage.closed"
        case .stopped: return "exclamationmark.triangle.fill"
        }
    }

    /// Whether the door is in a transitional (animating) state
    var isTransitional: Bool {
        self == .opening || self == .closing
    }
}

// MARK: - Target Door State

enum GarageDoorTargetState: Int {
    case open = 0
    case closed = 1
}

// MARK: - Garage Door Accessory Model

struct GarageDoorAccessory: Identifiable {
    let id: UUID
    let accessory: HMAccessory
    let service: HMService
    var name: String
    var roomName: String
    var currentState: GarageDoorState
    var targetState: GarageDoorTargetState
    var obstructionDetected: Bool
    var isStale: Bool = true

    // MARK: - Characteristics

    var currentDoorStateCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeCurrentDoorState }
    }

    var targetDoorStateCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeTargetDoorState }
    }

    var obstructionDetectedCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeObstructionDetected }
    }
}
