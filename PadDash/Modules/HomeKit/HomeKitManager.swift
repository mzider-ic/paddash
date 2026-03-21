import SwiftUI
import HomeKit

// MARK: - HomeKit Manager

@MainActor
final class HomeKitManager: NSObject, ObservableObject {

    // Published state
    @Published var homes: [HMHome] = []
    @Published var selectedHome: HMHome?
    @Published var availableLights: [LightAccessory] = []
    @Published var widgets: [HomeKitWidget] = []
    @Published var statusMessage: String?
    @Published var isLoading = true

    // Sheet state
    @Published var showWidgetTypePicker = false
    @Published var showAccessoryPicker = false
    @Published var pendingWidgetType: HomeKitWidgetType?

    let homeManager = HMHomeManager()
    private let store = DashboardStore.shared

    override init() {
        super.init()
        homeManager.delegate = self
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
                referenceID: $0.light.id.uuidString
            )
        }
        store.saveHomeKitWidgets(entries)
    }

    func restoreSelectedHome() {
        guard let savedID = store.loadSelectedHomeID() else { return }
        selectedHome = homes.first { $0.uniqueIdentifier == savedID }
    }

    func restoreWidgets() {
        let entries = store.loadHomeKitWidgets()
        var restored: [HomeKitWidget] = []
        for entry in entries {
            guard let widgetType = HomeKitWidgetType(rawValue: entry.kind),
                  let lightID = UUID(uuidString: entry.referenceID),
                  let light = availableLights.first(where: { $0.id == lightID }),
                  let widgetID = UUID(uuidString: entry.id) else { continue }
            restored.append(HomeKitWidget(id: widgetID, type: widgetType, light: light))
        }
        widgets = restored
    }

    // MARK: - Home Selection

    func selectHome(_ home: HMHome) {
        selectedHome = home
        discoverLights()
        saveState()
    }

    // MARK: - Discovery

    func discoverLights() {
        guard let home = selectedHome else {
            availableLights = []
            statusMessage = "No HomeKit home selected."
            isLoading = false
            return
        }

        var discovered: [LightAccessory] = []

        // Discover individual lightbulb services
        for accessory in home.accessories {
            accessory.delegate = self
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
                discovered.append(light)

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
            discovered.append(groupLight)

            for service in lightServices {
                for characteristic in service.characteristics {
                    characteristic.enableNotification(true) { _ in }
                }
            }
        }

        availableLights = discovered
        statusMessage = discovered.isEmpty ? "No lights found in \(home.name). Add lightbulb accessories in the Home app." : nil
        isLoading = false

        for light in discovered {
            refreshValues(for: light)
        }

        refreshWidgetLights()
    }

    private func refreshWidgetLights() {
        for (widgetIndex, widget) in widgets.enumerated() {
            if let freshLight = availableLights.first(where: { $0.id == widget.light.id }) {
                widgets[widgetIndex] = HomeKitWidget(
                    id: widget.id,
                    type: widget.type,
                    light: freshLight
                )
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
        showAccessoryPicker = true
    }

    func addWidget(for light: LightAccessory) {
        guard let type = pendingWidgetType else { return }
        let widget = HomeKitWidget(id: UUID(), type: type, light: light)
        widgets.append(widget)
        showAccessoryPicker = false
        pendingWidgetType = nil
        saveState()
    }

    func removeWidget(_ widget: HomeKitWidget) {
        widgets.removeAll { $0.id == widget.id }
        saveState()
    }

    /// Lights that haven't been added as widgets yet
    var unaddedLights: [LightAccessory] {
        let widgetServiceIDs = Set(widgets.map { $0.light.service.uniqueIdentifier })
        return availableLights.filter { !widgetServiceIDs.contains($0.service.uniqueIdentifier) }
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

    // MARK: - Read Values

    func refreshValues(for light: LightAccessory) {
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

    func updateLocalState(for light: LightAccessory) {
        if let index = availableLights.firstIndex(where: { $0.id == light.id }) {
            if let power = light.powerCharacteristic?.value as? Bool {
                availableLights[index].isOn = power
            }
            if let brightness = light.brightnessCharacteristic?.value as? Int {
                availableLights[index].brightness = brightness
            }
        }
        updateWidgetState(for: light)
    }

    func updateWidgetState(for light: LightAccessory) {
        for (index, widget) in widgets.enumerated() {
            if widget.light.service.uniqueIdentifier == light.service.uniqueIdentifier {
                if let power = light.powerCharacteristic?.value as? Bool {
                    widgets[index] = HomeKitWidget(
                        id: widget.id,
                        type: widget.type,
                        light: LightAccessory(
                            id: widget.light.id,
                            accessory: widget.light.accessory,
                            service: widget.light.service,
                            name: widget.light.name,
                            roomName: widget.light.roomName,
                            isOn: power,
                            brightness: widgets[index].light.brightness,
                            categoryType: widget.light.categoryType,
                            isGroup: widget.light.isGroup,
                            groupServices: widget.light.groupServices
                        )
                    )
                }
                if let brightness = light.brightnessCharacteristic?.value as? Int {
                    var updatedLight = widgets[index].light
                    updatedLight.brightness = brightness
                    widgets[index] = HomeKitWidget(
                        id: widget.id,
                        type: widget.type,
                        light: updatedLight
                    )
                }
            }
        }
    }

    // MARK: - Controls

    func togglePower(for light: LightAccessory) {
        let characteristics = light.allPowerCharacteristics
        guard !characteristics.isEmpty else { return }
        let newValue = !light.isOn

        if let index = availableLights.firstIndex(where: { $0.id == light.id }) {
            availableLights[index].isOn = newValue
        }
        for (index, widget) in widgets.enumerated() {
            if widget.light.service.uniqueIdentifier == light.service.uniqueIdentifier {
                var updated = widget.light
                updated.isOn = newValue
                widgets[index] = HomeKitWidget(id: widget.id, type: widget.type, light: updated)
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
            if widget.light.id == light.id {
                var updated = widget.light
                updated.isOn = newValue
                widgets[index] = HomeKitWidget(id: widget.id, type: widget.type, light: updated)
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
        for (index, widget) in widgets.enumerated() {
            if widget.light.service.uniqueIdentifier == light.service.uniqueIdentifier {
                var updated = widget.light
                updated.brightness = clamped
                widgets[index] = HomeKitWidget(id: widget.id, type: widget.type, light: updated)
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
