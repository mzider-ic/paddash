import SwiftUI
import MusicKit

// MARK: - AirPlay Widget

struct AirPlayWidget: Identifiable {
    let id: UUID
    var playlistID: MusicItemID
    var playlistName: String
    var customName: String?

    // Transient playback state (not persisted)
    var isPlaying: Bool = false
    var currentTrackTitle: String?
    var currentArtistName: String?
    var currentArtwork: Artwork?
    var currentPlaybackTime: TimeInterval = 0
    var totalDuration: TimeInterval = 0

    var displayName: String {
        if let custom = customName, !custom.isEmpty { return custom }
        return playlistName
    }

    var referenceID: String { playlistID.rawValue }
}
