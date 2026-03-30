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
            // Lights
            for (index, light) in availableLights.enumerated() {
                let isAffected: Bool
                if light.isGroup {
                    isAffected = light.groupServices.contains { $0.accessory === accessory }
                } else {
                    isAffected = light.accessory === accessory
                }
                guard isAffected else { continue }
                if light.isGroup {
                    accessory.isReachable ? refreshLightValues(for: light) : updateGroupState(for: light)
                } else if accessory.isReachable {
                    refreshLightValues(for: light)
                } else {
                    availableLights[index].isOn = false
                    availableLights[index].isStale = false
                    updateWidgetState(for: availableLights[index])
                }
            }
            // Locks
            for lock in availableLocks where lock.accessory === accessory {
                accessory.isReachable ? refreshLockValues(for: lock) : updateLockState(for: lock)
            }
            // Fans
            for fan in availableFans where fan.accessory === accessory {
                accessory.isReachable ? refreshFanValues(for: fan) : updateFanState(for: fan)
            }
            // Switches
            for sw in availableSwitches where sw.accessory === accessory {
                accessory.isReachable ? refreshSwitchValues(for: sw) : updateSwitchState(for: sw)
            }
            // Position devices
            for pos in availablePositionDevices where pos.accessory === accessory {
                accessory.isReachable ? refreshPositionValues(for: pos) : updatePositionState(for: pos)
            }
            // Valves
            for valve in availableValves where valve.accessory === accessory {
                accessory.isReachable ? refreshValveValues(for: valve) : updateValveState(for: valve)
            }
            // Security systems
            for system in availableSecuritySystems where system.accessory === accessory {
                accessory.isReachable ? refreshSecuritySystemValues(for: system) : updateSecuritySystemState(for: system)
            }
            // Speakers
            for speaker in availableSpeakers where speaker.accessory === accessory {
                accessory.isReachable ? refreshSpeakerValues(for: speaker) : updateSpeakerState(for: speaker)
            }
            // Sensors
            for sensor in availableSensors where sensor.accessory === accessory {
                accessory.isReachable ? refreshSensorValues(for: sensor) : updateSensorState(for: sensor)
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
                for (wIndex, widget) in widgets.enumerated() {
                    if widget.type == .garageDoor, widget.garageDoor?.id == availableGarageDoors[index].id {
                        widgets[wIndex].garageDoor = availableGarageDoors[index]
                    }
                }
            }

            // Lock updates
            if let index = availableLocks.firstIndex(where: { $0.service === service }) {
                if characteristic.characteristicType == HMCharacteristicTypeCurrentLockMechanismState,
                   let value = characteristic.value as? Int {
                    availableLocks[index].currentState = LockState(rawValue: value) ?? .unknown
                }
                if characteristic.characteristicType == HMCharacteristicTypeTargetLockMechanismState,
                   let value = characteristic.value as? Int {
                    availableLocks[index].targetState = LockTargetState(rawValue: value) ?? .secured
                }
                availableLocks[index].isStale = false
                for (wIndex, widget) in widgets.enumerated() {
                    if widget.type == .lock, widget.lock?.id == availableLocks[index].id {
                        widgets[wIndex].lock = availableLocks[index]
                    }
                }
            }

            // Fan updates
            if let index = availableFans.firstIndex(where: { $0.service === service }) {
                if characteristic.characteristicType == HMCharacteristicTypePowerState,
                   let value = characteristic.value as? Bool { availableFans[index].isOn = value }
                if characteristic.characteristicType == HMCharacteristicTypeRotationSpeed,
                   let value = characteristic.value as? NSNumber { availableFans[index].rotationSpeed = value.intValue }
                if characteristic.characteristicType == HMCharacteristicTypeRotationDirection,
                   let value = characteristic.value as? Int { availableFans[index].rotationDirection = value }
                availableFans[index].isStale = false
                for (wIndex, widget) in widgets.enumerated() {
                    if widget.type == .fan, widget.fan?.id == availableFans[index].id {
                        widgets[wIndex].fan = availableFans[index]
                    }
                }
            }

            // Switch/Outlet updates
            if let index = availableSwitches.firstIndex(where: { $0.service === service }) {
                if characteristic.characteristicType == HMCharacteristicTypePowerState,
                   let value = characteristic.value as? Bool { availableSwitches[index].isOn = value }
                if characteristic.characteristicType == HMCharacteristicTypeOutletInUse,
                   let value = characteristic.value as? Bool { availableSwitches[index].outletInUse = value }
                availableSwitches[index].isStale = false
                for (wIndex, widget) in widgets.enumerated() {
                    if (widget.type == .switchToggle || widget.type == .outlet),
                       widget.switchDevice?.id == availableSwitches[index].id {
                        widgets[wIndex].switchDevice = availableSwitches[index]
                    }
                }
            }

            // Position device updates (door, window, covering)
            if let index = availablePositionDevices.firstIndex(where: { $0.service === service }) {
                if characteristic.characteristicType == HMCharacteristicTypeCurrentPosition,
                   let value = characteristic.value as? Int { availablePositionDevices[index].currentPosition = value }
                if characteristic.characteristicType == HMCharacteristicTypeTargetPosition,
                   let value = characteristic.value as? Int { availablePositionDevices[index].targetPosition = value }
                availablePositionDevices[index].isStale = false
                for (wIndex, widget) in widgets.enumerated() {
                    if (widget.type == .door || widget.type == .window || widget.type == .windowCovering),
                       widget.position?.id == availablePositionDevices[index].id {
                        widgets[wIndex].position = availablePositionDevices[index]
                    }
                }
            }

            // Valve updates
            if let index = availableValves.firstIndex(where: { $0.service === service }) {
                if characteristic.characteristicType == HMCharacteristicTypeActive,
                   let value = characteristic.value as? Int { availableValves[index].isActive = value == 1 }
                if characteristic.characteristicType == HMCharacteristicTypeInUse,
                   let value = characteristic.value as? Int { availableValves[index].inUse = value == 1 }
                availableValves[index].isStale = false
                for (wIndex, widget) in widgets.enumerated() {
                    if widget.type == .valve, widget.valve?.id == availableValves[index].id {
                        widgets[wIndex].valve = availableValves[index]
                    }
                }
            }

            // Security system updates
            if let index = availableSecuritySystems.firstIndex(where: { $0.service === service }) {
                if characteristic.characteristicType == HMCharacteristicTypeCurrentSecuritySystemState,
                   let value = characteristic.value as? Int {
                    availableSecuritySystems[index].currentState = SecuritySystemState(rawValue: value) ?? .disarmed
                }
                if characteristic.characteristicType == HMCharacteristicTypeTargetSecuritySystemState,
                   let value = characteristic.value as? Int {
                    availableSecuritySystems[index].targetState = SecuritySystemTargetState(rawValue: value) ?? .disarmed
                }
                availableSecuritySystems[index].isStale = false
                for (wIndex, widget) in widgets.enumerated() {
                    if widget.type == .securitySystem, widget.securitySystem?.id == availableSecuritySystems[index].id {
                        widgets[wIndex].securitySystem = availableSecuritySystems[index]
                    }
                }
            }

            // Speaker updates
            if let index = availableSpeakers.firstIndex(where: { $0.service === service }) {
                if characteristic.characteristicType == HMCharacteristicTypeMute,
                   let value = characteristic.value as? Bool { availableSpeakers[index].isMuted = value }
                if characteristic.characteristicType == HMCharacteristicTypeVolume,
                   let value = characteristic.value as? Int { availableSpeakers[index].volume = value }
                availableSpeakers[index].isStale = false
                for (wIndex, widget) in widgets.enumerated() {
                    if widget.type == .speaker, widget.speaker?.id == availableSpeakers[index].id {
                        widgets[wIndex].speaker = availableSpeakers[index]
                    }
                }
            }

            // Sensor updates
            if let index = availableSensors.firstIndex(where: { $0.service === service }) {
                let sType = availableSensors[index].sensorType
                if characteristic.characteristicType == sType.primaryCharacteristicType,
                   let value = characteristic.value as? NSNumber {
                    availableSensors[index].primaryValue = value.doubleValue
                }
                if let secType = sType.secondaryCharacteristicType,
                   characteristic.characteristicType == secType,
                   let value = characteristic.value as? NSNumber {
                    availableSensors[index].secondaryValue = value.doubleValue
                }
                availableSensors[index].isStale = false
                for (wIndex, widget) in widgets.enumerated() {
                    if widget.type.sensorType != nil, widget.sensor?.id == availableSensors[index].id {
                        widgets[wIndex].sensor = availableSensors[index]
                    }
                }
            }
        }
    }
}
