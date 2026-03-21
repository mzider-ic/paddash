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

// MARK: - HomeKit Widget Type

enum HomeKitWidgetType: String, CaseIterable, Identifiable {
    case lightDimmer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lightDimmer: return "Light Dimmer"
        }
    }

    var icon: String {
        switch self {
        case .lightDimmer: return "lightbulb.fill"
        }
    }

    var description: String {
        switch self {
        case .lightDimmer: return "Control brightness and power for a light"
        }
    }

    var accent: Color {
        switch self {
        case .lightDimmer: return DS.Color.accentAmber
        }
    }
}

// MARK: - HomeKit Widget

struct HomeKitWidget: Identifiable {
    let id: UUID
    let type: HomeKitWidgetType
    let light: LightAccessory

    var accessoryName: String { light.name }
    var roomName: String { light.roomName }
}

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

    private let homeManager = HMHomeManager()

    override init() {
        super.init()
        homeManager.delegate = self
    }

    // MARK: - Home Selection

    func selectHome(_ home: HMHome) {
        selectedHome = home
        discoverLights()
    }

    // MARK: - Discovery

    private func discoverLights() {
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

                // Enable notifications for live updates
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

            // Use the first service's accessory as the representative for the group
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

        // Read current values
        for light in discovered {
            refreshValues(for: light)
        }

        // Also refresh any existing widgets that reference lights in this home
        refreshWidgetLights()
    }

    private func refreshWidgetLights() {
        for (widgetIndex, widget) in widgets.enumerated() {
            if let freshLight = availableLights.first(where: {
                $0.id == widget.light.id
            }) {
                // This now correctly passes the object containing the groupServices array
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
    }

    func removeWidget(_ widget: HomeKitWidget) {
        widgets.removeAll { $0.id == widget.id }
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

    private func refreshValues(for light: LightAccessory) {
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

    private func updateLocalState(for light: LightAccessory) {
        // Update in availableLights
        if let index = availableLights.firstIndex(where: { $0.id == light.id }) {
            if let power = light.powerCharacteristic?.value as? Bool {
                availableLights[index].isOn = power
            }
            if let brightness = light.brightnessCharacteristic?.value as? Int {
                availableLights[index].brightness = brightness
            }
        }

        // Also update any widget using this light
        updateWidgetState(for: light)
    }

    private func updateWidgetState(for light: LightAccessory) {
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

        // Optimistically update UI immediately
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

        // Write to all characteristics (handles groups)
        for characteristic in characteristics {
            characteristic.writeValue(newValue) { _ in }
        }
    }
    
    func togglePowerForGroupLight(light: LightAccessory) {
        print("Group Light: \(light)")
        let characteristics = light.allPowerCharacteristics
        guard !characteristics.isEmpty else { return }
        let newValue = !light.isOn

        for service in light.groupServices {
            if let characteristic = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypePowerState }) {
                
                characteristic.writeValue(newValue) { error in
                    if let error = error {
                        print("Failed to update \(service.name): \(error.localizedDescription)")
                    } else {
                        print("Successfully updated \(service.name)")
                    }
                }
            }
        }

    }

    func setBrightness(for light: LightAccessory, value: Int) {
        let characteristics = light.allBrightnessCharacteristics
        guard !characteristics.isEmpty else { return }
        let clamped = min(100, max(0, value))

        // Optimistically update UI immediately
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

        // Write to all characteristics (handles groups)
        for characteristic in characteristics {
            characteristic.writeValue(clamped) { _ in }
        }
    }
}

// MARK: - HMHomeManagerDelegate

extension HomeKitManager: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            homes = manager.homes
            // Auto-select the first home if none selected
            if selectedHome == nil {
                selectedHome = manager.primaryHome ?? manager.homes.first
            }
            discoverLights()
        }
    }
}

// MARK: - HMAccessoryDelegate

extension HomeKitManager: HMAccessoryDelegate {
    nonisolated func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        Task { @MainActor in
            // Update availableLights
            if let index = availableLights.firstIndex(where: { $0.service == service }) {
                if characteristic.characteristicType == HMCharacteristicTypePowerState,
                   let value = characteristic.value as? Bool {
                    availableLights[index].isOn = value
                }
                if characteristic.characteristicType == HMCharacteristicTypeBrightness,
                   let value = characteristic.value as? Int {
                    availableLights[index].brightness = value
                }
                // Propagate to widgets
                updateWidgetState(for: availableLights[index])
            }
        }
    }
}
