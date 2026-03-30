import SwiftUI
import UniformTypeIdentifiers

// MARK: - HomeKit Dashboard View

struct HomeKitDashboardView: View {
    @ObservedObject var manager: HomeKitManager
    @State private var draggedWidget: HomeKitWidget?
    @State private var widgetPendingRemoval: HomeKitWidget?

    var body: some View {
        VStack(spacing: 0) {
            // Home picker (only show if multiple homes)
            if manager.homes.count > 1 {
                homePicker
                    .padding(.bottom, DS.Space.sm)
            }

            // Main content
            Group {
                if manager.isLoading {
                    loadingView
                } else if manager.widgets.isEmpty && manager.availableLights.isEmpty && manager.availableThermostats.isEmpty && manager.availableGarageDoors.isEmpty && manager.availableLocks.isEmpty && manager.availableFans.isEmpty && manager.availableSwitches.isEmpty && manager.availablePositionDevices.isEmpty && manager.availableValves.isEmpty && manager.availableSecuritySystems.isEmpty && manager.availableSpeakers.isEmpty && manager.availableSensors.isEmpty {
                    if let message = manager.statusMessage {
                        emptyStateView(message: message)
                    } else {
                        emptyStateView(message: "Tap + to add a HomeKit widget.")
                    }
                } else if manager.widgets.isEmpty {
                    emptyStateView(message: "Tap + to add a HomeKit widget.")
                } else {
                    widgetsGrid
                }
            }
        }
        .sheet(isPresented: $manager.showWidgetTypePicker) {
            WidgetTypePickerSheet(manager: manager)
        }
        .sheet(isPresented: $manager.showAccessoryPicker) {
            AccessoryPickerSheet(manager: manager)
        }
        .alert("Rename Widget", isPresented: Binding(
            get: { manager.widgetBeingRenamed != nil },
            set: { if !$0 { manager.cancelRename() } }
        )) {
            TextField("Widget name", text: $manager.renameText)
            Button("Save") { manager.commitRename() }
            Button("Cancel", role: .cancel) { manager.cancelRename() }
        } message: {
            Text("Enter a custom name for this widget.")
        }
        .alert(
            "Remove Widget?",
            isPresented: Binding(
                get: { widgetPendingRemoval != nil },
                set: { if !$0 { widgetPendingRemoval = nil } }
            ),
            presenting: widgetPendingRemoval
        ) { widget in
            Button("Remove", role: .destructive) {
                withAnimation(DS.Animation.snappy) {
                    manager.removeWidget(widget)
                    widgetPendingRemoval = nil
                }
            }
            Button("Cancel", role: .cancel) {
                widgetPendingRemoval = nil
            }
        } message: { widget in
            Text("Remove \"\(widget.displayName)\" from the dashboard?")
        }
    }

    // MARK: - Home Picker

    private var homePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Space.sm) {
                ForEach(manager.homes, id: \.uniqueIdentifier) { home in
                    Button {
                        withAnimation(DS.Animation.snappy) {
                            manager.selectHome(home)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: home.uniqueIdentifier == manager.selectedHome?.uniqueIdentifier ? "house.fill" : "house")
                                .font(.system(size: 12, weight: .semibold))
                            Text(home.name)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(
                            home.uniqueIdentifier == manager.selectedHome?.uniqueIdentifier
                            ? DS.Color.accentAmber
                            : DS.Color.textSecondary
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            home.uniqueIdentifier == manager.selectedHome?.uniqueIdentifier
                            ? DS.Color.accentAmber.opacity(0.15)
                            : DS.Color.surfaceRaised
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    home.uniqueIdentifier == manager.selectedHome?.uniqueIdentifier
                                    ? DS.Color.accentAmber.opacity(0.3)
                                    : DS.Color.border,
                                    lineWidth: 1
                                )
                        )
                    }
                }
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: DS.Space.md) {
            Spacer()
            ProgressView()
                .tint(DS.Color.accentAmber)
            Text("Discovering accessories...")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(DS.Color.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private func emptyStateView(message: String) -> some View {
        VStack(spacing: DS.Space.md) {
            Spacer()
            Image(systemName: "lightbulb.slash")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(DS.Color.accentAmber.opacity(0.5))
            Text("No Widgets Yet")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(DS.Color.textPrimary)
            Text(message)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(DS.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Space.xl)

            Button {
                manager.beginAddWidget()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Add Widget")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundColor(DS.Color.accentAmber)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(DS.Color.accentAmber.opacity(0.15))
                .clipShape(Capsule())
            }
            .padding(.top, DS.Space.sm)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Widgets Grid

    private var widgetsGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DS.Space.md),
                    GridItem(.flexible(), spacing: DS.Space.md),
                    GridItem(.flexible(), spacing: DS.Space.md),
                ],
                spacing: DS.Space.md
            ) {
                ForEach(manager.widgets) { widget in
                    widgetCard(for: widget)
                        .aspectRatio(0.85, contentMode: .fit)
                        .opacity(draggedWidget?.id == widget.id ? 0.4 : 1.0)
                        .onDrag {
                            draggedWidget = widget
                            return NSItemProvider(object: widget.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: WidgetDropDelegate(
                            widget: widget,
                            manager: manager,
                            draggedWidget: $draggedWidget
                        ))
                        .contextMenu {
                            Button {
                                manager.beginRename(widget)
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                widgetPendingRemoval = widget
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }

                // Add widget button
                Button {
                    manager.beginAddWidget()
                } label: {
                    DashCard {
                        VStack(spacing: DS.Space.sm) {
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(DS.Color.textTertiary)
                            Text("Add Widget")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(DS.Color.textTertiary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .aspectRatio(0.85, contentMode: .fit)
            }
            .padding(.bottom, 100)
        }
    }

    @ViewBuilder
    private func widgetCard(for widget: HomeKitWidget) -> some View {
        let remove = { widgetPendingRemoval = widget }
        switch widget.type {
        case .lightDimmer:
            LightDimmerCard(widget: widget, manager: manager, onRemove: remove)
        case .thermostat:
            ThermostatCard(widget: widget, manager: manager, onRemove: remove)
        case .humidity:
            HumidityCard(widget: widget, manager: manager, onRemove: remove)
        case .garageDoor:
            GarageDoorCard(widget: widget, manager: manager, onRemove: remove)
        case .lock:
            LockCard(widget: widget, manager: manager, onRemove: remove)
        case .fan:
            FanCard(widget: widget, manager: manager, onRemove: remove)
        case .switchToggle, .outlet:
            SwitchCard(widget: widget, manager: manager, onRemove: remove)
        case .windowCovering, .door, .window:
            PositionCard(widget: widget, manager: manager, onRemove: remove)
        case .valve:
            ValveCard(widget: widget, manager: manager, onRemove: remove)
        case .securitySystem:
            SecuritySystemCard(widget: widget, manager: manager, onRemove: remove)
        case .speaker:
            SpeakerCard(widget: widget, manager: manager, onRemove: remove)
        case .temperatureSensor, .motionSensor, .contactSensor, .leakSensor,
             .airQualitySensor, .carbonMonoxideSensor, .carbonDioxideSensor,
             .occupancySensor, .lightSensor, .smokeSensor:
            SensorCard(widget: widget, manager: manager, onRemove: remove)
        }
    }
}

// MARK: - Light Dimmer Card

struct LightDimmerCard: View {
    let widget: HomeKitWidget
    @ObservedObject var manager: HomeKitManager
    var onRemove: (() -> Void)?

    private var light: LightAccessory { widget.light }

    var body: some View {
        DashCard {
            VStack(spacing: DS.Space.md) {

                // Header: name + room + controls
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(widget.displayName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.Color.textSecondary)
                            .lineLimit(1)
                        Text(light.roomName)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(DS.Color.textTertiary)
                    }
                    Spacer()

                    // Remove button
                    if let onRemove {
                        Button {
                            withAnimation(DS.Animation.snappy) {
                                onRemove()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(DS.Color.textTertiary)
                                .padding(6)
                                .background(DS.Color.surfaceRaised)
                                .clipShape(Circle())
                        }
                    }

                    // Power toggle
                    Button {
                        withAnimation(DS.Animation.snappy) {
                            if light.isGroup {
                                manager.togglePowerForGroupLight(light: light)
                            } else {
                                manager.togglePower(for: light)
                            }
                        }
                    } label: {
                        Image(systemName: "power")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(light.isOn ? DS.Color.accentAmber : DS.Color.textTertiary)
                            .padding(8)
                            .background(
                                light.isOn ? DS.Color.accentAmber.opacity(0.15) : DS.Color.surfaceRaised
                            )
                            .clipShape(Circle())
                    }
                }

                // Dimmer bar + brightness label below
                VStack(spacing: DS.Space.sm) {
                    DimmerBar(
                        brightness: light.brightness,
                        isOn: light.isOn,
                        isStale: light.isStale,
                        onBrightnessDragged: { newValue in
                            manager.setBrightnessLocally(for: light, value: newValue)
                        },
                        onBrightnessCommitted: { newValue in
                            manager.commitBrightness(for: light, value: newValue)
                        }
                    )

                    // Brightness label below
                    VStack(spacing: 0) {
                        Text(light.isOn ? "\(light.brightness)%" : "—")
                            .font(.system(size: 28, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(
                                light.isOn ? DS.Color.accentAmber : DS.Color.textTertiary
                            )
                        Text(light.isOn ? "" : "Off")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(
                                light.isOn ? DS.Color.accentAmber.opacity(0.6) : DS.Color.textTertiary
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Thermostat Card

struct ThermostatCard: View {
    let widget: HomeKitWidget
    @ObservedObject var manager: HomeKitManager
    var onRemove: (() -> Void)?

    private var thermostat: ThermostatAccessory? { widget.thermostat }

    var body: some View {
        DashCard {
            VStack(spacing: DS.Space.sm) {

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(widget.displayName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.Color.textSecondary)
                            .lineLimit(1)
                        Text(thermostat?.roomName ?? "")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(DS.Color.textTertiary)
                    }
                    Spacer()

                    if let onRemove {
                        Button {
                            withAnimation(DS.Animation.snappy) { onRemove() }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(DS.Color.textTertiary)
                                .padding(6)
                                .background(DS.Color.surfaceRaised)
                                .clipShape(Circle())
                        }
                    }
                }

                if let thermo = thermostat {
                    if thermo.isStale {
                        Spacer()
                        ProgressView()
                            .tint(DS.Color.accentBlue)
                        Spacer()
                    } else {
                        // Current temperature (large)
                        VStack(spacing: 2) {
                            Text(thermo.displayCurrentTemp() + "°")
                                .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(thermo.currentMode.accent)

                            Text(thermo.currentMode == .off ? "Off" : thermo.currentMode.displayName)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(thermo.currentMode.accent)
                        }

                        Spacer()

                        // Target temperature + mode controls
                        HStack(spacing: DS.Space.sm) {
                            // Decrease target
                            Button {
                                let newTarget = thermo.targetTemperature - 0.5
                                manager.setTargetTemperature(for: thermo, celsius: newTarget)
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(DS.Color.textSecondary)
                                    .frame(width: 32, height: 32)
                                    .background(DS.Color.surfaceRaised)
                                    .clipShape(Circle())
                            }

                            // Target label
                            VStack(spacing: 0) {
                                Text(thermo.displayTargetTemp() + "°")
                                    .font(.system(size: 20, weight: .medium, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(DS.Color.textPrimary)
                                Text("Target")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(DS.Color.textTertiary)
                            }
                            .frame(minWidth: 50)

                            // Increase target
                            Button {
                                let newTarget = thermo.targetTemperature + 0.5
                                manager.setTargetTemperature(for: thermo, celsius: newTarget)
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(DS.Color.textSecondary)
                                    .frame(width: 32, height: 32)
                                    .background(DS.Color.surfaceRaised)
                                    .clipShape(Circle())
                            }
                        }

                        // Mode buttons
                        HStack(spacing: DS.Space.xs) {
                            ForEach([ThermostatMode.off, .heat, .cool, .auto], id: \.rawValue) { mode in
                                Button {
                                    manager.setTargetMode(for: thermo, mode: mode)
                                } label: {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(thermo.targetMode == mode ? mode.accent : DS.Color.textTertiary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            thermo.targetMode == mode
                                            ? mode.accent.opacity(0.15)
                                            : DS.Color.surfaceRaised
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                                }
                            }
                        }
                    }
                } else {
                    Spacer()
                    Text("No thermostat")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(DS.Color.textTertiary)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Humidity Card

struct HumidityCard: View {
    let widget: HomeKitWidget
    @ObservedObject var manager: HomeKitManager
    var onRemove: (() -> Void)?

    var body: some View {
        DashCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(widget.displayName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.Color.textSecondary)
                            .lineLimit(1)
                        Text("All Sensors")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(DS.Color.textTertiary)
                    }
                    Spacer()

                    if let onRemove {
                        Button {
                            withAnimation(DS.Animation.snappy) { onRemove() }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(DS.Color.textTertiary)
                                .padding(6)
                                .background(DS.Color.surfaceRaised)
                                .clipShape(Circle())
                        }
                    }
                }

                if manager.availableHumiditySensors.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "humidity")
                                .font(.system(size: 28, weight: .thin))
                                .foregroundColor(DS.Color.textTertiary)
                            Text("No sensors")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(DS.Color.textTertiary)
                        }
                        Spacer()
                    }
                    Spacer()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: DS.Space.xs) {
                            ForEach(manager.humiditySensorsGroupedByRoom, id: \.room) { group in
                                // Room header
                                Text(group.room.uppercased())
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(DS.Color.textTertiary)
                                    .padding(.top, 2)

                                ForEach(group.sensors) { sensor in
                                    HStack(spacing: DS.Space.xs) {
                                        Image(systemName: "humidity.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(DS.Color.accentMint)

                                        Text(sensor.name)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(DS.Color.textSecondary)
                                            .lineLimit(1)

                                        Spacer()

                                        if sensor.isStale {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .tint(DS.Color.textTertiary)
                                        } else {
                                            Text(sensor.displayHumidity + "%")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .monospacedDigit()
                                                .foregroundColor(DS.Color.accentMint)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Dimmer Bar

struct DimmerBar: View {
    var brightness: Int
    var isOn: Bool
    var isStale: Bool
    var onBrightnessDragged: (Int) -> Void
    var onBrightnessCommitted: (Int) -> Void

    @State private var isDragging = false
    @State private var dragBrightness: Int = 0
    @State private var shimmerPhase: CGFloat = 0

    private let barWidth: CGFloat = 64
    private let barHeight: CGFloat = 200
    private let cornerRadius: CGFloat = 8
    private var displayBrightness: Int { isDragging ? dragBrightness : brightness }
    private var progress: Double { Double(displayBrightness) / 100.0 }
    private let accent = DS.Color.accentAmber

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let fillHeight = isOn ? height * CGFloat(max(0.02, progress)) : 0

            ZStack(alignment: .bottom) {
                // Track background
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DS.Color.surfaceRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(DS.Color.border, lineWidth: 1)
                    )

                if isStale {
                    // Shimmer loading state
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DS.Color.textTertiary.opacity(0.05),
                                    DS.Color.textTertiary.opacity(0.15),
                                    DS.Color.textTertiary.opacity(0.05),
                                ],
                                startPoint: UnitPoint(x: 0.5, y: shimmerPhase - 0.3),
                                endPoint: UnitPoint(x: 0.5, y: shimmerPhase + 0.3)
                            )
                        )
                        .onAppear {
                            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                                shimmerPhase = 1.3
                            }
                        }
                } else {
                    // Fill with gradient (bright at top, dark at bottom)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isOn
                                    ? [accent, accent.opacity(0.25)]
                                    : [DS.Color.textTertiary.opacity(0.3), DS.Color.textTertiary.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: fillHeight)
                        .animation(isDragging ? nil : DS.Animation.smooth, value: progress)

                    // Glow overlay when on
                    if isOn && displayBrightness > 0 {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(accent.opacity(0.15 * progress))
                            .frame(height: fillHeight)
                            .blur(radius: 8)
                            .animation(isDragging ? nil : DS.Animation.smooth, value: progress)
                    }
                }

                // Lightbulb icon centered
                VStack {
                    Spacer()
                    if isStale {
                        ProgressView()
                            .tint(DS.Color.textTertiary)
                    } else {
                        Image(systemName: isOn ? "lightbulb.fill" : "lightbulb")
                            .font(.system(size: 24, weight: .thin))
                            .foregroundColor(
                                isOn ? accent.opacity(0.5 + 0.5 * progress) : DS.Color.textTertiary
                            )
                            .shadow(
                                color: isOn ? accent.opacity(0.3 * progress) : .clear,
                                radius: 8
                            )
                    }
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isOn, !isStale else { return }
                        isDragging = true
                        let fraction = 1.0 - (value.location.y / height)
                        let clamped = min(1.0, max(0.01, fraction))
                        dragBrightness = Int(clamped * 100)
                        // Update UI only — no HomeKit write
                        onBrightnessDragged(dragBrightness)
                    }
                    .onEnded { _ in
                        let finalValue = dragBrightness
                        isDragging = false
                        // Commit to HomeKit on finger lift
                        onBrightnessCommitted(finalValue)
                    }
            )
        }
        .frame(width: barWidth, height: barHeight)
    }
}

// MARK: - Widget Drop Delegate

struct WidgetDropDelegate: DropDelegate {
    let widget: HomeKitWidget
    let manager: HomeKitManager
    @Binding var draggedWidget: HomeKitWidget?

    func performDrop(info: DropInfo) -> Bool {
        draggedWidget = nil
        manager.saveState()
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedWidget,
              dragged.id != widget.id,
              let fromIndex = manager.widgets.firstIndex(where: { $0.id == dragged.id }),
              let toIndex = manager.widgets.firstIndex(where: { $0.id == widget.id })
        else { return }

        withAnimation(DS.Animation.snappy) {
            manager.widgets.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Widget Type Picker Sheet

struct WidgetTypePickerSheet: View {
    @ObservedObject var manager: HomeKitManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                DS.Color.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DS.Space.lg) {
                        ForEach(HomeKitWidgetType.groupedByCategory, id: \.category) { group in
                            VStack(alignment: .leading, spacing: DS.Space.sm) {
                                Text(group.category.rawValue)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(DS.Color.textSecondary)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 4)

                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: DS.Space.md),
                                        GridItem(.flexible(), spacing: DS.Space.md),
                                    ],
                                    spacing: DS.Space.md
                                ) {
                                    ForEach(group.types) { type in
                                        Button {
                                            manager.selectWidgetType(type)
                                        } label: {
                                            widgetTypeCard(type)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(DS.Space.lg)
                }
            }
            .navigationTitle("Add Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DS.Color.textSecondary)
                }
            }
        }
    }

    private func widgetTypeCard(_ type: HomeKitWidgetType) -> some View {
        VStack(spacing: DS.Space.md) {
            Image(systemName: type.icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(type.accent)
                .shadow(color: type.accent.opacity(0.3), radius: 12)

            VStack(spacing: 4) {
                Text(type.displayName)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.Color.textPrimary)

                Text(type.description)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Space.xl)
        .padding(.horizontal, DS.Space.md)
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Color.border, lineWidth: 1)
        )
    }
}

// MARK: - Accessory Picker Sheet

struct AccessoryPickerSheet: View {
    @ObservedObject var manager: HomeKitManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var pickingType: HomeKitWidgetType? { manager.pendingWidgetType }

    // Generic accessory list for the current pending type
    private var accessoryItems: [AccessoryItem] {
        guard let type = pickingType else { return [] }
        switch type {
        case .lightDimmer:
            return manager.unaddedLights.map { AccessoryItem(id: $0.id, name: $0.name, room: $0.roomName, icon: $0.iconName, isGroup: $0.isGroup, accent: DS.Color.accentAmber) }
        case .thermostat:
            return manager.unaddedThermostats.map { AccessoryItem(id: $0.id, name: $0.name, room: $0.roomName, icon: "thermometer.medium", accent: DS.Color.accentBlue) }
        case .humidity:
            return []
        case .garageDoor:
            return manager.unaddedGarageDoors.map { AccessoryItem(id: $0.id, name: $0.name, room: $0.roomName, icon: "door.garage.closed", accent: DS.Color.danger) }
        case .lock:
            return manager.unaddedLocks.map { AccessoryItem(id: $0.id, name: $0.name, room: $0.roomName, icon: "lock.fill", accent: DS.Color.accentPurple) }
        case .fan:
            return manager.unaddedFans.map { AccessoryItem(id: $0.id, name: $0.name, room: $0.roomName, icon: "fan.fill", accent: DS.Color.accentGreen) }
        case .switchToggle:
            return manager.unaddedSwitches.filter { $0.kind == .toggle }.map { AccessoryItem(id: $0.id, name: $0.name, room: $0.roomName, icon: "switch.2", accent: DS.Color.accentAmber) }
        case .outlet:
            return manager.unaddedSwitches.filter { $0.kind == .outlet }.map { AccessoryItem(id: $0.id, name: $0.name, room: $0.roomName, icon: "powerplug.fill", accent: DS.Color.accentAmber) }
        case .windowCovering:
            return manager.unaddedPositionDevices.filter { $0.kind == .windowCovering }.map { AccessoryItem(id: $0.id, name: $0.name, room: $0.roomName, icon: "blinds.vertical.closed", accent: DS.Color.accentIndigo) }
        case .door:
            return manager.unaddedPositionDevices.filter { $0.kind == .door }.map { AccessoryItem(id: $0.id, name: $0.name, room: $0.roomName, icon: "door.left.hand.closed", accent: DS.Color.accentIndigo) }
        case .window:
            return manager.unaddedPositionDevices.filter { $0.kind == .window }.map { AccessoryItem(id: $0.id, name: $0.name, room: $0.roomName, icon: "window.vertical.closed", accent: DS.Color.accentIndigo) }
        case .valve:
            return manager.unaddedValves.map { AccessoryItem(id: $0.id, name: $0.name, room: $0.roomName, icon: "spigot.fill", accent: DS.Color.accentGreen) }
        case .securitySystem:
            return manager.unaddedSecuritySystems.map { AccessoryItem(id: $0.id, name: $0.name, room: $0.roomName, icon: "shield.lefthalf.filled", accent: DS.Color.accentPurple) }
        case .speaker:
            return manager.unaddedSpeakers.map { AccessoryItem(id: $0.id, name: $0.name, room: $0.roomName, icon: "speaker.wave.2.fill", accent: DS.Color.accentBlue) }
        case .temperatureSensor, .motionSensor, .contactSensor, .leakSensor,
             .airQualitySensor, .carbonMonoxideSensor, .carbonDioxideSensor,
             .occupancySensor, .lightSensor, .smokeSensor:
            guard let sensorType = type.sensorType else { return [] }
            return manager.unaddedSensors(for: sensorType).map { AccessoryItem(id: $0.id, name: $0.name, room: $0.roomName, icon: sensorType.icon, accent: DS.Color.accentTeal) }
        }
    }

    private var filteredItems: [AccessoryItem] {
        guard !searchText.isEmpty else { return accessoryItems }
        return accessoryItems.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.room.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Special handling: lights get grouped by room
    private var filteredLightGroups: [(room: String, lights: [LightAccessory])] {
        let groups = manager.unaddedLightsGroupedByRoom
        guard !searchText.isEmpty else { return groups }
        return groups.compactMap { group in
            let filtered = group.lights.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.roomName.localizedCaseInsensitiveContains(searchText)
            }
            return filtered.isEmpty ? nil : (room: group.room, lights: filtered)
        }
    }

    private var hasResults: Bool {
        if pickingType == .lightDimmer { return !filteredLightGroups.isEmpty }
        return !filteredItems.isEmpty
    }

    private var isEmpty: Bool { accessoryItems.isEmpty }

    var body: some View {
        NavigationView {
            ZStack {
                DS.Color.background.ignoresSafeArea()

                if isEmpty {
                    VStack(spacing: DS.Space.md) {
                        Spacer()
                        Image(systemName: pickingType?.icon ?? "questionmark")
                            .font(.system(size: 48, weight: .thin))
                            .foregroundColor((pickingType?.accent ?? DS.Color.accentAmber).opacity(0.5))
                        Text("No Available \(pickingType?.displayName ?? "Accessories")")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.Color.textPrimary)
                        Text("No matching devices were found, or all have been added.")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(DS.Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Space.xl)
                        Spacer()
                    }
                } else {
                    VStack(spacing: 0) {
                        // Search bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(DS.Color.textTertiary)
                            TextField("Search...", text: $searchText)
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(DS.Color.textPrimary)
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(DS.Color.textTertiary)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(DS.Color.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        .padding(.horizontal, DS.Space.lg)
                        .padding(.top, DS.Space.sm)
                        .padding(.bottom, DS.Space.sm)

                        if hasResults {
                            ScrollView {
                                if pickingType == .lightDimmer {
                                    lightList
                                } else {
                                    genericList
                                }
                            }
                        } else {
                            VStack(spacing: DS.Space.md) {
                                Spacer()
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 36, weight: .thin))
                                    .foregroundColor(DS.Color.textTertiary)
                                Text("No results for \"\(searchText)\"")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(DS.Color.textSecondary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Choose \(pickingType?.displayName ?? "Accessory")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        manager.pendingWidgetType = nil
                        dismiss()
                    }
                    .foregroundColor(DS.Color.textSecondary)
                }
            }
        }
    }

    // MARK: - Light List (grouped by room)

    private var lightList: some View {
        LazyVStack(spacing: DS.Space.md, pinnedViews: .sectionHeaders) {
            ForEach(filteredLightGroups, id: \.room) { group in
                Section {
                    ForEach(group.lights) { light in
                        Button {
                            withAnimation(DS.Animation.snappy) {
                                manager.addWidget(for: light)
                            }
                        } label: {
                            accessoryRow(name: light.name, room: light.roomName, icon: light.iconName, isGroup: light.isGroup, accent: DS.Color.accentAmber)
                        }
                    }
                } header: {
                    roomHeader(group.room)
                }
            }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.bottom, DS.Space.xl)
    }

    // MARK: - Generic Accessory List

    private var genericList: some View {
        LazyVStack(spacing: DS.Space.md) {
            ForEach(filteredItems) { item in
                Button {
                    withAnimation(DS.Animation.snappy) {
                        addAccessory(item)
                    }
                } label: {
                    accessoryRow(name: item.name, room: item.room, icon: item.icon, isGroup: item.isGroup, accent: item.accent)
                }
            }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.bottom, DS.Space.xl)
    }

    // MARK: - Add Accessory by Type

    private func addAccessory(_ item: AccessoryItem) {
        guard let type = pickingType else { return }
        switch type {
        case .thermostat:
            if let acc = manager.unaddedThermostats.first(where: { $0.id == item.id }) {
                manager.addThermostatWidget(for: acc)
            }
        case .garageDoor:
            if let acc = manager.unaddedGarageDoors.first(where: { $0.id == item.id }) {
                manager.addGarageDoorWidget(for: acc)
            }
        case .lock:
            if let acc = manager.unaddedLocks.first(where: { $0.id == item.id }) {
                manager.addLockWidget(for: acc)
            }
        case .fan:
            if let acc = manager.unaddedFans.first(where: { $0.id == item.id }) {
                manager.addFanWidget(for: acc)
            }
        case .switchToggle:
            if let acc = manager.unaddedSwitches.first(where: { $0.id == item.id && $0.kind == .toggle }) {
                manager.addSwitchWidget(for: acc)
            }
        case .outlet:
            if let acc = manager.unaddedSwitches.first(where: { $0.id == item.id && $0.kind == .outlet }) {
                manager.addSwitchWidget(for: acc)
            }
        case .windowCovering:
            if let acc = manager.unaddedPositionDevices.first(where: { $0.id == item.id && $0.kind == .windowCovering }) {
                manager.addPositionWidget(for: acc)
            }
        case .door:
            if let acc = manager.unaddedPositionDevices.first(where: { $0.id == item.id && $0.kind == .door }) {
                manager.addPositionWidget(for: acc)
            }
        case .window:
            if let acc = manager.unaddedPositionDevices.first(where: { $0.id == item.id && $0.kind == .window }) {
                manager.addPositionWidget(for: acc)
            }
        case .valve:
            if let acc = manager.unaddedValves.first(where: { $0.id == item.id }) {
                manager.addValveWidget(for: acc)
            }
        case .securitySystem:
            if let acc = manager.unaddedSecuritySystems.first(where: { $0.id == item.id }) {
                manager.addSecuritySystemWidget(for: acc)
            }
        case .speaker:
            if let acc = manager.unaddedSpeakers.first(where: { $0.id == item.id }) {
                manager.addSpeakerWidget(for: acc)
            }
        case .temperatureSensor, .motionSensor, .contactSensor, .leakSensor,
             .airQualitySensor, .carbonMonoxideSensor, .carbonDioxideSensor,
             .occupancySensor, .lightSensor, .smokeSensor:
            if let acc = manager.availableSensors.first(where: { $0.id == item.id }) {
                manager.addSensorWidget(for: acc)
            }
        case .humidity, .lightDimmer:
            break // Handled by lightList
        }
    }

    // MARK: - Shared Components

    private func roomHeader(_ room: String) -> some View {
        HStack {
            Text(room)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(DS.Color.textSecondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(DS.Color.background)
    }

    private func accessoryRow(name: String, room: String, icon: String, isGroup: Bool, accent: Color) -> some View {
        HStack(spacing: DS.Space.md) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.Color.textPrimary)
                    if isGroup {
                        Text("Group")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text(room)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(DS.Color.textSecondary)
            }

            Spacer()

            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(accent)
        }
        .padding(DS.Space.md)
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Color.border, lineWidth: 1)
        )
    }
}

// MARK: - Accessory Item (for generic picker)

private struct AccessoryItem: Identifiable {
    let id: UUID
    let name: String
    let room: String
    let icon: String
    var isGroup: Bool = false
    let accent: Color
}
