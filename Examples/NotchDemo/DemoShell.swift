import NotchKit
import SwiftUI

// The thin part. Everything here is preset-agnostic: it asks the active
// `IslandPreset` for content and adds only the switcher this demo needs.

// MARK: - Shell

/// The resting pill: cutout-safe layout, filled by whichever preset is active.
///
/// `NotchCutoutLayout` is what keeps content clear of the hardware. Drop it and
/// the centre of this bar becomes invisible on any MacBook — and only on a
/// MacBook, which is how it survives development on an external monitor.
struct CollapsedShell: View {
    let model: DemoModel

    var body: some View {
        NotchCutoutLayout(
            cutoutWidth: model.presenter.geometry.hasPhysicalNotch
                ? model.presenter.geometry.notchWidth
                : 0,
            gutterWidth: model.presenter.collapsedGutterWidth,
            // Lets the layout derive an edge inset that clears the pill's
            // semicircular corners for content of any height.
            pillHeight: model.presenter.geometry.collapsedHeight
        ) {
            model.preset.collapsedLeading(model)
        } trailing: {
            model.preset.collapsedTrailing(model)
        }
    }
}

/// The open panel: the active preset, plus the switcher this demo needs.
///
/// The switcher is an *overlay* rather than a row in a `VStack` so it works for
/// `Now Playing` too, whose `.canvas` configuration gives up the derived insets
/// and expects content to run edge to edge.
struct ExpandedShell: View {
    let model: DemoModel

    var body: some View {
        let insets = model.preset.configuration.expandedContentInsets
        // NotchContainer already applies `expandedContentInsets` around this view
        // when `insets.leading > 0`. For `.canvas` (insets.leading == 0), PresetSwitcher
        // applies its own insets to stay clear of the edge.
        let horizontalPadding: CGFloat = insets.leading > 0 ? 0 : 26
        let bottomPadding: CGFloat = insets.bottom > 0 ? 0 : 16

        model.preset.expanded(model)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .bottom) {
                PresetSwitcher(model: model)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, bottomPadding)
            }
    }
}

struct PresetSwitcher: View {
    let model: DemoModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(IslandPreset.all.enumerated()), id: \.element.id) { index, preset in
                Button(preset.name) { model.select(index) }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(
                        Capsule().fill(
                            Color.white.opacity(index == model.presetIndex ? 0.20 : 0.07)
                        )
                    )
            }

            Spacer(minLength: 0)

            Button("Close") { model.presenter.collapse() }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .opacity(0.65)
        }
    }
}
