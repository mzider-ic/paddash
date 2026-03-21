import SwiftUI
import HomeKit

// MARK: - Light Accessory Model

struct LightAccessory: Identifiable {
    let id: UUID
    let accessory: HMAccessory
    let service: HMService
    var name: String
    var roomName: String
    var isOn: Bool
    var brightness: Int  // 0–100
    var categoryType: String  // HMAccessoryCategoryType for icon mapping
    var isGroup: Bool = false
    var groupServices: [HMService] = []  // All services in a group (empty for individual lights)

    var powerCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypePowerState }
    }

    var brightnessCharacteristic: HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == HMCharacteristicTypeBrightness }
    }

    /// All power characteristics (multiple for groups, single for individual)
    var allPowerCharacteristics: [HMCharacteristic] {
        let services = isGroup && !groupServices.isEmpty ? groupServices : [service]
        return services.compactMap { $0.characteristics.first { $0.characteristicType == HMCharacteristicTypePowerState } }
    }

    /// All brightness characteristics (multiple for groups, single for individual)
    var allBrightnessCharacteristics: [HMCharacteristic] {
        let services = isGroup && !groupServices.isEmpty ? groupServices : [service]
        return services.compactMap { $0.characteristics.first { $0.characteristicType == HMCharacteristicTypeBrightness } }
    }

    /// SF Symbol matching the HomeKit accessory category
    var iconName: String {
        if #available(iOS 18.0, *) {
            switch categoryType {
            case HMAccessoryCategoryTypeSpeaker:
                return "hifispeaker.fill"
            case HMAccessoryCategoryTypeTelevision:
                return "tv.fill"
            default:
                break
            }
        }
        switch categoryType {
        case HMAccessoryCategoryTypeLightbulb:
            return "lightbulb.fill"
        case HMAccessoryCategoryTypeOutlet:
            return "powerplug.fill"
        case HMAccessoryCategoryTypeSwitch, HMAccessoryCategoryTypeProgrammableSwitch:
            return "light.switch.2"
        case HMAccessoryCategoryTypeFan:
            return "fan.fill"
        case HMAccessoryCategoryTypeThermostat:
            return "thermometer.medium"
        case HMAccessoryCategoryTypeSensor:
            return "sensor.fill"
        case HMAccessoryCategoryTypeDoor:
            return "door.left.hand.closed"
        case HMAccessoryCategoryTypeDoorLock:
            return "lock.fill"
        case HMAccessoryCategoryTypeGarageDoorOpener:
            return "door.garage.closed"
        case HMAccessoryCategoryTypeWindow:
            return "window.vertical.closed"
        case HMAccessoryCategoryTypeWindowCovering:
            return "blinds.vertical.closed"
        case HMAccessoryCategoryTypeBridge:
            return "network"
        case HMAccessoryCategoryTypeAirPurifier:
            return "air.purifier.fill"
        default:
            return isGroup ? "square.stack.3d.up.fill" : "lightbulb.fill"
        }
    }
}
