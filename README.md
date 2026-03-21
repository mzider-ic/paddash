# PadDash

A fullscreen SwiftUI dashboard app for iPad, targeting iPadOS 16.0+.
Modular panel architecture: Timer → HomeKit → AirPlay.

---

## Quick Start

1. Open `PadDash.xcodeproj` in Xcode 15+
2. Select your iPad as the run destination (or iPad simulator)
3. Set your Development Team in **Signing & Capabilities**
4. Update `PRODUCT_BUNDLE_IDENTIFIER` if needed (e.g. `com.yourname.paddash`)
5. ▶ Run

No Swift Package dependencies — zero external libraries required.

---

## Project Structure

```
PadDash/
├── App/
│   ├── PadDashApp.swift          # @main entry, forces dark mode
│   └── ContentView.swift         # Root layout: header + tab content + floating tab bar
│
├── DesignSystem/
│   └── DesignSystem.swift        # DS enum: colors, radius, spacing, animation tokens
│                                 # DashCard reusable surface component
│
├── Modules/
│   ├── Timer/
│   │   ├── TimerViewModel.swift  # DashTimer model, TimerSlotVM, DashboardVM
│   │   ├── ArcRing.swift         # Animated circular progress ring
│   │   ├── TimerCard.swift       # Full timer card UI
│   │   └── DurationPickerSheet.swift  # Wheel picker + quick presets sheet
│   │
│   └── Placeholders.swift        # HomeKit + AirPlay stub cards
│
└── Assets.xcassets/
```

---

## Timer Module — Features

- **3 independent timers** running simultaneously
- **Animated arc ring** — smooth fill, urgent red glow at ≤10 s
- **Quick presets** — 1 min through 1 hr, one tap to set
- **Custom duration** — wheel picker for hours / minutes / seconds
- **Play / Pause / Reset** controls per timer
- **Haptic feedback** — warning at 10 s, success chime on finish
- **System sound** on completion (AudioToolbox chime 1005)

---

## Adding the HomeKit Module (next steps)

1. Add `HomeKit` capability in Xcode → Signing & Capabilities
2. Add `NSHomeKitUsageDescription` to Info.plist
3. Create `HomeKitViewModel.swift` using `HMHomeManager`
4. Replace `HomeKitPlaceholderView` in `ContentView.swift` with your real view

```swift
// Minimal HomeKit setup
import HomeKit

@MainActor
final class HomeKitVM: NSObject, ObservableObject, HMHomeManagerDelegate {
    private let manager = HMHomeManager()
    @Published var accessories: [HMAccessory] = []

    override init() {
        super.init()
        manager.delegate = self
    }

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        accessories = manager.primaryHome?.accessories ?? []
    }
}
```

---

## Adding the AirPlay / Music Module (next steps)

1. Add `MusicKit` capability + `NSAppleMusicUsageDescription`
2. Use `AVRoutePickerView` (UIViewRepresentable) for the built-in AirPlay picker
3. Use `MusicKit` (`MusicLibrary`, `ApplicationMusicPlayer`) for playlist control

```swift
// AirPlay route picker (drop-in SwiftUI wrapper)
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.tintColor = UIColor(DS.Color.accentMint)
        return v
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
```

---

## Deployment Notes

- `TARGETED_DEVICE_FAMILY = 2` → iPad only
- `IPHONEOS_DEPLOYMENT_TARGET = 16.0` — works on iPadOS 16.7.x
- Supports all four iPad orientations
- No Mac Catalyst
- Forced dark mode in `PadDashApp.swift` (`.preferredColorScheme(.dark)`)
  Remove that line if you want to respect system appearance.
