import NotchKit
import SwiftUI

// The third shape a panel can take: full-bleed.
//
// `NotchConfiguration.canvas` sets `expandedTopReserve` to `.none` and drops the
// derived insets, so content owns every pixel of the panel — including the strip
// behind the physical cutout. That is fine for artwork and wrong for text, which
// is the whole reason the reserve is a policy rather than a constant.
//
// The container still clips content to `NotchShape`, so a full-bleed gradient
// picks up the concave corners for free.

extension IslandPreset {
    static let nowPlaying = IslandPreset(
        id: "now-playing",
        name: "Now Playing",
        configuration: {
            var configuration = NotchConfiguration.canvas
            configuration.expandedSize = CGSize(width: 460, height: 190)
            configuration.collapsedWidth = .wrapCutout(reserve: 40)
            configuration.expandedBottomCornerRadius = 26
            return configuration
        }(),
        motion: .crisp,
        style: .contrast,
        collapsedLeading: { model in
            AnyView(
                Image(systemName: model.isPlaying ? "waveform" : "pause.fill")
                    .font(.system(size: 11, weight: .medium))
                    .symbolEffect(.variableColor.iterative, isActive: model.isPlaying)
            )
        },
        collapsedTrailing: { _ in
            AnyView(
                Image(systemName: "airpodspro")
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.75)
            )
        },
        expanded: { model in AnyView(NowPlayingPanel(model: model)) }
    )
}

private struct NowPlayingPanel: View {
    let model: DemoModel

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Full-bleed artwork stand-in. Runs edge to edge and under the cutout,
            // which is the point of `.canvas`.
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.10, blue: 0.42),
                    Color(red: 0.66, green: 0.16, blue: 0.36),
                    Color(red: 0.95, green: 0.45, blue: 0.20),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Scrim so text stays legible over any artwork. Without it, light
            // album art and white type collide.
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.track.title)
                        .font(.system(size: 15, weight: .semibold))
                    Text(model.track.artist)
                        .font(.system(size: 12))
                        .opacity(0.75)
                }
                Spacer()
                Button {
                    model.isPlaying.toggle()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 26))
                }
                .buttonStyle(.plain)
            }
            // Hand-placed, because `.canvas` deliberately gave up the derived
            // insets. Clearing the bottom corner radius is now this view's job.
            .padding(.horizontal, 26)
            .padding(.bottom, 22)
        }
    }
}
