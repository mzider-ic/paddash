import SwiftUI
import HomeKit

// MARK: - Lock State

enum LockState: Int {
    case unsecured = 0
    case secured = 1
    case jammed = 2
    case unknown = 3

    var displayName: String {
        switch self {
        case .unsecured: return "Unlocked"
        case .secured:   return "Locked"
        case .jammed:    return "Jammed"
        case .unknown:   return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .unsecured: return "lock.open.fill"
        case .secured:   return "lock.fill"
        case .jammed:    return "lock.trianglebadge.exclamationmark.fill"
        case .unknown:   return "lock.slash.fill"
        }
    }

    var isAlert: Bool {
        self == .jammed || self == .unknown
    }
}

// MARK: - Lock Target State

enum LockTargetState: Int {
    case unsecured = 0
    case secured = 1
}

// MARK: - Lock Accessory Model

struct LockAccessory: Identifiable {
    let id: UUID
    let accessory: HMAccessory
    let service: HMService
    var name: String
    var roomName: String
    var currentState: LockState
    var targetState: LockTargetState
    var isStale: Bool = true

    var currentLockStateCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeCurrentLockMechanismState }
    }

    var targetLockStateCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeTargetLockMechanismState }
    }
}
