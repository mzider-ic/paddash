import SwiftUI
import HomeKit

// MARK: - Fan Accessory Model

struct FanAccessory: Identifiable {
    let id: UUID
    let accessory: HMAccessory
    let service: HMService
    var name: String
    var roomName: String
    var isOn: Bool
    var rotationSpeed: Int   // 0–100
    var rotationDirection: Int  // 0 = clockwise, 1 = counter-clockwise
    var isStale: Bool = true

    var powerCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypePowerState }
    }

    var rotationSpeedCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeRotationSpeed }
    }

    var rotationDirectionCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeRotationDirection }
    }
}
