import SwiftUI
import HomeKit

// MARK: - Position Device Kind

enum PositionDeviceKind: String, Codable {
    case door
    case window
    case windowCovering

    var icon: String {
        switch self {
        case .door:           return "door.left.hand.closed"
        case .window:         return "window.vertical.closed"
        case .windowCovering: return "blinds.vertical.closed"
        }
    }

    var displayName: String {
        switch self {
        case .door:           return "Door"
        case .window:         return "Window"
        case .windowCovering: return "Blinds"
        }
    }
}

// MARK: - Position Accessory Model

struct PositionAccessory: Identifiable {
    let id: UUID
    let accessory: HMAccessory
    let service: HMService
    let kind: PositionDeviceKind
    var name: String
    var roomName: String
    var currentPosition: Int  // 0 = closed, 100 = open
    var targetPosition: Int
    var isStale: Bool = true

    var currentPositionCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeCurrentPosition }
    }

    var targetPositionCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeTargetPosition }
    }
}
