import SwiftUI

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
