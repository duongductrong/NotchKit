import SwiftUI

/// Morphs the island between collapsed and expanded inside the fixed-size window.
///
/// ## The morph
///
/// There is **one** surface, not two. A single `NotchShape` whose width, height,
/// and both corner radii animate together, so the pill physically grows into the
/// panel and its top corners curl further inward as it goes. Because the resting
/// pill is just `NotchShape` at a small top radius — and at `0` an exactly flat
/// one, which is what displays with no cutout get — every state in between is a
/// valid shape and the whole thing is four interpolating numbers.
///
/// The alternative — mounting a pill view and a panel view and cross-fading them —
/// is what makes an island feel like it *switches* rather than *transforms*. At no
/// point during a cross-fade is there a single object changing form; there are two
/// objects trading places, and the eye reads that as a cut.
///
/// ## Why animating this frame is cheap
///
/// Animating a `frame` is normally expensive because it re-runs layout for the
/// whole subtree every frame. Here the content is **pinned to fixed sizes** and
/// merely clipped by the morphing container, so the animation moves one clip path
/// and one fill — the content itself never re-lays-out. That is the trick that
/// buys a real morph at cross-fade cost.
///
/// Note the window still never resizes; the morph happens entirely inside it.
/// See `docs/architecture.md`.
public struct NotchContainer<Collapsed: View, Expanded: View>: View {
    let presenter: NotchPresenter
    @ViewBuilder let collapsed: () -> Collapsed
    @ViewBuilder let expanded: () -> Expanded

    /// Keeps the expanded content alive through the morph and its fade-out.
    @State private var expandedMounted = false
    /// Invalidates in-flight unmount timers so a rapid open→close→open cannot let
    /// an older timer tear down the content that is currently showing.
    @State private var mountGeneration: UInt64 = 0

    public init(
        presenter: NotchPresenter,
        @ViewBuilder collapsed: @escaping () -> Collapsed,
        @ViewBuilder expanded: @escaping () -> Expanded
    ) {
        self.presenter = presenter
        self.collapsed = collapsed
        self.expanded = expanded
    }

    private var isOpen: Bool {
        presenter.phase == .expanded
    }

    private var isPeeking: Bool {
        presenter.phase == .peeking
    }

    private var motion: NotchMotion {
        presenter.motion
    }

    private var style: NotchStyle {
        presenter.style
    }

    private var config: NotchConfiguration {
        presenter.configuration
    }

    public var body: some View {
        GeometryReader { proxy in
            let geometry = presenter.geometry
            let collapsedHeight = geometry.collapsedHeight
            let collapsedWidth = presenter.collapsedSurfaceWidth
            let expandedWidth = max(0, proxy.size.width - config.shadowInsetHorizontal * 2)
            let expandedHeight = max(collapsedHeight, proxy.size.height - config.shadowInsetBottom)

            // The four interpolating values. Everything visual follows from these.
            let surfaceWidth = isOpen ? expandedWidth : collapsedWidth
            let surfaceHeight = isOpen ? expandedHeight : collapsedHeight
            let topRadius = cutoutTopRadius(
                isOpen ? config.expandedTopCornerRadius : config.collapsedTopCornerRadius
            )
            let bottomRadius = isOpen ? config.expandedBottomCornerRadius : collapsedHeight / 2

            let shape = NotchShape(
                topCornerRadius: topRadius,
                bottomCornerRadius: bottomRadius
            )

            ZStack(alignment: .top) {
                // Fills the window so the surface anchors to the top edge and
                // centres horizontally — which lands it exactly inside the
                // shadow margin without any explicit padding.
                Color.clear

                ZStack(alignment: .top) {
                    collapsedContent(width: collapsedWidth, height: collapsedHeight)
                    expandedContent(
                        width: expandedWidth,
                        height: expandedHeight,
                        topReserve: config.expandedTopReserve.resolved(
                            collapsedHeight: collapsedHeight,
                            hasPhysicalNotch: geometry.hasPhysicalNotch
                        )
                    )
                }
                // THE MORPH. Content overflows this frame while collapsed and is
                // clipped to the shape, so the panel is revealed rather than
                // faded in.
                .frame(width: surfaceWidth, height: surfaceHeight, alignment: .top)
                .background(shape.fill(style.ink))
                .clipShape(shape)
                .overlay { shape.stroke(style.hairline, lineWidth: style.hairlineWidth) }
                .shadow(
                    color: style.shadowColor,
                    // No shadow when collapsed: the pill sits flush against the
                    // bezel, and a shadow there makes it look like it is hovering
                    // in front of the hardware.
                    radius: isOpen ? style.shadowRadius : 0,
                    y: isOpen ? style.shadowOffsetY : 0
                )
                .scaleEffect(isPeeking ? motion.peekScale : 1, anchor: .top)
                // One driver for the morph. Content opacity is choreographed
                // separately below — different properties, not a race.
                .animation(motion.animation(for: presenter.phase), value: presenter.phase)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
        // Dark by default, because content that picks Light Mode colours vanishes
        // against dark ink — and only for users who happen to be in Light Mode.
        // `nil` opts out, for a deliberately light island.
        .preferredColorScheme(style.colorScheme)
        .onAppear { syncMount(immediately: true) }
        .onChange(of: presenter.phase) { _, _ in syncMount() }
    }

    /// Concave top corners only where there is a real cutout to fuse with. On a
    /// plain display they read as a rendering fault, so the top stays flat in
    /// both states and the island morphs pill → larger pill.
    ///
    /// Both phases go through here, which is what keeps the collapsed curl and the
    /// expanded one from disagreeing about the display: a pill that flares but a
    /// panel that does not would make the morph appear to *un*-curl as it opens.
    private func cutoutTopRadius(_ requested: CGFloat) -> CGFloat {
        presenter.geometry.hasPhysicalNotch ? requested : 0
    }

    // MARK: Content

    private func collapsedContent(width: CGFloat, height: CGFloat) -> some View {
        collapsed()
            .frame(width: width, height: height)
            .foregroundStyle(style.foreground)
            .opacity(isOpen ? 0 : 1)
            .allowsHitTesting(!isOpen)
            // Scoped to opacity: the outgoing content clears out fast, the
            // incoming waits for room. Attaching the animation here rather than
            // at the root is what keeps it from competing with the morph.
            .animation(motion.contentFade(isIncoming: !isOpen), value: isOpen)
    }

    @ViewBuilder
    private func expandedContent(width: CGFloat, height: CGFloat, topReserve: CGFloat) -> some View {
        if expandedMounted {
            VStack(spacing: 0) {
                // Reserve the cutout row when the policy asks for it: content up
                // there sits behind the physical notch on a MacBook and is simply
                // not visible. A zero reserve skips the row entirely rather than
                // inserting an empty one, so `.canvas` really does get the full
                // panel.
                if topReserve > 0 {
                    Color.clear
                        .frame(height: topReserve)
                        .allowsHitTesting(false)
                }

                expanded()
                    .padding(config.expandedContentInsets)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: config.expandedContentAlignment
                    )
            }
            .frame(width: width, height: height, alignment: .top)
            .foregroundStyle(style.foreground)
            .opacity(isOpen ? 1 : 0)
            .allowsHitTesting(isOpen)
            .animation(motion.contentFade(isIncoming: isOpen), value: isOpen)
        }
    }

    // MARK: Mount lifecycle

    private func syncMount(immediately: Bool = false) {
        mountGeneration &+= 1
        let generation = mountGeneration

        if presenter.phase == .expanded {
            expandedMounted = true
            return
        }

        guard !immediately else {
            expandedMounted = false
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(motion.expandedUnmountDelay))
            // Bail if another transition happened while we slept. Without the
            // generation check a fast toggle unmounts content that is on screen
            // and the panel goes blank mid-morph.
            guard mountGeneration == generation, presenter.phase != .expanded else { return }
            expandedMounted = false
        }
    }
}
