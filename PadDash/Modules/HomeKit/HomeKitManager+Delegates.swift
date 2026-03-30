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

    nonisolated func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        Task { @MainActor in
            for (index, light) in availableLights.enumerated() {
                // Check if this accessory is involved in the light (individual or group)
                let isAffected: Bool
                if light.isGroup {
                    isAffected = light.groupServices.contains { $0.accessory === accessory }
                } else {
                    isAffected = light.accessory === accessory
                }
                guard isAffected else { continue }

                if light.isGroup {
                    if accessory.isReachable {
                        refreshLightValues(for: light)
                    } else {
                        updateGroupState(for: light)
                    }
                } else {
                    if accessory.isReachable {
                        refreshLightValues(for: light)
                    } else {
                        availableLights[index].isOn = false
                        availableLights[index].isStale = false
                        updateWidgetState(for: availableLights[index])
                    }
                }
            }
        }
    }
}

// MARK: - HMAccessoryDelegate

extension HomeKitManager: HMAccessoryDelegate {
    nonisolated func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        Task { @MainActor in
            // Light updates — match both primary service and group members
            if let index = availableLights.firstIndex(where: { light in
                light.service === service ||
                (light.isGroup && light.groupServices.contains(where: { $0 === service }))
            }) {
                if availableLights[index].isGroup {
                    updateGroupState(for: availableLights[index])
                } else {
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

            // Garage door updates
            if let index = availableGarageDoors.firstIndex(where: { $0.service === service }) {
                if characteristic.characteristicType == HMCharacteristicTypeCurrentDoorState,
                   let value = characteristic.value as? Int {
                    availableGarageDoors[index].currentState = GarageDoorState(rawValue: value) ?? .closed
                }
                if characteristic.characteristicType == HMCharacteristicTypeTargetDoorState,
                   let value = characteristic.value as? Int {
                    availableGarageDoors[index].targetState = GarageDoorTargetState(rawValue: value) ?? .closed
                }
                if characteristic.characteristicType == HMCharacteristicTypeObstructionDetected,
                   let value = characteristic.value as? Bool {
                    availableGarageDoors[index].obstructionDetected = value
                }
                availableGarageDoors[index].isStale = false

                // Propagate to widgets
                for (wIndex, widget) in widgets.enumerated() {
                    if widget.type == .garageDoor, widget.garageDoor?.id == availableGarageDoors[index].id {
                        widgets[wIndex].garageDoor = availableGarageDoors[index]
                    }
                }
            }
        }
    }
}
