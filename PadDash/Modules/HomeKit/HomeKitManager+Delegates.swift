import HomeKit

// MARK: - HMHomeManagerDelegate

extension HomeKitManager: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            homes = manager.homes
            // Restore previously selected home, or fall back to primary/first
            if selectedHome == nil {
                restoreSelectedHome()
                if selectedHome == nil {
                    selectedHome = manager.primaryHome ?? manager.homes.first
                }
            }
            discoverLights()
            // Restore persisted widgets after lights are discovered
            if widgets.isEmpty {
                restoreWidgets()
            }
        }
    }
}

// MARK: - HMAccessoryDelegate

extension HomeKitManager: HMAccessoryDelegate {
    nonisolated func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        Task { @MainActor in
            if let index = availableLights.firstIndex(where: { $0.service == service }) {
                if characteristic.characteristicType == HMCharacteristicTypePowerState,
                   let value = characteristic.value as? Bool {
                    availableLights[index].isOn = value
                }
                if characteristic.characteristicType == HMCharacteristicTypeBrightness,
                   let value = characteristic.value as? Int {
                    availableLights[index].brightness = value
                }
                updateWidgetState(for: availableLights[index])
            }
        }
    }
}
