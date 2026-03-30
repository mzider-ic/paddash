import SwiftUI
import HomeKit

// MARK: - Switch Device Kind

enum SwitchDeviceKind: String, Codable {
    case toggle   // HMServiceTypeSwitch
    case outlet   // HMServiceTypeOutlet
}

// MARK: - Switch Accessory Model

struct SwitchAccessory: Identifiable {
    let id: UUID
    let accessory: HMAccessory
    let service: HMService
    let kind: SwitchDeviceKind
    var name: String
    var roomName: String
    var isOn: Bool
    var outletInUse: Bool?  // Only for outlets
    var isStale: Bool = true

    var powerCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypePowerState }
    }

    var outletInUseCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeOutletInUse }
    }
}
