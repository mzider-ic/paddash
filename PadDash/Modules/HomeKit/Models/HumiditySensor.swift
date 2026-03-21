import SwiftUI
import HomeKit

// MARK: - Humidity Sensor Model

struct HumiditySensor: Identifiable {
    let id: UUID
    let accessory: HMAccessory
    let service: HMService
    var name: String
    var roomName: String
    var humidity: Double  // 0–100%
    var isStale: Bool = true

    var humidityCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeCurrentRelativeHumidity }
    }

    /// Display humidity as a formatted string
    var displayHumidity: String {
        String(format: "%.0f", humidity)
    }
}
