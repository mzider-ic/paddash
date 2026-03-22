import ProjectDescription

let project = Project(
    name: "PadDash",
    settings: .settings(
        base: [
            "SWIFT_VERSION": "5.9",
            "MARKETING_VERSION": "1.0",
            "CURRENT_PROJECT_VERSION": "1",
            "CODE_SIGN_STYLE": "Automatic",
        ]
    ),
    targets: [
        .target(
            name: "PadDash",
            destinations: [.iPad],
            product: .app,
            bundleId: "com.msz.PadDash",
            deploymentTargets: .iOS("16.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": .dictionary([:]),
                "UIApplicationSupportsIndirectInputEvents": .boolean(true),
                "UISupportedInterfaceOrientations~ipad": .array([
                    .string("UIInterfaceOrientationPortrait"),
                    .string("UIInterfaceOrientationPortraitUpsideDown"),
                    .string("UIInterfaceOrientationLandscapeLeft"),
                    .string("UIInterfaceOrientationLandscapeRight"),
                ]),
                "NSHomeKitUsageDescription": .string("PadDash needs HomeKit access to control your lights and other accessories."),
                "NSAppleMusicUsageDescription": .string("PadDash needs access to your Apple Music library to play your playlists."),
                "UIBackgroundModes": .array([.string("audio")]),
            ]),
            sources: ["PadDash/**/*.swift"],
            resources: ["PadDash/Assets.xcassets"],
            entitlements: .file(path: "PadDash/PadDash.entitlements")
        ),
    ]
)
