import SwiftUI
import HomeKit
import Combine

// MARK: - HomeKit Manager

@MainActor
final class HomeKitManager: NSObject, ObservableObject {

    // Published state
    @Published var homes: [HMHome] = []
    @Published var selectedHome: HMHome?
    @Published var availableLights: [LightAccessory] = []
    @Published var availableThermostats: [ThermostatAccessory] = []
    @Published var availableHumiditySensors: [HumiditySensor] = []
    @Published var availableGarageDoors: [GarageDoorAccessory] = []
    @Published var widgets: [HomeKitWidget] = []
    @Published var statusMessage: String?
    @Published var isLoading = true

    // Sheet state
    @Published var showWidgetTypePicker = false
    @Published var showAccessoryPicker = false
    @Published var pendingWidgetType: HomeKitWidgetType?

    // Rename sheet state
    @Published var widgetBeingRenamed: HomeKitWidget?
    @Published var renameText: String = ""

    let homeManager = HMHomeManager()
    private let store = DashboardStore.shared
    private var humidityRefreshTimer: AnyCancellable?

    override init() {
        super.init()
        homeManager.delegate = self
        startHumidityRefreshTimer()
    }

    // MARK: - Humidity Polling

    /// Periodically re-reads humidity values. HomePods and some sensors
    /// don't reliably push characteristic notifications, so polling keeps
    /// the displayed values current.
    private func startHumidityRefreshTimer() {
        humidityRefreshTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    for sensor in self.availableHumiditySensors {
                        self.refreshHumidityValues(for: sensor)
                    }
                }
            }
    }

    // MARK: - Persistence

    func saveState() {
        if let homeID = selectedHome?.uniqueIdentifier {
            store.saveSelectedHomeID(homeID)
        }
        let entries = widgets.map {
            PersistedWidgetEntry(
                id: $0.id.uuidString,
                kind: $0.type.rawValue,
                referenceID: $0.referenceID,
                customName: $0.customName
            )
        }
        store.saveHomeKitWidgets(entries)
    }

    func restoreSelectedHome() {
        guard let savedID = store.loadSelectedHomeID() else { return }
        selectedHome = homes.first { $0.uniqueIdentifier == savedID }
        if let home = selectedHome {
            dumpAllCharacteristics(for: home)
        }
    }

    func restoreWidgets() {
        let entries = store.loadHomeKitWidgets()
        var restored: [HomeKitWidget] = []
        for entry in entries {
            guard let widgetType = HomeKitWidgetType(rawValue: entry.kind),
                  let widgetID = UUID(uuidString: entry.id) else { continue }

            switch widgetType {
            case .lightDimmer:
                guard let lightID = UUID(uuidString: entry.referenceID),
                      let light = availableLights.first(where: { $0.id == lightID }) else { continue }
                restored.append(HomeKitWidget(id: widgetID, type: widgetType, light: light, customName: entry.customName))

            case .thermostat:
                guard let thermostatID = UUID(uuidString: entry.referenceID),
                      let thermostat = availableThermostats.first(where: { $0.id == thermostatID }) else { continue }
                var widget = HomeKitWidget(id: widgetID, type: widgetType, light: LightAccessory.placeholder)
                widget.thermostat = thermostat
                widget.customName = entry.customName
                restored.append(widget)

            case .humidity:
                // Humidity widget doesn't reference a specific accessory
                var widget = HomeKitWidget(id: widgetID, type: widgetType, light: LightAccessory.placeholder)
                widget.customName = entry.customName
                restored.append(widget)

            case .garageDoor:
                guard let garageDoorID = UUID(uuidString: entry.referenceID),
                      let garageDoor = availableGarageDoors.first(where: { $0.id == garageDoorID }) else { continue }
                var widget = HomeKitWidget(id: widgetID, type: widgetType, light: LightAccessory.placeholder)
                widget.garageDoor = garageDoor
                widget.customName = entry.customName
                restored.append(widget)
            }
        }
        widgets = restored
    }

    // MARK: - Home Selection

    func selectHome(_ home: HMHome) {
        selectedHome = home
        discoverAccessories()
        saveState()
    }

    // MARK: - Discovery

    func discoverAccessories() {
        guard let home = selectedHome else {
            availableLights = []
            availableThermostats = []
            availableHumiditySensors = []
            availableGarageDoors = []
            statusMessage = "No HomeKit home selected."
            isLoading = false
            return
        }

        var discoveredLights: [LightAccessory] = []
        var discoveredThermostats: [ThermostatAccessory] = []
        var discoveredHumidity: [HumiditySensor] = []
        var discoveredGarageDoors: [GarageDoorAccessory] = []

        for accessory in home.accessories {
            accessory.delegate = self

            // Discover lightbulb services
            for service in accessory.services where service.serviceType == HMServiceTypeLightbulb {
                let light = LightAccessory(
                    id: service.uniqueIdentifier,
                    accessory: accessory,
                    service: service,
                    name: service.name,
                    roomName: accessory.room?.name ?? "Default Room",
                    isOn: false,
                    brightness: 100,
                    categoryType: accessory.category.categoryType
                )
                discoveredLights.append(light)
                for characteristic in service.characteristics {
                    characteristic.enableNotification(true) { _ in }
                }
            }

            // Discover thermostat services
            for service in accessory.services where service.serviceType == HMServiceTypeThermostat {
                let thermostat = ThermostatAccessory(
                    id: service.uniqueIdentifier,
                    accessory: accessory,
                    service: service,
                    name: service.name,
                    roomName: accessory.room?.name ?? "Default Room",
                    currentTemperature: 0,
                    targetTemperature: 20,
                    currentMode: .off,
                    targetMode: .off
                )
                discoveredThermostats.append(thermostat)
                for characteristic in service.characteristics {
                    characteristic.enableNotification(true) { _ in }
                }
            }

            // Discover ANY service that exposes humidity (covers dedicated sensors, thermostats, HomePods, etc.)
            for service in accessory.services {
                let hasHumidity = service.characteristics.contains {
                    $0.characteristicType == HMCharacteristicTypeCurrentRelativeHumidity
                }
                guard hasHumidity else { continue }
                
                // Avoid duplicate entries when the same accessory exposes humidity on multiple services
                let alreadyAdded = discoveredHumidity.contains { $0.service.uniqueIdentifier == service.uniqueIdentifier }
                guard !alreadyAdded else { continue }

                let sensor = HumiditySensor(
                    id: service.uniqueIdentifier,
                    accessory: accessory,
                    service: service,
                    name: accessory.name,
                    roomName: accessory.room?.name ?? "Default Room",
                    humidity: 0
                )
                discoveredHumidity.append(sensor)
                for characteristic in service.characteristics {
                    characteristic.enableNotification(true) { _ in }
                }
            }

            // Discover garage door opener services
            for service in accessory.services where service.serviceType == HMServiceTypeGarageDoorOpener {
                let garageDoor = GarageDoorAccessory(
                    id: service.uniqueIdentifier,
                    accessory: accessory,
                    service: service,
                    name: service.name,
                    roomName: accessory.room?.name ?? "Default Room",
                    currentState: .closed,
                    targetState: .closed,
                    obstructionDetected: false
                )
                discoveredGarageDoors.append(garageDoor)
                for characteristic in service.characteristics {
                    characteristic.enableNotification(true) { _ in }
                }
            }
        }

        // Discover grouped lights from service groups
        for group in home.serviceGroups {
            let lightServices = group.services.filter { $0.serviceType == HMServiceTypeLightbulb }
            guard !lightServices.isEmpty, let firstService = lightServices.first else { continue }
            guard let firstAccessory = firstService.accessory else { continue }

            let groupLight = LightAccessory(
                id: group.uniqueIdentifier,
                accessory: firstAccessory,
                service: firstService,
                name: group.name,
                roomName: firstAccessory.room?.name ?? "Default Room",
                isOn: false,
                brightness: 100,
                categoryType: firstAccessory.category.categoryType,
                isGroup: true,
                groupServices: lightServices
            )
            discoveredLights.append(groupLight)

            for service in lightServices {
                for characteristic in service.characteristics {
                    characteristic.enableNotification(true) { _ in }
                }
            }
        }

        availableLights = discoveredLights
        availableThermostats = discoveredThermostats
        availableHumiditySensors = discoveredHumidity
        availableGarageDoors = discoveredGarageDoors

        let totalAccessories = discoveredLights.count + discoveredThermostats.count + discoveredHumidity.count + discoveredGarageDoors.count
        statusMessage = totalAccessories == 0 ? "No compatible accessories found in \(home.name)." : nil
        isLoading = false

        for light in discoveredLights {
            refreshLightValues(for: light)
        }
        for thermostat in discoveredThermostats {
            refreshThermostatValues(for: thermostat)
        }
        for sensor in discoveredHumidity {
            refreshHumidityValues(for: sensor)
        }
        for garageDoor in discoveredGarageDoors {
            refreshGarageDoorValues(for: garageDoor)
        }

        refreshWidgetAccessories()
    }

    // Keep backward compatibility
    func discoverLights() {
        discoverAccessories()
    }

    private func refreshWidgetAccessories() {
        for (widgetIndex, widget) in widgets.enumerated() {
            switch widget.type {
            case .lightDimmer:
                if let freshLight = availableLights.first(where: { $0.id == widget.light.id }) {
                    widgets[widgetIndex].light = freshLight
                }
            case .thermostat:
                if let thermostat = widget.thermostat,
                   let fresh = availableThermostats.first(where: { $0.id == thermostat.id }) {
                    widgets[widgetIndex].thermostat = fresh
                }
            case .humidity:
                break // Humidity widget reads from availableHumiditySensors directly
            case .garageDoor:
                if let garageDoor = widget.garageDoor,
                   let fresh = availableGarageDoors.first(where: { $0.id == garageDoor.id }) {
                    widgets[widgetIndex].garageDoor = fresh
                }
            }
        }
    }

    // MARK: - Widget Management

    func beginAddWidget() {
        showWidgetTypePicker = true
    }

    func selectWidgetType(_ type: HomeKitWidgetType) {
        pendingWidgetType = type
        showWidgetTypePicker = false

        if type.requiresAccessorySelection {
            showAccessoryPicker = true
        } else {
            // Humidity widget — add directly, no accessory to pick
            let widget = HomeKitWidget(id: UUID(), type: type, light: LightAccessory.placeholder)
            widgets.append(widget)
            pendingWidgetType = nil
            saveState()
        }
    }

    func addWidget(for light: LightAccessory) {
        guard let type = pendingWidgetType else { return }
        let widget = HomeKitWidget(id: UUID(), type: type, light: light)
        widgets.append(widget)
        showAccessoryPicker = false
        pendingWidgetType = nil
        saveState()
    }

    func addThermostatWidget(for thermostat: ThermostatAccessory) {
        guard let type = pendingWidgetType else { return }
        var widget = HomeKitWidget(id: UUID(), type: type, light: LightAccessory.placeholder)
        widget.thermostat = thermostat
        widgets.append(widget)
        showAccessoryPicker = false
        pendingWidgetType = nil
        saveState()
    }

    func addGarageDoorWidget(for garageDoor: GarageDoorAccessory) {
        guard let type = pendingWidgetType else { return }
        var widget = HomeKitWidget(id: UUID(), type: type, light: LightAccessory.placeholder)
        widget.garageDoor = garageDoor
        widgets.append(widget)
        showAccessoryPicker = false
        pendingWidgetType = nil
        saveState()
    }

    func removeWidget(_ widget: HomeKitWidget) {
        widgets.removeAll { $0.id == widget.id }
        saveState()
    }

    func moveWidget(from source: IndexSet, to destination: Int) {
        widgets.move(fromOffsets: source, toOffset: destination)
        saveState()
    }

    // MARK: - Widget Rename

    func beginRename(_ widget: HomeKitWidget) {
        widgetBeingRenamed = widget
        renameText = widget.customName ?? ""
    }

    func commitRename() {
        guard let widget = widgetBeingRenamed,
              let index = widgets.firstIndex(where: { $0.id == widget.id }) else {
            widgetBeingRenamed = nil
            return
        }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        widgets[index].customName = trimmed.isEmpty ? nil : trimmed
        widgetBeingRenamed = nil
        renameText = ""
        saveState()
    }

    func cancelRename() {
        widgetBeingRenamed = nil
        renameText = ""
    }

    // MARK: - Accessory Filtering

    /// Lights that haven't been added as widgets yet
    var unaddedLights: [LightAccessory] {
        let widgetServiceIDs = Set(widgets.compactMap { widget -> UUID? in
            guard widget.type == .lightDimmer else { return nil }
            return widget.light.service?.uniqueIdentifier
        })
        return availableLights.filter { light in
            guard let serviceID = light.service?.uniqueIdentifier else { return false }
            return !widgetServiceIDs.contains(serviceID)
        }
    }

    /// Thermostats that haven't been added as widgets yet
    var unaddedThermostats: [ThermostatAccessory] {
        let widgetServiceIDs = Set(widgets.compactMap { widget -> UUID? in
            guard widget.type == .thermostat else { return nil }
            return widget.thermostat?.service.uniqueIdentifier
        })
        return availableThermostats.filter { !widgetServiceIDs.contains($0.service.uniqueIdentifier) }
    }

    /// Garage doors that haven't been added as widgets yet
    var unaddedGarageDoors: [GarageDoorAccessory] {
        let widgetServiceIDs = Set(widgets.compactMap { widget -> UUID? in
            guard widget.type == .garageDoor else { return nil }
            return widget.garageDoor?.service.uniqueIdentifier
        })
        return availableGarageDoors.filter { !widgetServiceIDs.contains($0.service.uniqueIdentifier) }
    }

    /// Unadded lights grouped by room, each group sorted alphabetically
    var unaddedLightsGroupedByRoom: [(room: String, lights: [LightAccessory])] {
        let lights = unaddedLights
        var grouped: [String: [LightAccessory]] = [:]
        for light in lights {
            grouped[light.roomName, default: []].append(light)
        }
        return grouped
            .map { (room: $0.key, lights: $0.value.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) }
            .sorted { $0.room.localizedCaseInsensitiveCompare($1.room) == .orderedAscending }
    }

    /// Humidity sensors grouped by room
    var humiditySensorsGroupedByRoom: [(room: String, sensors: [HumiditySensor])] {
        var grouped: [String: [HumiditySensor]] = [:]
        for sensor in availableHumiditySensors {
            grouped[sensor.roomName, default: []].append(sensor)
        }
        return grouped
            .map { (room: $0.key, sensors: $0.value.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) }
            .sorted { $0.room.localizedCaseInsensitiveCompare($1.room) == .orderedAscending }
    }

    // MARK: - Read Light Values

    func refreshLightValues(for light: LightAccessory) {
        if light.isGroup {
            // Read from all services in the group, then re-aggregate
            for characteristic in light.allPowerCharacteristics + light.allBrightnessCharacteristics {
                characteristic.readValue { [weak self] _ in
                    Task { @MainActor in
                        self?.updateGroupState(for: light)
                    }
                }
            }
        } else {
            light.powerCharacteristic?.readValue { [weak self] _ in
                Task { @MainActor in
                    self?.updateLocalState(for: light)
                }
            }
            light.brightnessCharacteristic?.readValue { [weak self] _ in
                Task { @MainActor in
                    self?.updateLocalState(for: light)
                }
            }
        }
    }

    // Keep backward compatibility
    func refreshValues(for light: LightAccessory) {
        refreshLightValues(for: light)
    }

    func updateLocalState(for light: LightAccessory) {
        if let index = availableLights.firstIndex(where: { $0.id == light.id }) {
            if let power = light.powerCharacteristic?.value as? Bool {
                availableLights[index].isOn = power
            }
            if let brightness = light.brightnessCharacteristic?.value as? Int {
                availableLights[index].brightness = brightness
            }
            availableLights[index].isStale = false
        }
        updateWidgetState(for: light)
    }

    func updateWidgetState(for light: LightAccessory) {
        // Groups use updateGroupState for widget propagation
        guard !light.isGroup else { return }
        guard let lightServiceID = light.service?.uniqueIdentifier else { return }
        for (index, widget) in widgets.enumerated() {
            guard widget.type == .lightDimmer else { continue }
            if widget.light.service?.uniqueIdentifier == lightServiceID {
                if let power = light.powerCharacteristic?.value as? Bool {
                    widgets[index].light.isOn = power
                }
                if let brightness = light.brightnessCharacteristic?.value as? Int {
                    widgets[index].light.brightness = brightness
                }
                widgets[index].light.isStale = false
            }
        }
    }

    /// Aggregate power/brightness across all services in a grouped light,
    /// filtering out unreachable accessories.
    func updateGroupState(for light: LightAccessory) {
        guard light.isGroup,
              let index = availableLights.firstIndex(where: { $0.id == light.id })
        else { return }

        let services = light.groupServices
        let reachableServices = services.filter { $0.accessory?.isReachable == true }

        if reachableServices.isEmpty {
            availableLights[index].isOn = false
            availableLights[index].brightness = 0
        } else {
            let anyOn = reachableServices.contains { service in
                service.characteristics
                    .first { $0.characteristicType == HMCharacteristicTypePowerState }?
                    .value as? Bool ?? false
            }
            availableLights[index].isOn = anyOn

            let brightnessValues: [Int] = reachableServices.compactMap { service in
                service.characteristics
                    .first { $0.characteristicType == HMCharacteristicTypeBrightness }?
                    .value as? Int
            }
            if !brightnessValues.isEmpty {
                availableLights[index].brightness = brightnessValues.reduce(0, +) / brightnessValues.count
            }
        }
        availableLights[index].isStale = false

        // Propagate to widgets — match by light ID for groups
        for (wIndex, widget) in widgets.enumerated() {
            guard widget.type == .lightDimmer, widget.light.id == light.id else { continue }
            widgets[wIndex].light.isOn = availableLights[index].isOn
            widgets[wIndex].light.brightness = availableLights[index].brightness
            widgets[wIndex].light.isStale = false
        }
    }

    // MARK: - Read Thermostat Values

    func refreshThermostatValues(for thermostat: ThermostatAccessory) {
        thermostat.currentTemperatureCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateThermostatState(for: thermostat) }
        }
        thermostat.targetTemperatureCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateThermostatState(for: thermostat) }
        }
        thermostat.currentHeatingCoolingCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateThermostatState(for: thermostat) }
        }
        thermostat.targetHeatingCoolingCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateThermostatState(for: thermostat) }
        }
    }

    func updateThermostatState(for thermostat: ThermostatAccessory) {
        if let index = availableThermostats.firstIndex(where: { $0.id == thermostat.id }) {
            if let temp = thermostat.currentTemperatureCharacteristic?.value as? Double {
                availableThermostats[index].currentTemperature = temp
            } else if let temp = thermostat.currentTemperatureCharacteristic?.value as? NSNumber {
                availableThermostats[index].currentTemperature = temp.doubleValue
            }
            if let temp = thermostat.targetTemperatureCharacteristic?.value as? Double {
                availableThermostats[index].targetTemperature = temp
            } else if let temp = thermostat.targetTemperatureCharacteristic?.value as? NSNumber {
                availableThermostats[index].targetTemperature = temp.doubleValue
            }
            if let mode = thermostat.currentHeatingCoolingCharacteristic?.value as? Int {
                availableThermostats[index].currentMode = ThermostatMode.from(heatingCoolingValue: mode)
            }
            if let mode = thermostat.targetHeatingCoolingCharacteristic?.value as? Int {
                availableThermostats[index].targetMode = ThermostatMode.from(heatingCoolingValue: mode)
            }
            availableThermostats[index].isStale = false

            // Update widget
            for (wIndex, widget) in widgets.enumerated() {
                if widget.type == .thermostat, widget.thermostat?.id == thermostat.id {
                    widgets[wIndex].thermostat = availableThermostats[index]
                }
            }
        }
    }

    // MARK: - Read Humidity Values

    func refreshHumidityValues(for sensor: HumiditySensor) {
        sensor.humidityCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateHumidityState(for: sensor) }
        }
    }

    func updateHumidityState(for sensor: HumiditySensor) {
        if let index = availableHumiditySensors.firstIndex(where: { $0.id == sensor.id }) {
            if let humidity = sensor.humidityCharacteristic?.value as? Double {
                availableHumiditySensors[index].humidity = humidity
            } else if let humidity = sensor.humidityCharacteristic?.value as? NSNumber {
                availableHumiditySensors[index].humidity = humidity.doubleValue
            }
            availableHumiditySensors[index].isStale = false
        }
    }

    // MARK: - Read Garage Door Values

    func refreshGarageDoorValues(for garageDoor: GarageDoorAccessory) {
        garageDoor.currentDoorStateCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateGarageDoorState(for: garageDoor) }
        }
        garageDoor.targetDoorStateCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateGarageDoorState(for: garageDoor) }
        }
        garageDoor.obstructionDetectedCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateGarageDoorState(for: garageDoor) }
        }
    }

    func updateGarageDoorState(for garageDoor: GarageDoorAccessory) {
        if let index = availableGarageDoors.firstIndex(where: { $0.id == garageDoor.id }) {
            if let state = garageDoor.currentDoorStateCharacteristic?.value as? Int {
                availableGarageDoors[index].currentState = GarageDoorState(rawValue: state) ?? .closed
            }
            if let target = garageDoor.targetDoorStateCharacteristic?.value as? Int {
                availableGarageDoors[index].targetState = GarageDoorTargetState(rawValue: target) ?? .closed
            }
            if let obstruction = garageDoor.obstructionDetectedCharacteristic?.value as? Bool {
                availableGarageDoors[index].obstructionDetected = obstruction
            }
            availableGarageDoors[index].isStale = false

            // Propagate to widgets
            for (wIndex, widget) in widgets.enumerated() {
                if widget.type == .garageDoor, widget.garageDoor?.id == garageDoor.id {
                    widgets[wIndex].garageDoor = availableGarageDoors[index]
                }
            }
        }
    }

    // MARK: - Garage Door Controls

    func toggleGarageDoor(for garageDoor: GarageDoorAccessory) {
        guard let characteristic = garageDoor.targetDoorStateCharacteristic else { return }

        // Toggle: if currently open/opening -> close; if closed/closing/stopped -> open
        let newTarget: GarageDoorTargetState
        switch garageDoor.currentState {
        case .open, .opening:
            newTarget = .closed
        case .closed, .closing, .stopped:
            newTarget = .open
        }

        // Optimistic local update
        if let index = availableGarageDoors.firstIndex(where: { $0.id == garageDoor.id }) {
            availableGarageDoors[index].targetState = newTarget
            for (wIndex, widget) in widgets.enumerated() {
                if widget.type == .garageDoor, widget.garageDoor?.id == garageDoor.id {
                    widgets[wIndex].garageDoor?.targetState = newTarget
                }
            }
        }

        characteristic.writeValue(newTarget.rawValue) { _ in }
    }

    // MARK: - Thermostat Controls

    func setTargetTemperature(for thermostat: ThermostatAccessory, celsius: Double) {
        guard let characteristic = thermostat.targetTemperatureCharacteristic else { return }
        let clamped = min(32, max(10, celsius)) // HomeKit typical range in Celsius

        if let index = availableThermostats.firstIndex(where: { $0.id == thermostat.id }) {
            availableThermostats[index].targetTemperature = clamped
            for (wIndex, widget) in widgets.enumerated() {
                if widget.type == .thermostat, widget.thermostat?.id == thermostat.id {
                    widgets[wIndex].thermostat?.targetTemperature = clamped
                }
            }
        }

        characteristic.writeValue(clamped) { _ in }
    }

    func setTargetMode(for thermostat: ThermostatAccessory, mode: ThermostatMode) {
        guard let characteristic = thermostat.targetHeatingCoolingCharacteristic else { return }

        if let index = availableThermostats.firstIndex(where: { $0.id == thermostat.id }) {
            availableThermostats[index].targetMode = mode
            for (wIndex, widget) in widgets.enumerated() {
                if widget.type == .thermostat, widget.thermostat?.id == thermostat.id {
                    widgets[wIndex].thermostat?.targetMode = mode
                }
            }
        }

        characteristic.writeValue(mode.rawValue) { _ in }
    }

    // MARK: - Light Controls

    func togglePower(for light: LightAccessory) {
        let characteristics = light.allPowerCharacteristics
        guard !characteristics.isEmpty else { return }
        let newValue = !light.isOn

        if let index = availableLights.firstIndex(where: { $0.id == light.id }) {
            availableLights[index].isOn = newValue
        }
        let lightServiceID = light.service?.uniqueIdentifier
        for (index, widget) in widgets.enumerated() {
            if widget.type == .lightDimmer,
               widget.light.service?.uniqueIdentifier == lightServiceID {
                widgets[index].light.isOn = newValue
            }
        }

        for characteristic in characteristics {
            characteristic.writeValue(newValue) { _ in }
        }
    }

    func togglePowerForGroupLight(light: LightAccessory) {
        let newValue = !light.isOn

        if let index = availableLights.firstIndex(where: { $0.id == light.id }) {
            availableLights[index].isOn = newValue
        }
        for (index, widget) in widgets.enumerated() {
            if widget.type == .lightDimmer, widget.light.id == light.id {
                widgets[index].light.isOn = newValue
            }
        }

        for service in light.groupServices {
            if let characteristic = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypePowerState }) {
                characteristic.writeValue(newValue) { _ in }
            }
        }
    }

    /// Update the local UI state only (no HomeKit write). Use during drag.
    func setBrightnessLocally(for light: LightAccessory, value: Int) {
        let clamped = min(100, max(0, value))
        if let index = availableLights.firstIndex(where: { $0.id == light.id }) {
            availableLights[index].brightness = clamped
        }
        let lightServiceID = light.service?.uniqueIdentifier
        for (index, widget) in widgets.enumerated() {
            if widget.type == .lightDimmer,
               widget.light.service?.uniqueIdentifier == lightServiceID {
                widgets[index].light.brightness = clamped
            }
        }
    }

    /// Commit brightness to HomeKit hardware. Call on finger lift.
    func commitBrightness(for light: LightAccessory, value: Int) {
        let characteristics = light.allBrightnessCharacteristics
        guard !characteristics.isEmpty else { return }
        let clamped = min(100, max(0, value))

        setBrightnessLocally(for: light, value: clamped)

        for characteristic in characteristics {
            characteristic.writeValue(clamped) { _ in }
        }
    }

    func setBrightness(for light: LightAccessory, value: Int) {
        commitBrightness(for: light, value: value)
    }
}
extension HomeKitManager {
    func dumpAllCharacteristics(for home: HMHome) {
        for accessory in home.accessories {
            print("🏠 Accessory: \(accessory.name)")
            for service in accessory.services {
                print("   🛠 Service: \(service.name)")
                for char in service.characteristics {
                    print("      🔹 Name: \(char.localizedDescription)")
                    print("         Type: \(char.characteristicTypeName)")
                    print("         UUID: \(char.characteristicType)")
                    print("         Value: \(String(describing: char.value))")
                }
            }
        }
    }
}

extension HMCharacteristic {
    var characteristicTypeName: String {
        switch self.characteristicType {
        // --- Light and Color ---
        case HMCharacteristicTypePowerState: return "HMCharacteristicTypePowerState"
        case HMCharacteristicTypeHue: return "HMCharacteristicTypeHue"
        case HMCharacteristicTypeSaturation: return "HMCharacteristicTypeSaturation"
        case HMCharacteristicTypeBrightness: return "HMCharacteristicTypeBrightness"
        case HMCharacteristicTypeColorTemperature: return "HMCharacteristicTypeColorTemperature"

        // --- Climate and Sensors ---
        case HMCharacteristicTypeCurrentTemperature: return "HMCharacteristicTypeCurrentTemperature"
        case HMCharacteristicTypeTargetTemperature: return "HMCharacteristicTypeTargetTemperature"
        case HMCharacteristicTypeCurrentRelativeHumidity: return "HMCharacteristicTypeCurrentRelativeHumidity"
        case HMCharacteristicTypeTargetRelativeHumidity: return "HMCharacteristicTypeTargetRelativeHumidity"
        case HMCharacteristicTypeTemperatureUnits: return "HMCharacteristicTypeTemperatureUnits"
        case HMCharacteristicTypeCurrentHeatingCooling: return "HMCharacteristicTypeCurrentHeatingCooling"
        case HMCharacteristicTypeTargetHeatingCooling: return "HMCharacteristicTypeTargetHeatingCooling"
        case HMCharacteristicTypeAirQuality: return "HMCharacteristicTypeAirQuality"
        case HMCharacteristicTypeCarbonDioxideLevel: return "HMCharacteristicTypeCarbonDioxideLevel"

        // --- Security and Access ---
        case HMCharacteristicTypeCurrentDoorState: return "HMCharacteristicTypeCurrentDoorState"
        case HMCharacteristicTypeTargetDoorState: return "HMCharacteristicTypeTargetDoorState"
        case HMCharacteristicTypeObstructionDetected: return "HMCharacteristicTypeObstructionDetected"
        case HMCharacteristicTypeCurrentLockMechanismState: return "HMCharacteristicTypeCurrentLockMechanismState"
        case HMCharacteristicTypeTargetLockMechanismState: return "HMCharacteristicTypeTargetLockMechanismState"
        case HMCharacteristicTypeMotionDetected: return "HMCharacteristicTypeMotionDetected"
        case HMCharacteristicTypeContactState: return "HMCharacteristicTypeContactState"

        // --- Device Information ---
        case HMCharacteristicTypeVersion: return "HMCharacteristicTypeVersion"
        case "00000020-0000-1000-8000-0026BB765291": return "Manufacturer"
        case "00000021-0000-1000-8000-0026BB765291": return "Model"
        case "00000030-0000-1000-8000-0026BB765291": return "SerialNumber"

        // --- Power and Status ---
        case HMCharacteristicTypeBatteryLevel: return "HMCharacteristicTypeBatteryLevel"
        case HMCharacteristicTypeChargingState: return "HMCharacteristicTypeChargingState"
        case HMCharacteristicTypeStatusLowBattery: return "HMCharacteristicTypeStatusLowBattery"
        case HMCharacteristicTypeStatusFault: return "HMCharacteristicTypeStatusFault"
        case HMCharacteristicTypeOutletInUse: return "HMCharacteristicTypeOutletInUse"

        default:
            // This handles custom vendor types or new types Apple adds later
            return "Unknown/Custom (\(self.characteristicType))"
        }
    }
}
