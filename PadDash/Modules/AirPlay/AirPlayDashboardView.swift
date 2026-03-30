import SwiftUI
import MusicKit
import AVKit
import UniformTypeIdentifiers
import CoreImage
import UIKit

// MARK: - AirPlay Dashboard View

struct AirPlayDashboardView: View {
    @ObservedObject var manager: AirPlayManager
    @State private var draggedWidget: AirPlayWidget?

    var body: some View {
        VStack(spacing: 0) {
            if let expandedID = manager.expandedWidgetID,
               let widget = manager.widgets.first(where: { $0.id == expandedID }) {
                ExpandedPlayerView(widget: widget, manager: manager)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if manager.widgets.isEmpty {
                emptyStateView
            } else {
                widgetsGrid
            }
        }
        .sheet(isPresented: $manager.showPlaylistPicker) {
            PlaylistPickerSheet(manager: manager)
        }
        .alert("Rename Widget", isPresented: Binding(
            get: { manager.widgetBeingRenamed != nil },
            set: { if !$0 { manager.cancelRename() } }
        )) {
            TextField("Widget name", text: $manager.renameText)
            Button("Save") { manager.commitRename() }
            Button("Cancel", role: .cancel) { manager.cancelRename() }
        } message: {
            Text("Enter a custom name for this widget.")
        }
        .task {
            if !manager.isAuthorized && !manager.authorizationDenied {
                await manager.requestAuthorization()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: DS.Space.md) {
            Spacer()
            Image(systemName: "airplayaudio")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(DS.Color.accentMint.opacity(0.5))
            Text("No Music Widgets")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(DS.Color.textPrimary)

            if manager.authorizationDenied {
                Text("Apple Music access was denied.\nGo to Settings → PadDash to enable it.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Space.xl)
            } else {
                Text("Tap + to add a playlist widget.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Space.xl)

                Button {
                    manager.beginAddWidget()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                        Text("Add Widget")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(DS.Color.accentMint)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(DS.Color.accentMint.opacity(0.15))
                    .clipShape(Capsule())
                }
                .padding(.top, DS.Space.sm)
            }

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
                    MusicWidgetCard(widget: widget, manager: manager)
                        .aspectRatio(0.85, contentMode: .fit)
                        .opacity(draggedWidget?.id == widget.id ? 0.4 : 1.0)
                        .onDrag {
                            draggedWidget = widget
                            return NSItemProvider(object: widget.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: AirPlayWidgetDropDelegate(
                            widget: widget,
                            manager: manager,
                            draggedWidget: $draggedWidget
                        ))
                        .contextMenu {
                            Button {
                                manager.beginRename(widget)
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                withAnimation(DS.Animation.snappy) {
                                    manager.removeWidget(widget)
                                }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
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

// MARK: - Music Widget Card (Collapsed)

struct MusicWidgetCard: View {
    let widget: AirPlayWidget
    @ObservedObject var manager: AirPlayManager

    private var isActive: Bool { manager.activeWidgetID == widget.id }
    private let accent = DS.Color.accentMint

    var body: some View {
        DashCard {
            VStack(spacing: DS.Space.sm) {

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(widget.displayName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.Color.textSecondary)
                            .lineLimit(1)
                        Text("Playlist")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(DS.Color.textTertiary)
                    }
                    Spacer()

                    AirPlayRouteButton()
                        .frame(width: 24, height: 24)
                }

                Spacer()

                // Album art or placeholder
                if isActive, let artwork = manager.currentArtwork {
                    ArtworkImage(artwork, width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .fill(DS.Color.surfaceRaised)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 36, weight: .thin))
                                .foregroundColor(accent.opacity(0.4))
                        )
                }

                // Track info when playing
                if isActive, let title = manager.currentTrackTitle {
                    VStack(spacing: 2) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.Color.textPrimary)
                            .lineLimit(1)
                        if let artist = manager.currentArtistName {
                            Text(artist)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(DS.Color.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }

                // Progress bar when active
                if isActive, manager.totalDuration > 0 {
                    TrackProgressBar(
                        progress: manager.currentPlaybackTime / manager.totalDuration,
                        accent: accent
                    )
                }

                Spacer()

                // Playback controls
                HStack(spacing: DS.Space.sm) {
                    Button { manager.skipBackward() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isActive ? DS.Color.textSecondary : DS.Color.textTertiary)
                            .frame(width: 36, height: 36)
                            .background(DS.Color.surfaceRaised)
                            .clipShape(Circle())
                    }
                    .disabled(!isActive)

                    Button {
                        if isActive {
                            manager.togglePlayPause()
                        } else {
                            manager.playWidget(widget)
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(accent)
                                .frame(width: 48, height: 48)
                                .shadow(color: accent.opacity(0.45), radius: 12, x: 0, y: 4)

                            Image(systemName: (isActive && manager.isPlaying) ? "pause.fill" : "play.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(DS.Color.background)
                                .offset(x: (isActive && manager.isPlaying) ? 0 : 2)
                        }
                    }

                    Button { manager.skipForward() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isActive ? DS.Color.textSecondary : DS.Color.textTertiary)
                            .frame(width: 36, height: 36)
                            .background(DS.Color.surfaceRaised)
                            .clipShape(Circle())
                    }
                    .disabled(!isActive)
                }

                // Expand button when playing
                if isActive {
                    Button {
                        manager.expandWidget(widget)
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(accent)
                            .padding(6)
                            .background(accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    }
                }
            }
        }
        .onTapGesture {
            if isActive {
                manager.expandWidget(widget)
            }
        }
    }
}

// MARK: - Expanded Player View

struct ExpandedPlayerView: View {
    let widget: AirPlayWidget
    @ObservedObject var manager: AirPlayManager

    private let accent = DS.Color.accentMint

    var body: some View {
        ZStack {
            AlbumArtShimmerBackground(artwork: manager.currentArtwork, accent: accent)

            VStack(spacing: DS.Space.lg) {

                // Top bar
                HStack {
                    Button {
                        manager.collapseWidget()
                    } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DS.Color.textSecondary)
                            .padding(10)
                            .background(DS.Color.surfaceRaised.opacity(0.72))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text(widget.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.Color.textSecondary)

                    Spacer()

                    AirPlayRouteButton()
                        .frame(width: 36, height: 36)
                }

                Spacer()

                // Large album artwork
                if let artwork = manager.currentArtwork {
                    ArtworkImage(artwork, width: 300, height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                        .shadow(color: accent.opacity(0.3), radius: 30, x: 0, y: 10)
                } else {
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(DS.Color.surfaceRaised)
                        .frame(width: 300, height: 300)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 80, weight: .ultraLight))
                                .foregroundColor(accent.opacity(0.3))
                        )
                }

                // Track info
                VStack(spacing: 4) {
                    Text(manager.currentTrackTitle ?? "Not Playing")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.Color.textPrimary)
                        .lineLimit(1)

                    Text(manager.currentArtistName ?? "")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(DS.Color.textSecondary)
                        .lineLimit(1)
                }

                // Progress bar with timestamps
                VStack(spacing: 4) {
                    TrackProgressBar(
                        progress: manager.totalDuration > 0
                            ? manager.currentPlaybackTime / manager.totalDuration
                            : 0,
                        accent: accent
                    )
                    .frame(height: 6)

                    HStack {
                        Text(formatTime(manager.currentPlaybackTime))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(DS.Color.textTertiary)
                        Spacer()
                        Text(formatTime(manager.totalDuration))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(DS.Color.textTertiary)
                    }
                }
                .padding(.horizontal, DS.Space.xl)

                // Large playback controls
                HStack(spacing: DS.Space.xl) {
                    Button { manager.skipBackward() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(DS.Color.textSecondary)
                            .frame(width: 56, height: 56)
                    }

                    Button { manager.togglePlayPause() } label: {
                        ZStack {
                            Circle()
                                .fill(accent)
                                .frame(width: 80, height: 80)
                                .shadow(color: accent.opacity(0.45), radius: 16, x: 0, y: 6)

                            Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(DS.Color.background)
                                .offset(x: manager.isPlaying ? 0 : 3)
                        }
                    }

                    Button { manager.skipForward() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(DS.Color.textSecondary)
                            .frame(width: 56, height: 56)
                    }
                }

                // Shuffle & Repeat controls
                HStack(spacing: DS.Space.xl) {
                    Button { manager.toggleShuffle() } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(manager.shuffleMode == .songs ? accent : DS.Color.textTertiary)
                            .frame(width: 44, height: 44)
                            .background(manager.shuffleMode == .songs ? accent.opacity(0.15) : Color.clear)
                            .clipShape(Circle())
                    }

                    Button { manager.cycleRepeatMode() } label: {
                        Image(systemName: repeatIconName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(manager.repeatMode != .none ? accent : DS.Color.textTertiary)
                            .frame(width: 44, height: 44)
                            .background(manager.repeatMode != .none ? accent.opacity(0.15) : Color.clear)
                            .clipShape(Circle())
                    }
                }

                Spacer()
            }
            .padding(DS.Space.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var repeatIconName: String {
        switch manager.repeatMode {
        case .one:
            return "repeat.1"
        case .all:
            return "repeat"
        default:
            return "repeat"
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard !seconds.isNaN && seconds >= 0 else { return "0:00" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Album Art Shimmer Background

private struct AlbumArtShimmerBackground: View {
    let artwork: Artwork?
    let accent: Color

    @State private var palette: [Color] = [
        DS.Color.background,
        DS.Color.accentMint.opacity(0.35),
        DS.Color.accentBlue.opacity(0.22),
    ]

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    LinearGradient(
                        colors: [
                            palette[safe: 0] ?? DS.Color.background,
                            palette[safe: 1] ?? accent.opacity(0.28),
                            palette[safe: 2] ?? DS.Color.background,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    shimmerOrb(
                        color: (palette[safe: 1] ?? accent).opacity(0.75),
                        size: proxy.size.width * 0.78,
                        x: proxy.size.width * (0.2 + 0.18 * sin(time * 0.22)),
                        y: proxy.size.height * (0.18 + 0.12 * cos(time * 0.18))
                    )

                    shimmerOrb(
                        color: (palette[safe: 2] ?? accent).opacity(0.65),
                        size: proxy.size.width * 0.92,
                        x: proxy.size.width * (0.78 + 0.14 * cos(time * 0.17)),
                        y: proxy.size.height * (0.46 + 0.16 * sin(time * 0.21))
                    )

                    shimmerOrb(
                        color: (palette[safe: 0] ?? accent).opacity(0.48),
                        size: proxy.size.width * 0.66,
                        x: proxy.size.width * (0.48 + 0.22 * sin(time * 0.14 + 1.4)),
                        y: proxy.size.height * (0.82 + 0.08 * cos(time * 0.24))
                    )

                    Rectangle()
                        .fill(.ultraThinMaterial.opacity(0.36))
                }
                .overlay(
                    LinearGradient(
                        colors: [
                            DS.Color.background.opacity(0.34),
                            .clear,
                            DS.Color.background.opacity(0.52),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            }
        }
        .task(id: artwork?.backgroundKey) {
            let extracted = await AlbumArtPaletteExtractor.palette(from: artwork)
            if !extracted.isEmpty {
                withAnimation(.easeInOut(duration: 0.8)) {
                    palette = extracted
                }
            }
        }
    }

    private func shimmerOrb(color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: size * 0.18)
            .position(x: x, y: y)
            .blendMode(.plusLighter)
    }
}

@MainActor
private enum AlbumArtPaletteExtractor {
    static func palette(from artwork: Artwork?) async -> [Color] {
        guard let artwork,
              let url = artwork.url(width: 160, height: 160) else {
            return fallbackPalette
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data),
                  let colors = extractPalette(from: image),
                  !colors.isEmpty else {
                return fallbackPalette
            }
            return colors
        } catch {
            return fallbackPalette
        }
    }

    private static var fallbackPalette: [Color] {
        [
            DS.Color.background,
            DS.Color.accentMint.opacity(0.34),
            DS.Color.accentBlue.opacity(0.22),
        ]
    }

    private static func extractPalette(from image: UIImage) -> [Color]? {
        let renderSize = CGSize(width: 40, height: 40)
        let renderer = UIGraphicsImageRenderer(size: renderSize)
        let normalized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: renderSize))
        }

        guard let cgImage = normalized.cgImage,
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }

        struct Bucket {
            var score: Double = 0
            var red: Double = 0
            var green: Double = 0
            var blue: Double = 0
        }

        var buckets: [Int: Bucket] = [:]
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let red = Double(bytes[offset]) / 255.0
                let green = Double(bytes[offset + 1]) / 255.0
                let blue = Double(bytes[offset + 2]) / 255.0
                let alpha = bytesPerPixel > 3 ? Double(bytes[offset + 3]) / 255.0 : 1.0

                guard alpha > 0.6 else { continue }

                var hue: CGFloat = 0
                var saturation: CGFloat = 0
                var brightness: CGFloat = 0
                UIColor(red: red, green: green, blue: blue, alpha: alpha)
                    .getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)

                guard brightness > 0.14 else { continue }

                let hueBucket = Int(hue * 24)
                let saturationBucket = Int(saturation * 5)
                let brightnessBucket = Int(brightness * 5)
                let key = hueBucket * 100 + saturationBucket * 10 + brightnessBucket

                let weight = Double((saturation + brightness) * alpha)
                var bucket = buckets[key, default: Bucket()]
                bucket.score += weight
                bucket.red += red * weight
                bucket.green += green * weight
                bucket.blue += blue * weight
                buckets[key] = bucket
            }
        }

        let palette = buckets.values
            .sorted { $0.score > $1.score }
            .prefix(3)
            .compactMap { bucket -> Color? in
                guard bucket.score > 0 else { return nil }
                return Color(
                    red: bucket.red / bucket.score,
                    green: bucket.green / bucket.score,
                    blue: bucket.blue / bucket.score
                )
            }

        guard !palette.isEmpty else { return nil }

        if palette.count == 1 {
            return [palette[0].opacity(0.28), palette[0].opacity(0.48), palette[0].opacity(0.22)]
        }

        if palette.count == 2 {
            return [palette[0].opacity(0.24), palette[1].opacity(0.48), palette[0].opacity(0.18)]
        }

        return [
            palette[0].opacity(0.22),
            palette[1].opacity(0.5),
            palette[2].opacity(0.34),
        ]
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Artwork {
    var backgroundKey: String? {
        url(width: 160, height: 160)?.absoluteString
    }
}

// MARK: - Track Progress Bar

struct TrackProgressBar: View {
    var progress: Double
    var accent: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(DS.Color.surfaceRaised)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(accent)
                    .frame(width: geo.size.width * CGFloat(max(0, min(1, progress))))
                    .animation(DS.Animation.smooth, value: progress)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - AirPlay Route Button

struct AirPlayRouteButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = UIColor(DS.Color.accentMint)
        picker.tintColor = UIColor(DS.Color.textSecondary)
        picker.backgroundColor = .clear
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

// MARK: - Playlist Picker Sheet

struct PlaylistPickerSheet: View {
    @ObservedObject var manager: AirPlayManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredPlaylists: [Playlist] {
        guard !searchText.isEmpty else { return manager.availablePlaylists }
        return manager.availablePlaylists.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                DS.Color.background.ignoresSafeArea()

                if manager.isLoadingPlaylists {
                    VStack(spacing: DS.Space.md) {
                        Spacer()
                        ProgressView()
                            .tint(DS.Color.accentMint)
                        Text("Loading playlists...")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(DS.Color.textSecondary)
                        Spacer()
                    }
                } else if manager.availablePlaylists.isEmpty {
                    VStack(spacing: DS.Space.md) {
                        Spacer()
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48, weight: .thin))
                            .foregroundColor(DS.Color.accentMint.opacity(0.5))
                        Text("No Playlists Found")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.Color.textPrimary)
                        Text("Create a playlist in Apple Music first.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(DS.Color.textSecondary)
                        Spacer()
                    }
                } else {
                    VStack(spacing: 0) {
                        // Search bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(DS.Color.textTertiary)
                            TextField("Search...", text: $searchText)
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

                        if filteredPlaylists.isEmpty {
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
                        } else {
                            ScrollView {
                                LazyVStack(spacing: DS.Space.sm) {
                                    ForEach(filteredPlaylists) { playlist in
                                        Button {
                                            withAnimation(DS.Animation.snappy) {
                                                manager.addWidget(for: playlist)
                                            }
                                        } label: {
                                            playlistRow(playlist)
                                        }
                                    }
                                }
                                .padding(.horizontal, DS.Space.lg)
                                .padding(.bottom, DS.Space.xl)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose a Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DS.Color.textSecondary)
                }
            }
        }
    }

    private func playlistRow(_ playlist: Playlist) -> some View {
        HStack(spacing: DS.Space.md) {
            // Playlist artwork thumbnail
            if let artwork = playlist.artwork {
                ArtworkImage(artwork, width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .fill(DS.Color.surfaceRaised)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "music.note.list")
                            .font(.system(size: 18))
                            .foregroundColor(DS.Color.accentMint)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.Color.textPrimary)
                    .lineLimit(1)
                if let description = playlist.shortDescription {
                    Text(description)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(DS.Color.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(DS.Color.accentMint)
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

// MARK: - AirPlay Widget Drop Delegate

struct AirPlayWidgetDropDelegate: DropDelegate {
    let widget: AirPlayWidget
    let manager: AirPlayManager
    @Binding var draggedWidget: AirPlayWidget?

    func performDrop(info: DropInfo) -> Bool {
        draggedWidget = nil
        manager.saveState()
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedWidget,
              dragged.id != widget.id,
              let fromIndex = manager.widgets.firstIndex(where: { $0.id == dragged.id }),
              let toIndex = manager.widgets.firstIndex(where: { $0.id == widget.id })
        else { return }

        withAnimation(DS.Animation.snappy) {
            manager.widgets.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
