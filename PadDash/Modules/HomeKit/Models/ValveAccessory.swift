import SwiftUI
import HomeKit

// MARK: - Valve Type

enum ValveType: Int {
    case generic = 0
    case irrigation = 1
    case shower = 2
    case faucet = 3

    var displayName: String {
        switch self {
        case .generic:    return "Valve"
        case .irrigation: return "Sprinkler"
        case .shower:     return "Shower"
        case .faucet:     return "Faucet"
        }
    }

    var icon: String {
        switch self {
        case .generic:    return "spigot.fill"
        case .irrigation: return "sprinkler.and.droplets.fill"
        case .shower:     return "shower.fill"
        case .faucet:     return "drop.fill"
        }
    }
}

// MARK: - Valve Accessory Model

struct ValveAccessory: Identifiable {
    let id: UUID
    let accessory: HMAccessory
    let service: HMService
    var name: String
    var roomName: String
    var isActive: Bool
    var inUse: Bool
    var valveType: ValveType
    var isStale: Bool = true

    var activeCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeActive }
    }

    var inUseCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeInUse }
    }

    var valveTypeCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeValveType }
    }
}
