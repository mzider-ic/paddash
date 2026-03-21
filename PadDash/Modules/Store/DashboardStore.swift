import SwiftUI

// MARK: - Persisted Widget Entry

/// A lightweight, Codable representation of any dashboard widget.
/// Stores just enough to re-hydrate the widget when the backing service
/// (HomeKit, timers, etc.) finishes loading.
struct PersistedWidgetEntry: Codable, Identifiable {
    let id: String           // Widget UUID string
    let kind: String         // Widget kind key (e.g. HomeKitWidgetType rawValue)
    let referenceID: String  // External object ID (e.g. HMService UUID, timer slot UUID)
    var customName: String?  // User-defined local rename (nil = use accessory name)
}

// MARK: - Persisted Timer Entry

struct PersistedTimerEntry: Codable {
    let label: String
    let totalSeconds: Int
    let accentIndex: Int
}

// MARK: - Dashboard Store

/// Unified persistence layer for all dashboard state.
/// Has no dependencies on HomeKit, UIKit, or any specific widget framework.
@MainActor
final class DashboardStore: ObservableObject {

    static let shared = DashboardStore()

    // MARK: Keys
    private enum Keys {
        static let homeKitWidgets = "Store.homeKitWidgets"
        static let selectedHomeID = "Store.selectedHomeID"
        static let timerSlots = "Store.timerSlots"
    }

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - HomeKit Widgets

    func saveHomeKitWidgets(_ entries: [PersistedWidgetEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Keys.homeKitWidgets)
        }
    }

    func loadHomeKitWidgets() -> [PersistedWidgetEntry] {
        guard let data = defaults.data(forKey: Keys.homeKitWidgets),
              let entries = try? JSONDecoder().decode([PersistedWidgetEntry].self, from: data) else {
            return []
        }
        return entries
    }

    // MARK: - Selected Home

    func saveSelectedHomeID(_ id: UUID) {
        defaults.set(id.uuidString, forKey: Keys.selectedHomeID)
    }

    func loadSelectedHomeID() -> UUID? {
        guard let str = defaults.string(forKey: Keys.selectedHomeID) else { return nil }
        return UUID(uuidString: str)
    }

    // MARK: - Timer Slots

    func saveTimerSlots(_ entries: [PersistedTimerEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Keys.timerSlots)
        }
    }

    func loadTimerSlots() -> [PersistedTimerEntry] {
        guard let data = defaults.data(forKey: Keys.timerSlots),
              let entries = try? JSONDecoder().decode([PersistedTimerEntry].self, from: data) else {
            return []
        }
        return entries
    }
}
