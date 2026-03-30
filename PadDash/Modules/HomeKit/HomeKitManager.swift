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
    @Published var availableLocks: [LockAccessory] = []
    @Published var availableFans: [FanAccessory] = []
    @Published var availableSwitches: [SwitchAccessory] = []
    @Published var availablePositionDevices: [PositionAccessory] = []
    @Published var availableValves: [ValveAccessory] = []
    @Published var availableSecuritySystems: [SecuritySystemAccessory] = []
    @Published var availableSpeakers: [SpeakerAccessory] = []
    @Published var availableSensors: [SensorAccessory] = []
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

            case .lock:
                guard let refID = UUID(uuidString: entry.referenceID),
                      let lock = availableLocks.first(where: { $0.id == refID }) else { continue }
                var widget = HomeKitWidget(id: widgetID, type: widgetType, light: LightAccessory.placeholder)
                widget.lock = lock
                widget.customName = entry.customName
                restored.append(widget)

            case .fan:
                guard let refID = UUID(uuidString: entry.referenceID),
                      let fan = availableFans.first(where: { $0.id == refID }) else { continue }
                var widget = HomeKitWidget(id: widgetID, type: widgetType, light: LightAccessory.placeholder)
                widget.fan = fan
                widget.customName = entry.customName
                restored.append(widget)

            case .switchToggle, .outlet:
                guard let refID = UUID(uuidString: entry.referenceID),
                      let switchDevice = availableSwitches.first(where: { $0.id == refID }) else { continue }
                var widget = HomeKitWidget(id: widgetID, type: widgetType, light: LightAccessory.placeholder)
                widget.switchDevice = switchDevice
                widget.customName = entry.customName
                restored.append(widget)

            case .door, .window, .windowCovering:
                guard let refID = UUID(uuidString: entry.referenceID),
                      let position = availablePositionDevices.first(where: { $0.id == refID }) else { continue }
                var widget = HomeKitWidget(id: widgetID, type: widgetType, light: LightAccessory.placeholder)
                widget.position = position
                widget.customName = entry.customName
                restored.append(widget)

            case .valve:
                guard let refID = UUID(uuidString: entry.referenceID),
                      let valve = availableValves.first(where: { $0.id == refID }) else { continue }
                var widget = HomeKitWidget(id: widgetID, type: widgetType, light: LightAccessory.placeholder)
                widget.valve = valve
                widget.customName = entry.customName
                restored.append(widget)

            case .securitySystem:
                guard let refID = UUID(uuidString: entry.referenceID),
                      let system = availableSecuritySystems.first(where: { $0.id == refID }) else { continue }
                var widget = HomeKitWidget(id: widgetID, type: widgetType, light: LightAccessory.placeholder)
                widget.securitySystem = system
                widget.customName = entry.customName
                restored.append(widget)

            case .speaker:
                guard let refID = UUID(uuidString: entry.referenceID),
                      let speaker = availableSpeakers.first(where: { $0.id == refID }) else { continue }
                var widget = HomeKitWidget(id: widgetID, type: widgetType, light: LightAccessory.placeholder)
                widget.speaker = speaker
                widget.customName = entry.customName
                restored.append(widget)

            case .temperatureSensor, .motionSensor, .contactSensor, .leakSensor,
                 .airQualitySensor, .carbonMonoxideSensor, .carbonDioxideSensor,
                 .occupancySensor, .lightSensor, .smokeSensor:
                guard let refID = UUID(uuidString: entry.referenceID),
                      let sensor = availableSensors.first(where: { $0.id == refID }) else { continue }
                var widget = HomeKitWidget(id: widgetID, type: widgetType, light: LightAccessory.placeholder)
                widget.sensor = sensor
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
            availableLights = []; availableThermostats = []; availableHumiditySensors = []; availableGarageDoors = []
            availableLocks = []; availableFans = []; availableSwitches = []; availablePositionDevices = []
            availableValves = []; availableSecuritySystems = []; availableSpeakers = []; availableSensors = []
            statusMessage = "No HomeKit home selected."
            isLoading = false
            return
        }

        var discoveredLights: [LightAccessory] = []
        var discoveredThermostats: [ThermostatAccessory] = []
        var discoveredHumidity: [HumiditySensor] = []
        var discoveredGarageDoors: [GarageDoorAccessory] = []
        var discoveredLocks: [LockAccessory] = []
        var discoveredFans: [FanAccessory] = []
        var discoveredSwitches: [SwitchAccessory] = []
        var discoveredPositionDevices: [PositionAccessory] = []
        var discoveredValves: [ValveAccessory] = []
        var discoveredSecuritySystems: [SecuritySystemAccessory] = []
        var discoveredSpeakers: [SpeakerAccessory] = []
        var discoveredSensors: [SensorAccessory] = []

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

            // Discover locks
            for service in accessory.services where service.serviceType == HMServiceTypeLockMechanism {
                let lock = LockAccessory(
                    id: service.uniqueIdentifier, accessory: accessory, service: service,
                    name: service.name, roomName: accessory.room?.name ?? "Default Room",
                    currentState: .unknown, targetState: .secured
                )
                discoveredLocks.append(lock)
                for characteristic in service.characteristics { characteristic.enableNotification(true) { _ in } }
            }

            // Discover fans
            for service in accessory.services where service.serviceType == HMServiceTypeFan {
                let fan = FanAccessory(
                    id: service.uniqueIdentifier, accessory: accessory, service: service,
                    name: service.name, roomName: accessory.room?.name ?? "Default Room",
                    isOn: false, rotationSpeed: 0, rotationDirection: 0
                )
                discoveredFans.append(fan)
                for characteristic in service.characteristics { characteristic.enableNotification(true) { _ in } }
            }

            // Discover switches
            for service in accessory.services where service.serviceType == HMServiceTypeSwitch {
                let sw = SwitchAccessory(
                    id: service.uniqueIdentifier, accessory: accessory, service: service,
                    kind: .toggle, name: service.name, roomName: accessory.room?.name ?? "Default Room",
                    isOn: false
                )
                discoveredSwitches.append(sw)
                for characteristic in service.characteristics { characteristic.enableNotification(true) { _ in } }
            }

            // Discover outlets
            for service in accessory.services where service.serviceType == HMServiceTypeOutlet {
                let outlet = SwitchAccessory(
                    id: service.uniqueIdentifier, accessory: accessory, service: service,
                    kind: .outlet, name: service.name, roomName: accessory.room?.name ?? "Default Room",
                    isOn: false, outletInUse: false
                )
                discoveredSwitches.append(outlet)
                for characteristic in service.characteristics { characteristic.enableNotification(true) { _ in } }
            }

            // Discover window coverings
            for service in accessory.services where service.serviceType == HMServiceTypeWindowCovering {
                let covering = PositionAccessory(
                    id: service.uniqueIdentifier, accessory: accessory, service: service,
                    kind: .windowCovering, name: service.name, roomName: accessory.room?.name ?? "Default Room",
                    currentPosition: 0, targetPosition: 0
                )
                discoveredPositionDevices.append(covering)
                for characteristic in service.characteristics { characteristic.enableNotification(true) { _ in } }
            }

            // Discover doors
            for service in accessory.services where service.serviceType == HMServiceTypeDoor {
                let door = PositionAccessory(
                    id: service.uniqueIdentifier, accessory: accessory, service: service,
                    kind: .door, name: service.name, roomName: accessory.room?.name ?? "Default Room",
                    currentPosition: 0, targetPosition: 0
                )
                discoveredPositionDevices.append(door)
                for characteristic in service.characteristics { characteristic.enableNotification(true) { _ in } }
            }

            // Discover windows
            for service in accessory.services where service.serviceType == HMServiceTypeWindow {
                let window = PositionAccessory(
                    id: service.uniqueIdentifier, accessory: accessory, service: service,
                    kind: .window, name: service.name, roomName: accessory.room?.name ?? "Default Room",
                    currentPosition: 0, targetPosition: 0
                )
                discoveredPositionDevices.append(window)
                for characteristic in service.characteristics { characteristic.enableNotification(true) { _ in } }
            }

            // Discover valves
            for service in accessory.services where service.serviceType == HMServiceTypeValve {
                let valveTypeChar = service.characteristics.first { $0.characteristicType == HMCharacteristicTypeValveType }
                let vType = ValveType(rawValue: valveTypeChar?.value as? Int ?? 0) ?? .generic
                let valve = ValveAccessory(
                    id: service.uniqueIdentifier, accessory: accessory, service: service,
                    name: service.name, roomName: accessory.room?.name ?? "Default Room",
                    isActive: false, inUse: false, valveType: vType
                )
                discoveredValves.append(valve)
                for characteristic in service.characteristics { characteristic.enableNotification(true) { _ in } }
            }

            // Discover security systems
            for service in accessory.services where service.serviceType == HMServiceTypeSecuritySystem {
                let system = SecuritySystemAccessory(
                    id: service.uniqueIdentifier, accessory: accessory, service: service,
                    name: service.name, roomName: accessory.room?.name ?? "Default Room",
                    currentState: .disarmed, targetState: .disarmed
                )
                discoveredSecuritySystems.append(system)
                for characteristic in service.characteristics { characteristic.enableNotification(true) { _ in } }
            }

            // Discover speakers
            for service in accessory.services where service.serviceType == HMServiceTypeSpeaker {
                let speaker = SpeakerAccessory(
                    id: service.uniqueIdentifier, accessory: accessory, service: service,
                    name: service.name, roomName: accessory.room?.name ?? "Default Room",
                    isMuted: false, volume: 50
                )
                discoveredSpeakers.append(speaker)
                for characteristic in service.characteristics { characteristic.enableNotification(true) { _ in } }
            }

            // Discover sensors (all 10 types)
            for sensorType in SensorType.allCases {
                for service in accessory.services where service.serviceType == sensorType.serviceType {
                    let alreadyAdded = discoveredSensors.contains { $0.service.uniqueIdentifier == service.uniqueIdentifier }
                    guard !alreadyAdded else { continue }
                    let sensor = SensorAccessory(
                        id: service.uniqueIdentifier, accessory: accessory, service: service,
                        sensorType: sensorType, name: accessory.name,
                        roomName: accessory.room?.name ?? "Default Room"
                    )
                    discoveredSensors.append(sensor)
                    for characteristic in service.characteristics { characteristic.enableNotification(true) { _ in } }
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
        availableLocks = discoveredLocks
        availableFans = discoveredFans
        availableSwitches = discoveredSwitches
        availablePositionDevices = discoveredPositionDevices
        availableValves = discoveredValves
        availableSecuritySystems = discoveredSecuritySystems
        availableSpeakers = discoveredSpeakers
        availableSensors = discoveredSensors

        let totalAccessories = discoveredLights.count + discoveredThermostats.count + discoveredHumidity.count
            + discoveredGarageDoors.count + discoveredLocks.count + discoveredFans.count
            + discoveredSwitches.count + discoveredPositionDevices.count + discoveredValves.count
            + discoveredSecuritySystems.count + discoveredSpeakers.count + discoveredSensors.count
        statusMessage = totalAccessories == 0 ? "No compatible accessories found in \(home.name)." : nil
        isLoading = false

        for light in discoveredLights { refreshLightValues(for: light) }
        for thermostat in discoveredThermostats { refreshThermostatValues(for: thermostat) }
        for sensor in discoveredHumidity { refreshHumidityValues(for: sensor) }
        for garageDoor in discoveredGarageDoors { refreshGarageDoorValues(for: garageDoor) }
        for lock in discoveredLocks { refreshLockValues(for: lock) }
        for fan in discoveredFans { refreshFanValues(for: fan) }
        for sw in discoveredSwitches { refreshSwitchValues(for: sw) }
        for pos in discoveredPositionDevices { refreshPositionValues(for: pos) }
        for valve in discoveredValves { refreshValveValues(for: valve) }
        for system in discoveredSecuritySystems { refreshSecuritySystemValues(for: system) }
        for speaker in discoveredSpeakers { refreshSpeakerValues(for: speaker) }
        for sensor in discoveredSensors { refreshSensorValues(for: sensor) }

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
                if let t = widget.thermostat, let fresh = availableThermostats.first(where: { $0.id == t.id }) {
                    widgets[widgetIndex].thermostat = fresh
                }
            case .humidity:
                break
            case .garageDoor:
                if let g = widget.garageDoor, let fresh = availableGarageDoors.first(where: { $0.id == g.id }) {
                    widgets[widgetIndex].garageDoor = fresh
                }
            case .lock:
                if let l = widget.lock, let fresh = availableLocks.first(where: { $0.id == l.id }) {
                    widgets[widgetIndex].lock = fresh
                }
            case .fan:
                if let f = widget.fan, let fresh = availableFans.first(where: { $0.id == f.id }) {
                    widgets[widgetIndex].fan = fresh
                }
            case .switchToggle, .outlet:
                if let s = widget.switchDevice, let fresh = availableSwitches.first(where: { $0.id == s.id }) {
                    widgets[widgetIndex].switchDevice = fresh
                }
            case .door, .window, .windowCovering:
                if let p = widget.position, let fresh = availablePositionDevices.first(where: { $0.id == p.id }) {
                    widgets[widgetIndex].position = fresh
                }
            case .valve:
                if let v = widget.valve, let fresh = availableValves.first(where: { $0.id == v.id }) {
                    widgets[widgetIndex].valve = fresh
                }
            case .securitySystem:
                if let ss = widget.securitySystem, let fresh = availableSecuritySystems.first(where: { $0.id == ss.id }) {
                    widgets[widgetIndex].securitySystem = fresh
                }
            case .speaker:
                if let sp = widget.speaker, let fresh = availableSpeakers.first(where: { $0.id == sp.id }) {
                    widgets[widgetIndex].speaker = fresh
                }
            case .temperatureSensor, .motionSensor, .contactSensor, .leakSensor,
                 .airQualitySensor, .carbonMonoxideSensor, .carbonDioxideSensor,
                 .occupancySensor, .lightSensor, .smokeSensor:
                if let sn = widget.sensor, let fresh = availableSensors.first(where: { $0.id == sn.id }) {
                    widgets[widgetIndex].sensor = fresh
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

    func addLockWidget(for lock: LockAccessory) {
        guard let type = pendingWidgetType else { return }
        var widget = HomeKitWidget(id: UUID(), type: type, light: LightAccessory.placeholder)
        widget.lock = lock
        widgets.append(widget)
        showAccessoryPicker = false; pendingWidgetType = nil; saveState()
    }

    func addFanWidget(for fan: FanAccessory) {
        guard let type = pendingWidgetType else { return }
        var widget = HomeKitWidget(id: UUID(), type: type, light: LightAccessory.placeholder)
        widget.fan = fan
        widgets.append(widget)
        showAccessoryPicker = false; pendingWidgetType = nil; saveState()
    }

    func addSwitchWidget(for sw: SwitchAccessory) {
        guard let type = pendingWidgetType else { return }
        var widget = HomeKitWidget(id: UUID(), type: type, light: LightAccessory.placeholder)
        widget.switchDevice = sw
        widgets.append(widget)
        showAccessoryPicker = false; pendingWidgetType = nil; saveState()
    }

    func addPositionWidget(for pos: PositionAccessory) {
        guard let type = pendingWidgetType else { return }
        var widget = HomeKitWidget(id: UUID(), type: type, light: LightAccessory.placeholder)
        widget.position = pos
        widgets.append(widget)
        showAccessoryPicker = false; pendingWidgetType = nil; saveState()
    }

    func addValveWidget(for valve: ValveAccessory) {
        guard let type = pendingWidgetType else { return }
        var widget = HomeKitWidget(id: UUID(), type: type, light: LightAccessory.placeholder)
        widget.valve = valve
        widgets.append(widget)
        showAccessoryPicker = false; pendingWidgetType = nil; saveState()
    }

    func addSecuritySystemWidget(for system: SecuritySystemAccessory) {
        guard let type = pendingWidgetType else { return }
        var widget = HomeKitWidget(id: UUID(), type: type, light: LightAccessory.placeholder)
        widget.securitySystem = system
        widgets.append(widget)
        showAccessoryPicker = false; pendingWidgetType = nil; saveState()
    }

    func addSpeakerWidget(for speaker: SpeakerAccessory) {
        guard let type = pendingWidgetType else { return }
        var widget = HomeKitWidget(id: UUID(), type: type, light: LightAccessory.placeholder)
        widget.speaker = speaker
        widgets.append(widget)
        showAccessoryPicker = false; pendingWidgetType = nil; saveState()
    }

    func addSensorWidget(for sensor: SensorAccessory) {
        guard let type = pendingWidgetType else { return }
        var widget = HomeKitWidget(id: UUID(), type: type, light: LightAccessory.placeholder)
        widget.sensor = sensor
        widgets.append(widget)
        showAccessoryPicker = false; pendingWidgetType = nil; saveState()
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

    var unaddedLocks: [LockAccessory] {
        let addedIDs = Set(widgets.compactMap { $0.lock?.id })
        return availableLocks.filter { !addedIDs.contains($0.id) }
    }

    var unaddedFans: [FanAccessory] {
        let addedIDs = Set(widgets.compactMap { $0.fan?.id })
        return availableFans.filter { !addedIDs.contains($0.id) }
    }

    var unaddedSwitches: [SwitchAccessory] {
        let addedIDs = Set(widgets.compactMap { $0.switchDevice?.id })
        return availableSwitches.filter { !addedIDs.contains($0.id) }
    }

    var unaddedPositionDevices: [PositionAccessory] {
        let addedIDs = Set(widgets.compactMap { $0.position?.id })
        return availablePositionDevices.filter { !addedIDs.contains($0.id) }
    }

    var unaddedValves: [ValveAccessory] {
        let addedIDs = Set(widgets.compactMap { $0.valve?.id })
        return availableValves.filter { !addedIDs.contains($0.id) }
    }

    var unaddedSecuritySystems: [SecuritySystemAccessory] {
        let addedIDs = Set(widgets.compactMap { $0.securitySystem?.id })
        return availableSecuritySystems.filter { !addedIDs.contains($0.id) }
    }

    var unaddedSpeakers: [SpeakerAccessory] {
        let addedIDs = Set(widgets.compactMap { $0.speaker?.id })
        return availableSpeakers.filter { !addedIDs.contains($0.id) }
    }

    func unaddedSensors(for sensorType: SensorType) -> [SensorAccessory] {
        let addedIDs = Set(widgets.compactMap { $0.sensor?.id })
        return availableSensors.filter { $0.sensorType == sensorType && !addedIDs.contains($0.id) }
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

    // MARK: - Lock Refresh & Control

    func refreshLockValues(for lock: LockAccessory) {
        lock.currentLockStateCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateLockState(for: lock) }
        }
        lock.targetLockStateCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateLockState(for: lock) }
        }
    }

    func updateLockState(for lock: LockAccessory) {
        guard let index = availableLocks.firstIndex(where: { $0.id == lock.id }) else { return }
        if let state = lock.currentLockStateCharacteristic?.value as? Int {
            availableLocks[index].currentState = LockState(rawValue: state) ?? .unknown
        }
        if let target = lock.targetLockStateCharacteristic?.value as? Int {
            availableLocks[index].targetState = LockTargetState(rawValue: target) ?? .secured
        }
        availableLocks[index].isStale = false
        for (wIndex, widget) in widgets.enumerated() {
            if widget.type == .lock, widget.lock?.id == lock.id {
                widgets[wIndex].lock = availableLocks[index]
            }
        }
    }

    func toggleLock(for lock: LockAccessory) {
        guard let characteristic = lock.targetLockStateCharacteristic else { return }
        let newTarget: LockTargetState = lock.currentState == .secured ? .unsecured : .secured
        if let index = availableLocks.firstIndex(where: { $0.id == lock.id }) {
            availableLocks[index].targetState = newTarget
            for (wIndex, widget) in widgets.enumerated() {
                if widget.type == .lock, widget.lock?.id == lock.id {
                    widgets[wIndex].lock?.targetState = newTarget
                }
            }
        }
        characteristic.writeValue(newTarget.rawValue) { _ in }
    }

    // MARK: - Fan Refresh & Control

    func refreshFanValues(for fan: FanAccessory) {
        fan.powerCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateFanState(for: fan) }
        }
        fan.rotationSpeedCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateFanState(for: fan) }
        }
        fan.rotationDirectionCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateFanState(for: fan) }
        }
    }

    func updateFanState(for fan: FanAccessory) {
        guard let index = availableFans.firstIndex(where: { $0.id == fan.id }) else { return }
        if let power = fan.powerCharacteristic?.value as? Bool { availableFans[index].isOn = power }
        if let speed = fan.rotationSpeedCharacteristic?.value as? NSNumber {
            availableFans[index].rotationSpeed = speed.intValue
        }
        if let dir = fan.rotationDirectionCharacteristic?.value as? Int { availableFans[index].rotationDirection = dir }
        availableFans[index].isStale = false
        for (wIndex, widget) in widgets.enumerated() {
            if widget.type == .fan, widget.fan?.id == fan.id { widgets[wIndex].fan = availableFans[index] }
        }
    }

    func toggleFanPower(for fan: FanAccessory) {
        guard let characteristic = fan.powerCharacteristic else { return }
        let newValue = !fan.isOn
        if let index = availableFans.firstIndex(where: { $0.id == fan.id }) {
            availableFans[index].isOn = newValue
            for (wIndex, widget) in widgets.enumerated() {
                if widget.type == .fan, widget.fan?.id == fan.id { widgets[wIndex].fan?.isOn = newValue }
            }
        }
        characteristic.writeValue(newValue) { _ in }
    }

    func setFanSpeed(for fan: FanAccessory, value: Int) {
        guard let characteristic = fan.rotationSpeedCharacteristic else { return }
        let clamped = min(100, max(0, value))
        if let index = availableFans.firstIndex(where: { $0.id == fan.id }) {
            availableFans[index].rotationSpeed = clamped
            for (wIndex, widget) in widgets.enumerated() {
                if widget.type == .fan, widget.fan?.id == fan.id { widgets[wIndex].fan?.rotationSpeed = clamped }
            }
        }
        characteristic.writeValue(clamped) { _ in }
    }

    func toggleFanDirection(for fan: FanAccessory) {
        guard let characteristic = fan.rotationDirectionCharacteristic else { return }
        let newDir = fan.rotationDirection == 0 ? 1 : 0
        if let index = availableFans.firstIndex(where: { $0.id == fan.id }) {
            availableFans[index].rotationDirection = newDir
            for (wIndex, widget) in widgets.enumerated() {
                if widget.type == .fan, widget.fan?.id == fan.id { widgets[wIndex].fan?.rotationDirection = newDir }
            }
        }
        characteristic.writeValue(newDir) { _ in }
    }

    // MARK: - Switch/Outlet Refresh & Control

    func refreshSwitchValues(for sw: SwitchAccessory) {
        sw.powerCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateSwitchState(for: sw) }
        }
        sw.outletInUseCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateSwitchState(for: sw) }
        }
    }

    func updateSwitchState(for sw: SwitchAccessory) {
        guard let index = availableSwitches.firstIndex(where: { $0.id == sw.id }) else { return }
        if let power = sw.powerCharacteristic?.value as? Bool { availableSwitches[index].isOn = power }
        if let inUse = sw.outletInUseCharacteristic?.value as? Bool { availableSwitches[index].outletInUse = inUse }
        availableSwitches[index].isStale = false
        for (wIndex, widget) in widgets.enumerated() {
            if (widget.type == .switchToggle || widget.type == .outlet), widget.switchDevice?.id == sw.id {
                widgets[wIndex].switchDevice = availableSwitches[index]
            }
        }
    }

    func toggleSwitchPower(for sw: SwitchAccessory) {
        guard let characteristic = sw.powerCharacteristic else { return }
        let newValue = !sw.isOn
        if let index = availableSwitches.firstIndex(where: { $0.id == sw.id }) {
            availableSwitches[index].isOn = newValue
            for (wIndex, widget) in widgets.enumerated() {
                if (widget.type == .switchToggle || widget.type == .outlet), widget.switchDevice?.id == sw.id {
                    widgets[wIndex].switchDevice?.isOn = newValue
                }
            }
        }
        characteristic.writeValue(newValue) { _ in }
    }

    // MARK: - Position (Door/Window/Covering) Refresh & Control

    func refreshPositionValues(for pos: PositionAccessory) {
        pos.currentPositionCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updatePositionState(for: pos) }
        }
        pos.targetPositionCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updatePositionState(for: pos) }
        }
    }

    func updatePositionState(for pos: PositionAccessory) {
        guard let index = availablePositionDevices.firstIndex(where: { $0.id == pos.id }) else { return }
        if let current = pos.currentPositionCharacteristic?.value as? Int { availablePositionDevices[index].currentPosition = current }
        if let target = pos.targetPositionCharacteristic?.value as? Int { availablePositionDevices[index].targetPosition = target }
        availablePositionDevices[index].isStale = false
        for (wIndex, widget) in widgets.enumerated() {
            if (widget.type == .door || widget.type == .window || widget.type == .windowCovering),
               widget.position?.id == pos.id {
                widgets[wIndex].position = availablePositionDevices[index]
            }
        }
    }

    func setTargetPosition(for pos: PositionAccessory, value: Int) {
        guard let characteristic = pos.targetPositionCharacteristic else { return }
        let clamped = min(100, max(0, value))
        if let index = availablePositionDevices.firstIndex(where: { $0.id == pos.id }) {
            availablePositionDevices[index].targetPosition = clamped
            for (wIndex, widget) in widgets.enumerated() {
                if (widget.type == .door || widget.type == .window || widget.type == .windowCovering),
                   widget.position?.id == pos.id {
                    widgets[wIndex].position?.targetPosition = clamped
                }
            }
        }
        characteristic.writeValue(clamped) { _ in }
    }

    // MARK: - Valve Refresh & Control

    func refreshValveValues(for valve: ValveAccessory) {
        valve.activeCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateValveState(for: valve) }
        }
        valve.inUseCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateValveState(for: valve) }
        }
    }

    func updateValveState(for valve: ValveAccessory) {
        guard let index = availableValves.firstIndex(where: { $0.id == valve.id }) else { return }
        if let active = valve.activeCharacteristic?.value as? Int { availableValves[index].isActive = active == 1 }
        if let inUse = valve.inUseCharacteristic?.value as? Int { availableValves[index].inUse = inUse == 1 }
        availableValves[index].isStale = false
        for (wIndex, widget) in widgets.enumerated() {
            if widget.type == .valve, widget.valve?.id == valve.id {
                widgets[wIndex].valve = availableValves[index]
            }
        }
    }

    func toggleValve(for valve: ValveAccessory) {
        guard let characteristic = valve.activeCharacteristic else { return }
        let newActive = !valve.isActive
        if let index = availableValves.firstIndex(where: { $0.id == valve.id }) {
            availableValves[index].isActive = newActive
            for (wIndex, widget) in widgets.enumerated() {
                if widget.type == .valve, widget.valve?.id == valve.id {
                    widgets[wIndex].valve?.isActive = newActive
                }
            }
        }
        characteristic.writeValue(newActive ? 1 : 0) { _ in }
    }

    // MARK: - Security System Refresh & Control

    func refreshSecuritySystemValues(for system: SecuritySystemAccessory) {
        system.currentStateCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateSecuritySystemState(for: system) }
        }
        system.targetStateCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateSecuritySystemState(for: system) }
        }
    }

    func updateSecuritySystemState(for system: SecuritySystemAccessory) {
        guard let index = availableSecuritySystems.firstIndex(where: { $0.id == system.id }) else { return }
        if let state = system.currentStateCharacteristic?.value as? Int {
            availableSecuritySystems[index].currentState = SecuritySystemState(rawValue: state) ?? .disarmed
        }
        if let target = system.targetStateCharacteristic?.value as? Int {
            availableSecuritySystems[index].targetState = SecuritySystemTargetState(rawValue: target) ?? .disarmed
        }
        availableSecuritySystems[index].isStale = false
        for (wIndex, widget) in widgets.enumerated() {
            if widget.type == .securitySystem, widget.securitySystem?.id == system.id {
                widgets[wIndex].securitySystem = availableSecuritySystems[index]
            }
        }
    }

    func setSecuritySystemMode(for system: SecuritySystemAccessory, mode: SecuritySystemTargetState) {
        guard let characteristic = system.targetStateCharacteristic else { return }
        if let index = availableSecuritySystems.firstIndex(where: { $0.id == system.id }) {
            availableSecuritySystems[index].targetState = mode
            for (wIndex, widget) in widgets.enumerated() {
                if widget.type == .securitySystem, widget.securitySystem?.id == system.id {
                    widgets[wIndex].securitySystem?.targetState = mode
                }
            }
        }
        characteristic.writeValue(mode.rawValue) { _ in }
    }

    // MARK: - Speaker Refresh & Control

    func refreshSpeakerValues(for speaker: SpeakerAccessory) {
        speaker.muteCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateSpeakerState(for: speaker) }
        }
        speaker.volumeCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateSpeakerState(for: speaker) }
        }
    }

    func updateSpeakerState(for speaker: SpeakerAccessory) {
        guard let index = availableSpeakers.firstIndex(where: { $0.id == speaker.id }) else { return }
        if let muted = speaker.muteCharacteristic?.value as? Bool { availableSpeakers[index].isMuted = muted }
        if let volume = speaker.volumeCharacteristic?.value as? Int { availableSpeakers[index].volume = volume }
        availableSpeakers[index].isStale = false
        for (wIndex, widget) in widgets.enumerated() {
            if widget.type == .speaker, widget.speaker?.id == speaker.id {
                widgets[wIndex].speaker = availableSpeakers[index]
            }
        }
    }

    func toggleSpeakerMute(for speaker: SpeakerAccessory) {
        guard let characteristic = speaker.muteCharacteristic else { return }
        let newMuted = !speaker.isMuted
        if let index = availableSpeakers.firstIndex(where: { $0.id == speaker.id }) {
            availableSpeakers[index].isMuted = newMuted
            for (wIndex, widget) in widgets.enumerated() {
                if widget.type == .speaker, widget.speaker?.id == speaker.id {
                    widgets[wIndex].speaker?.isMuted = newMuted
                }
            }
        }
        characteristic.writeValue(newMuted) { _ in }
    }

    func setSpeakerVolume(for speaker: SpeakerAccessory, value: Int) {
        guard let characteristic = speaker.volumeCharacteristic else { return }
        let clamped = min(100, max(0, value))
        if let index = availableSpeakers.firstIndex(where: { $0.id == speaker.id }) {
            availableSpeakers[index].volume = clamped
            for (wIndex, widget) in widgets.enumerated() {
                if widget.type == .speaker, widget.speaker?.id == speaker.id {
                    widgets[wIndex].speaker?.volume = clamped
                }
            }
        }
        characteristic.writeValue(clamped) { _ in }
    }

    // MARK: - Sensor Refresh

    func refreshSensorValues(for sensor: SensorAccessory) {
        sensor.primaryCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateSensorState(for: sensor) }
        }
        sensor.secondaryCharacteristic?.readValue { [weak self] _ in
            Task { @MainActor in self?.updateSensorState(for: sensor) }
        }
    }

    func updateSensorState(for sensor: SensorAccessory) {
        guard let index = availableSensors.firstIndex(where: { $0.id == sensor.id }) else { return }
        if let value = sensor.primaryCharacteristic?.value as? NSNumber {
            availableSensors[index].primaryValue = value.doubleValue
        }
        if let value = sensor.secondaryCharacteristic?.value as? NSNumber {
            availableSensors[index].secondaryValue = value.doubleValue
        }
        availableSensors[index].isStale = false
        for (wIndex, widget) in widgets.enumerated() {
            if widget.type.sensorType != nil, widget.sensor?.id == sensor.id {
                widgets[wIndex].sensor = availableSensors[index]
            }
        }
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
