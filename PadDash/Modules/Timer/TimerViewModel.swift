import SwiftUI
import Combine
import AudioToolbox
import UserNotifications

// MARK: - Timer State

enum TimerState {
    case idle, running, paused, finished
}

// MARK: - Timer Model

struct DashTimer: Identifiable {
    let id: UUID
    var label: String
    var totalSeconds: Int          // configured duration
    var remainingSeconds: Int      // live countdown
    var state: TimerState
    var accent: Color

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(remainingSeconds) / Double(totalSeconds)
    }

    var isUrgent: Bool {
        remainingSeconds <= 10 && state == .running
    }

    var formattedTime: String {
        let h = remainingSeconds / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    // Presets (in seconds)
    static let presets: [(label: String, seconds: Int)] = [
        ("1 min",   60),
        ("3 min",  180),
        ("5 min",  300),
        ("10 min", 600),
        ("15 min", 900),
        ("20 min", 1200),
        ("25 min", 1500),
        ("30 min", 1800),
        ("45 min", 2700),
        ("1 hr",   3600),
    ]
}

// MARK: - Timer Slot ViewModel

@MainActor
final class TimerSlotVM: ObservableObject, Identifiable {
    let id: UUID
    let accent: Color

    @Published var timer: DashTimer
    @Published var isEditingDuration: Bool = false
    @Published var showFinishedAlert: Bool = false
    @Published var pickerHours: Int = 0
    @Published var pickerMinutes: Int = 5
    @Published var pickerSeconds: Int = 0

    private var cancellable: AnyCancellable?
    private var tickPublisher = Timer.publish(every: 1, on: .main, in: .common)

    init(id: UUID = UUID(), label: String, accent: Color) {
        self.id = id
        self.accent = accent
        self.timer = DashTimer(
            id: id,
            label: label,
            totalSeconds: 30,
            remainingSeconds: 30,
            state: .idle,
            accent: accent
        )
    }

    // MARK: - Controls

    func start() {
        guard timer.state != .running else { return }
        if timer.state == .finished || timer.remainingSeconds == 0 {
            reset()
        }
        stopAlarm()
        timer.state = .running
        startTick()
    }

    func pause() {
        timer.state = .paused
        stopTick()
    }

    func reset() {
        stopTick()
        stopAlarm()
        timer.remainingSeconds = timer.totalSeconds
        timer.state = .idle
    }

    func applyPickerDuration() {
        let total = pickerHours * 3600 + pickerMinutes * 60 + pickerSeconds
        guard total > 0 else { return }
        timer.totalSeconds = total
        timer.remainingSeconds = total
        timer.state = .idle
        stopTick()
        isEditingDuration = false
    }

    func applyPreset(seconds: Int) {
        timer.totalSeconds = seconds
        timer.remainingSeconds = seconds
        timer.state = .idle
        stopTick()
        // Sync picker
        pickerHours   = seconds / 3600
        pickerMinutes = (seconds % 3600) / 60
        pickerSeconds = seconds % 60
    }

    // MARK: - Tick

    private func startTick() {
        let pub = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        cancellable = pub.sink { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tick() }
        }
    }

    private func stopTick() {
        cancellable?.cancel()
        cancellable = nil
    }

    private func tick() {
        guard timer.state == .running else { return }
        if timer.remainingSeconds > 0 {
            timer.remainingSeconds -= 1
            if timer.remainingSeconds == 10 {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        } else {
            timer.state = .finished
            showFinishedAlert = true
            stopTick()
            playTimerAlarm()
            sendFinishedNotification()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Alarm Sound

    private var alarmCancellable: AnyCancellable?

    /// Plays a repeating alert sound similar to the iOS timer alarm.
    private func playTimerAlarm() {
        // Play the first chime immediately
        AudioServicesPlayAlertSound(SystemSoundID(1005))

        // Repeat the alert every 2 seconds until the user interacts
        let pub = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
        alarmCancellable = pub.sink { [weak self] _ in
            guard let self, self.timer.state == .finished else {
                self?.alarmCancellable?.cancel()
                self?.alarmCancellable = nil
                return
            }
            AudioServicesPlayAlertSound(SystemSoundID(1005))
        }
    }

    func stopAlarm() {
        alarmCancellable?.cancel()
        alarmCancellable = nil
    }

    func dismissAlert() {
        showFinishedAlert = false
        stopAlarm()
    }

    func repeatTimer() {
        showFinishedAlert = false
        reset()
        start()
    }

    // MARK: - Local Notification

    private func sendFinishedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Timer Done"
        content.body = "\(timer.label) has finished."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: id.uuidString,
            content: content,
            trigger: nil // fire immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Dashboard ViewModel

@MainActor
final class DashboardVM: ObservableObject {
    @Published var slots: [TimerSlotVM]
    @Published var alertingSlots: [TimerSlotVM] = []

    private var slotCancellables: [UUID: AnyCancellable] = [:]

    private static let accentCycle: [Color] = [
        DS.Color.accentBlue,
        DS.Color.accentMint,
        DS.Color.accentAmber,
    ]

    init() {
        let first = TimerSlotVM(label: "Timer 1", accent: Self.accentCycle[0])
        slots = [first]
        observeSlot(first)
    }

    private func observeSlot(_ slot: TimerSlotVM) {
        slotCancellables[slot.id] = slot.$showFinishedAlert.sink { [weak self] showing in
            guard let self else { return }
            if showing {
                if !self.alertingSlots.contains(where: { $0.id == slot.id }) {
                    self.alertingSlots.append(slot)
                }
            } else {
                self.alertingSlots.removeAll { $0.id == slot.id }
            }
        }
    }

    private func removeSlotObserver(_ slot: TimerSlotVM) {
        slotCancellables.removeValue(forKey: slot.id)
    }

    func addTimer() {
        let index = slots.count
        let accent = Self.accentCycle[index % Self.accentCycle.count]
        let newSlot = TimerSlotVM(label: "Timer \(index + 1)", accent: accent)

        // Inherit duration from the last timer
        if let last = slots.last {
            newSlot.applyPreset(seconds: last.timer.totalSeconds)
        }

        observeSlot(newSlot)
        withAnimation(DS.Animation.snappy) {
            slots.append(newSlot)
        }
    }

    func removeTimer(_ slot: TimerSlotVM) {
        guard slots.count > 1 else { return }
        slot.reset()
        removeSlotObserver(slot)
        withAnimation(DS.Animation.snappy) {
            slots.removeAll { $0.id == slot.id }
        }
    }
}
