import SwiftUI
import UserNotifications
import AVFoundation

@main
struct PadDashApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                    requestNotificationPermission()
                    configureAudioSession()
                }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                policy: .longFormAudio
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio session configuration failed
        }
    }
}
