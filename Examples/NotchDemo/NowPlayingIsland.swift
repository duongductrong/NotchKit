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
            var configuration = NotchConfiguration.standard
            configuration.expandedSize = CGSize(width: 480, height: 195)
            configuration.collapsedWidth = .wrapCutout(reserve: 44)
            configuration.expandedBottomCornerRadius = 24
            return configuration
        }(),
        motion: .crisp,
        style: .standard,
        collapsedLeading: { model in
            AnyView(
                Image(systemName: model.isPlaying ? "waveform" : "pause.fill")
                    .font(.system(size: 11, weight: .medium))
                    .symbolEffect(.variableColor.iterative, isActive: model.isPlaying)
                    .foregroundStyle(Color(white: 0.9))
            )
        },
        collapsedTrailing: { _ in
            AnyView(
                Image(systemName: "airpodspro")
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.85)
            )
        },
        expanded: { model in AnyView(NowPlayingPanel(model: model)) }
    )
}

// MARK: - Native Expanded View

private struct NowPlayingPanel: View {
    let model: DemoModel
    @State private var progress: Double = 0.42

    var body: some View {
        VStack(spacing: 12) {
            // Track Header: Album Art, Info & Output Device
            HStack(spacing: 12) {
                // Album Art Box
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.22, green: 0.12, blue: 0.38),
                                    Color(red: 0.10, green: 0.14, blue: 0.28)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )

                    Image(systemName: "music.note")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(white: 0.85))
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(model.track.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                // AirPlay / AirPods Indicator
                HStack(spacing: 4) {
                    Image(systemName: "airpodspro")
                        .font(.system(size: 11))
                    Text("AirPods Pro")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            }

            // Scrubber Bar & Timers
            VStack(spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 4)

                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, geo.size.width * progress), height: 4)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text("1:42")
                    Spacer()
                    Text("-2:15")
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            }

            // Transport Controls
            HStack(spacing: 24) {
                Button {} label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {} label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)

                Button {
                    model.isPlaying.toggle()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)

                Button {} label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {} label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(Color(white: 0.9))
        }
        .padding(.bottom, 32)
    }
}
