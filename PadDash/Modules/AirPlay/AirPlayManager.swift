import SwiftUI
import MusicKit
import Combine

// MARK: - AirPlay Manager

@MainActor
final class AirPlayManager: ObservableObject {

    // MARK: - Published State

    @Published var widgets: [AirPlayWidget] = []
    @Published var isAuthorized = false
    @Published var authorizationDenied = false

    // Playback state
    @Published var isPlaying = false
    @Published var currentTrackTitle: String?
    @Published var currentArtistName: String?
    @Published var currentArtwork: Artwork?
    @Published var currentPlaybackTime: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var activeWidgetID: UUID?

    // Shuffle & repeat state
    @Published var shuffleMode: MusicPlayer.ShuffleMode = .off
    @Published var repeatMode: MusicPlayer.RepeatMode = .none

    // Expanded view state
    @Published var expandedWidgetID: UUID?

    // Sheet state
    @Published var showPlaylistPicker = false
    @Published var availablePlaylists: [Playlist] = []
    @Published var isLoadingPlaylists = false

    // Rename state
    @Published var widgetBeingRenamed: AirPlayWidget?
    @Published var renameText: String = ""

    // MARK: - Private

    private let player = SystemMusicPlayer.shared
    private let store = DashboardStore.shared
    private var progressTimer: AnyCancellable?
    private var stateObserver: AnyCancellable?
    private var queueObserver: AnyCancellable?

    // MARK: - Init

    init() {
        let status = MusicAuthorization.currentStatus
        isAuthorized = (status == .authorized)
        authorizationDenied = (status == .denied)
        restoreWidgets()
        setupObservers()
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        isAuthorized = (status == .authorized)
        authorizationDenied = (status == .denied)
    }

    // MARK: - Playlist Discovery

    func fetchPlaylists() async {
        isLoadingPlaylists = true
        do {
            var request = MusicLibraryRequest<Playlist>()
            request.sort(by: \.lastPlayedDate, ascending: false)
            let response = try await request.response()
            availablePlaylists = Array(response.items)
        } catch {
            availablePlaylists = []
        }
        isLoadingPlaylists = false
    }

    // MARK: - Widget Management

    func beginAddWidget() {
        Task {
            if !isAuthorized {
                await requestAuthorization()
            }
            guard isAuthorized else { return }
            await fetchPlaylists()
            showPlaylistPicker = true
        }
    }

    func addWidget(for playlist: Playlist) {
        let widget = AirPlayWidget(
            id: UUID(),
            playlistID: playlist.id,
            playlistName: playlist.name
        )
        widgets.append(widget)
        showPlaylistPicker = false
        saveState()
    }

    func removeWidget(_ widget: AirPlayWidget) {
        if activeWidgetID == widget.id {
            stopPlayback()
        }
        if expandedWidgetID == widget.id {
            expandedWidgetID = nil
        }
        widgets.removeAll { $0.id == widget.id }
        saveState()
    }

    func moveWidget(from source: IndexSet, to destination: Int) {
        widgets.move(fromOffsets: source, toOffset: destination)
        saveState()
    }

    // MARK: - Widget Rename

    func beginRename(_ widget: AirPlayWidget) {
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

    // MARK: - Playback

    func playWidget(_ widget: AirPlayWidget) {
        Task {
            guard widgets.contains(where: { $0.id == widget.id }) else { return }

            do {
                // Fetch the playlist with its tracks from the user's library
                var request = MusicLibraryRequest<Playlist>()
                request.filter(matching: \.id, equalTo: widget.playlistID)
                let response = try await request.response()

                guard let playlist = response.items.first else { return }

                // Load the playlist's tracks so the queue is scoped to them
                let detailedPlaylist = try await playlist.with([.tracks])
                let tracks = detailedPlaylist.tracks ?? []
                guard !tracks.isEmpty else { return }

                // Set the queue to the playlist's tracks explicitly
                player.queue = SystemMusicPlayer.Queue(for: tracks)

                // Repeat the playlist so autoplay doesn't add unrelated songs
                player.state.repeatMode = .all

                try await player.play()

                activeWidgetID = widget.id
                isPlaying = true
                shuffleMode = player.state.shuffleMode ?? .off
                repeatMode = player.state.repeatMode ?? .none
                startProgressTracking()
                updateNowPlayingInfo()
            } catch {
                // Playback failed — could be no subscription, network, etc.
            }
        }
    }

    func togglePlayPause() {
        if player.state.playbackStatus == .playing {
            player.pause()
            isPlaying = false
            stopProgressTracking()
        } else {
            Task {
                try? await player.play()
                isPlaying = true
                startProgressTracking()
            }
        }
    }

    func skipForward() {
        Task {
            try? await player.skipToNextEntry()
            updateNowPlayingInfo()
        }
    }

    func skipBackward() {
        Task {
            try? await player.skipToPreviousEntry()
            updateNowPlayingInfo()
        }
    }

    func stopPlayback() {
        player.stop()
        isPlaying = false
        activeWidgetID = nil
        stopProgressTracking()
        clearNowPlayingInfo()
    }

    // MARK: - Shuffle & Repeat

    func toggleShuffle() {
        let newMode: MusicPlayer.ShuffleMode = (shuffleMode == .off) ? .songs : .off
        player.state.shuffleMode = newMode
        shuffleMode = newMode
    }

    /// Cycles: none → all → one → none
    func cycleRepeatMode() {
        let newMode: MusicPlayer.RepeatMode
        switch repeatMode {
        case .none:
            newMode = .all
        case .all:
            newMode = .one
        case .one:
            newMode = .none
        @unknown default:
            newMode = .none
        }
        player.state.repeatMode = newMode
        repeatMode = newMode
    }

    // MARK: - Expanded State

    func expandWidget(_ widget: AirPlayWidget) {
        withAnimation(DS.Animation.snappy) {
            expandedWidgetID = widget.id
        }
    }

    func collapseWidget() {
        withAnimation(DS.Animation.snappy) {
            expandedWidgetID = nil
        }
    }

    // MARK: - Progress Tracking

    private func startProgressTracking() {
        stopProgressTracking()
        progressTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updatePlaybackProgress()
                }
            }
    }

    private func stopProgressTracking() {
        progressTimer?.cancel()
        progressTimer = nil
    }

    private func updatePlaybackProgress() {
        let time = player.playbackTime
        guard !time.isNaN else { return }
        currentPlaybackTime = time
        updateNowPlayingInfo()
    }

    // MARK: - Player Observation

    private func setupObservers() {
        // Observe player state changes (play/pause/stop, shuffle, repeat)
        stateObserver = player.state.objectWillChange.sink { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                let playing = self.player.state.playbackStatus == .playing
                self.isPlaying = playing
                if playing {
                    self.startProgressTracking()
                } else {
                    self.stopProgressTracking()
                }
                self.shuffleMode = self.player.state.shuffleMode ?? .off
                self.repeatMode = self.player.state.repeatMode ?? .none
                self.updateNowPlayingInfo()
            }
        }

        // Observe queue changes (track changed)
        queueObserver = player.queue.objectWillChange.sink { [weak self] in
            Task { @MainActor in
                // Small delay to let the queue settle
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                self?.updateNowPlayingInfo()
            }
        }
    }

    private func updateNowPlayingInfo() {
        guard let entry = player.queue.currentEntry else {
            clearNowPlayingInfo()
            return
        }

        currentTrackTitle = entry.title
        currentArtistName = entry.subtitle
        currentArtwork = entry.artwork

        // Get duration from the song item if available
        if let item = entry.item {
            switch item {
            case .song(let song):
                totalDuration = song.duration ?? 0
            case .musicVideo(let video):
                totalDuration = video.duration ?? 0
            @unknown default:
                break
            }
        }

        // Propagate to the active widget
        if let widgetID = activeWidgetID,
           let index = widgets.firstIndex(where: { $0.id == widgetID }) {
            widgets[index].isPlaying = isPlaying
            widgets[index].currentTrackTitle = currentTrackTitle
            widgets[index].currentArtistName = currentArtistName
            widgets[index].currentArtwork = currentArtwork
            widgets[index].currentPlaybackTime = currentPlaybackTime
            widgets[index].totalDuration = totalDuration
        }
    }

    private func clearNowPlayingInfo() {
        currentTrackTitle = nil
        currentArtistName = nil
        currentArtwork = nil
        currentPlaybackTime = 0
        totalDuration = 0
    }

    // MARK: - Persistence

    func saveState() {
        let entries = widgets.map {
            PersistedAirPlayEntry(
                id: $0.id.uuidString,
                playlistID: $0.playlistID.rawValue,
                playlistName: $0.playlistName,
                customName: $0.customName
            )
        }
        store.saveAirPlayWidgets(entries)
    }

    func restoreWidgets() {
        let entries = store.loadAirPlayWidgets()
        widgets = entries.compactMap { entry -> AirPlayWidget? in
            guard let widgetID = UUID(uuidString: entry.id) else { return nil }
            return AirPlayWidget(
                id: widgetID,
                playlistID: MusicItemID(entry.playlistID),
                playlistName: entry.playlistName,
                customName: entry.customName
            )
        }
    }
}
