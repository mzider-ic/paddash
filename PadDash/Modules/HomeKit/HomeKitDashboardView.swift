import SwiftUI

// MARK: - HomeKit Dashboard View

struct HomeKitDashboardView: View {
    @ObservedObject var manager: HomeKitManager

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
                } else if manager.widgets.isEmpty && manager.availableLights.isEmpty {
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

            // Add widget button in empty state
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
                    LightDimmerCard(
                        light: widget.light,
                        manager: manager,
                        onRemove: { manager.removeWidget(widget) }
                    )
                    .aspectRatio(0.85, contentMode: .fit)
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
}

// MARK: - Light Dimmer Card

struct LightDimmerCard: View {
    let light: LightAccessory
    @ObservedObject var manager: HomeKitManager
    var onRemove: (() -> Void)?

    var body: some View {
        DashCard {
            VStack(spacing: DS.Space.md) {

                // Header: name + room + controls
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(light.name)
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

// MARK: - Widget Type Picker Sheet

struct WidgetTypePickerSheet: View {
    @ObservedObject var manager: HomeKitManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                DS.Color.background.ignoresSafeArea()

                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: DS.Space.md),
                            GridItem(.flexible(), spacing: DS.Space.md),
                        ],
                        spacing: DS.Space.md
                    ) {
                        ForEach(HomeKitWidgetType.allCases) { type in
                            Button {
                                manager.selectWidgetType(type)
                            } label: {
                                widgetTypeCard(type)
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

    private var filteredGroups: [(room: String, lights: [LightAccessory])] {
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
        !filteredGroups.isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                DS.Color.background.ignoresSafeArea()

                if manager.unaddedLights.isEmpty {
                    VStack(spacing: DS.Space.md) {
                        Spacer()
                        Image(systemName: "lightbulb.slash")
                            .font(.system(size: 48, weight: .thin))
                            .foregroundColor(DS.Color.accentAmber.opacity(0.5))
                        Text("No Available Lights")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.Color.textPrimary)
                        Text("All discovered lights have already been added as widgets, or no lights were found in this home.")
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
                            TextField("Search lights...", text: $searchText)
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
                                LazyVStack(spacing: DS.Space.md, pinnedViews: .sectionHeaders) {
                                    ForEach(filteredGroups, id: \.room) { group in
                                        Section {
                                            ForEach(group.lights) { light in
                                                Button {
                                                    withAnimation(DS.Animation.snappy) {
                                                        manager.addWidget(for: light)
                                                    }
                                                } label: {
                                                    accessoryRow(light)
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
            .navigationTitle("Choose a Light")
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

    private func accessoryRow(_ light: LightAccessory) -> some View {
        HStack(spacing: DS.Space.md) {
            Image(systemName: light.iconName)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(DS.Color.accentAmber)
                .frame(width: 44, height: 44)
                .background(DS.Color.accentAmber.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(light.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.Color.textPrimary)
                    if light.isGroup {
                        Text("Group")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(DS.Color.accentAmber)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DS.Color.accentAmber.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text(light.roomName)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(DS.Color.textSecondary)
            }

            Spacer()

            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(DS.Color.accentAmber)
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
