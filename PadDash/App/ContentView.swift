import SwiftUI

// MARK: - Dashboard Tab

enum DashTab: String, CaseIterable {
    case timers  = "Timers"
    case homekit = "HomeKit"
    case airplay = "AirPlay"

    var icon: String {
        switch self {
        case .timers:  return "timer"
        case .homekit: return "house.fill"
        case .airplay: return "airplayaudio"
        }
    }

    var accent: Color {
        switch self {
        case .timers:  return DS.Color.accentBlue
        case .homekit: return DS.Color.accentAmber
        case .airplay: return DS.Color.accentMint
        }
    }
}

// MARK: - Root Content View

struct ContentView: View {
    @StateObject private var dashVM = DashboardVM()
    @StateObject private var homeKitManager = HomeKitManager()
    @StateObject private var airPlayManager = AirPlayManager()
    @State private var activeTab: DashTab = .timers
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {

            // Background
            DS.Color.background
                .ignoresSafeArea()

            // Content
            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, DS.Space.lg)
                    .padding(.top, DS.Space.md)

                tabContent
                    .padding(.horizontal, DS.Space.lg)
                    .padding(.top, DS.Space.md)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer(minLength: 90) // room for tab bar
            }

            // Floating tab bar
            floatingTabBar
                .padding(.bottom, 24)
                .padding(.horizontal, DS.Space.xl)

            // Timer finished overlay
            if !dashVM.alertingSlots.isEmpty {
                TimerFinishedOverlay(alertingSlots: dashVM.alertingSlots)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .animation(DS.Animation.snappy, value: dashVM.alertingSlots.map(\.id))
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background || newPhase == .inactive {
                dashVM.saveSlots()
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PadDash")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Color.textPrimary)
                Text(activeTab.rawValue)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(activeTab.accent)
            }
            Spacer()

            // Clock
            LiveClockView()
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .timers:
            TimerDashboardView(vm: dashVM)
                .transition(.opacity.combined(with: .move(edge: .leading)))
        case .homekit:
            HomeKitDashboardView(manager: homeKitManager)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        case .airplay:
            AirPlayDashboardView(manager: airPlayManager)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }

    // MARK: - Floating Tab Bar

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            ForEach(DashTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(DS.Animation.snappy) { activeTab = tab }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: activeTab == tab ? .semibold : .regular))
                            .foregroundColor(
                                activeTab == tab ? tab.accent : DS.Color.textTertiary
                            )
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(
                                activeTab == tab ? tab.accent : DS.Color.textTertiary
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(DS.Color.surfaceRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .stroke(DS.Color.borderStrong, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 8)
        )
    }
}

// MARK: - Live Clock

struct LiveClockView: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()

    private static let ampmFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "a"
        return f
    }()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(Self.timeFormatter.string(from: now))
                .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                .foregroundColor(DS.Color.textPrimary)
            Text(Self.ampmFormatter.string(from: now))
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(DS.Color.textSecondary)
        }
        .onReceive(timer) { now = $0 }
    }
}

// MARK: - Timer Dashboard

struct TimerDashboardView: View {
    @ObservedObject var vm: DashboardVM

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DS.Space.md),
                    GridItem(.flexible(), spacing: DS.Space.md),
                    GridItem(.flexible(), spacing: DS.Space.md),
                ],
                spacing: DS.Space.md
            ) {
                ForEach(vm.slots) { slot in
                    TimerCard(vm: slot, canRemove: vm.slots.count > 1) {
                        vm.removeTimer(slot)
                    }
                    .aspectRatio(0.85, contentMode: .fit)
                }

                // Add timer button
                Button {
                    vm.addTimer()
                } label: {
                    DashCard {
                        VStack(spacing: DS.Space.sm) {
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(DS.Color.textTertiary)
                            Text("Add Timer")
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
