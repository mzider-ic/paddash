import SwiftUI
import HomeKit

// MARK: - Speaker Accessory Model

struct SpeakerAccessory: Identifiable {
    let id: UUID
    let accessory: HMAccessory
    let service: HMService
    var name: String
    var roomName: String
    var isMuted: Bool
    var volume: Int  // 0–100
    var isStale: Bool = true

    var muteCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeMute }
    }

    var volumeCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeVolume }
    }
}
