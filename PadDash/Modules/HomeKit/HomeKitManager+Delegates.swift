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
            discoverAccessories()
            // Restore persisted widgets after accessories are discovered
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
            // Light updates
            if let index = availableLights.firstIndex(where: { $0.service === service }) {
                if characteristic.characteristicType == HMCharacteristicTypePowerState,
                   let value = characteristic.value as? Bool {
                    availableLights[index].isOn = value
                }
                if characteristic.characteristicType == HMCharacteristicTypeBrightness,
                   let value = characteristic.value as? Int {
                    availableLights[index].brightness = value
                }
                availableLights[index].isStale = false
                updateWidgetState(for: availableLights[index])
            }

            // Thermostat updates
            if let index = availableThermostats.firstIndex(where: { $0.service === service }) {
                if characteristic.characteristicType == HMCharacteristicTypeCurrentTemperature,
                   let value = characteristic.value as? NSNumber {
                    availableThermostats[index].currentTemperature = value.doubleValue
                }
                if characteristic.characteristicType == HMCharacteristicTypeTargetTemperature,
                   let value = characteristic.value as? NSNumber {
                    availableThermostats[index].targetTemperature = value.doubleValue
                }
                if characteristic.characteristicType == HMCharacteristicTypeCurrentHeatingCooling,
                   let value = characteristic.value as? Int {
                    availableThermostats[index].currentMode = ThermostatMode.from(heatingCoolingValue: value)
                }
                if characteristic.characteristicType == HMCharacteristicTypeTargetHeatingCooling,
                   let value = characteristic.value as? Int {
                    availableThermostats[index].targetMode = ThermostatMode.from(heatingCoolingValue: value)
                }
                availableThermostats[index].isStale = false

                // Propagate to widgets
                for (wIndex, widget) in widgets.enumerated() {
                    if widget.type == .thermostat, widget.thermostat?.id == availableThermostats[index].id {
                        widgets[wIndex].thermostat = availableThermostats[index]
                    }
                }
            }

            // Humidity sensor updates
            if let index = availableHumiditySensors.firstIndex(where: { $0.service === service }) {
                if characteristic.characteristicType == HMCharacteristicTypeCurrentRelativeHumidity,
                   let value = characteristic.value as? NSNumber {
                    availableHumiditySensors[index].humidity = value.doubleValue
                }
                availableHumiditySensors[index].isStale = false
            }
        }
    }
}
