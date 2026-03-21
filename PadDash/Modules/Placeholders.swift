import SwiftUI

// MARK: - Coming Soon placeholder card

struct ComingSoonCard: View {
    var icon: String
    var title: String
    var subtitle: String
    var accent: Color

    var body: some View {
        DashCard {
            VStack(spacing: DS.Space.sm) {
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .thin))
                    .foregroundColor(accent.opacity(0.6))
                    .padding(.bottom, DS.Space.xs)

                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.Color.textPrimary)

                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)

                Spacer()

                Text("COMING SOON")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(accent.opacity(0.5))
                    .tracking(2)
                    .padding(.horizontal, DS.Space.sm)
                    .padding(.vertical, 5)
                    .background(accent.opacity(0.08))
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - AirPlay placeholder
struct AirPlayPlaceholderView: View {
    var body: some View {
        ComingSoonCard(
            icon: "airplayaudio",
            title: "AirPlay Music",
            subtitle: "Browse playlists and route\naudio to any AirPlay speaker.",
            accent: DS.Color.accentMint
        )
    }
}
