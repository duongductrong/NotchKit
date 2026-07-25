import SwiftUI

// MARK: - NotchMotion

/// The animation vocabulary for an island, in one place.
///
/// ## Why these curves
///
/// **Opening and closing are not symmetric, on purpose.** Opening is a spring:
/// the panel is arriving, and a touch of overshoot makes it feel physical and
/// responsive. Closing is a monotonic ease: the panel is *leaving*, and a spring
/// on the way out means the shape bounces back toward the viewer after they have
/// already dismissed it — which reads as the UI arguing. Every island that feels
/// cheap gets this wrong by reusing one curve for both directions.
///
/// **`response` is not duration.** It is the spring's natural period — roughly
/// how long the bulk of the travel takes. 0.42s is at the top of the range that
/// still feels instant; past ~0.5s the panel starts to feel like it is loading.
///
/// **`dampingFraction` is the personality dial.** 1.0 settles with no overshoot
/// (correct, lifeless). 0.8 gives one barely-perceptible overshoot — the sweet
/// spot for a surface that carries content, because visible ringing under text
/// makes the text hard to read. Drop to ~0.5 only for a deliberate attention
/// bump where the bounce *is* the message.
public struct NotchMotion: Equatable, Sendable {
    /// Collapsed → expanded. Drives the shape morph. Spring: the panel is arriving.
    public var expand: Animation

    /// Expanded → collapsed. Monotonic: the panel is leaving, don't argue.
    public var collapse: Animation

    /// The attention bump. Bouncy by design.
    public var peek: Animation

    /// Hover scale on the collapsed pill.
    public var hover: Animation

    /// Content changing *inside* an already-open panel (rows appearing, labels
    /// swapping). Standard material easing — content should not spring, because
    /// overshoot on text is hard to read.
    public var contentMorph: Animation

    /// Small state flips: selection, highlight, checkmarks. Short enough to feel
    /// immediate, long enough not to strobe.
    public var highlight: Animation

    // MARK: Content choreography

    /// How long incoming content takes to fade up.
    public var contentRevealDuration: TimeInterval

    /// Head start given to the shape before incoming content appears.
    ///
    /// Without it, panel text fades up while the shape is still pill-sized, so
    /// for the first few frames the content is squeezed into a sliver and
    /// visibly clipped. A small delay lets the morph open the room first, and is
    /// most of what separates a morph that looks intentional from one that looks
    /// like two things happening at once.
    public var contentRevealDelay: TimeInterval

    /// How long outgoing content takes to fade away.
    ///
    /// Deliberately quicker than the reveal and never delayed: the content must
    /// be gone before the shape closes over the space it occupied, or it appears
    /// to be crushed by the animation.
    public var contentHideDuration: TimeInterval

    /// How long the expanded content stays mounted after collapsing.
    ///
    /// Must outlast `collapse`, or the content tears down mid-morph and the panel
    /// flashes empty while it is still closing.
    public var expandedUnmountDelay: TimeInterval

    /// Scale applied to the collapsed pill on hover. Tiny for a reason: at notch
    /// size, anything past ~1.05 visibly clips against the screen edge.
    public var hoverScale: CGFloat

    /// Scale at the top of a `peek`.
    public var peekScale: CGFloat

    /// How long a `peek` holds before returning to collapsed.
    public var peekDuration: TimeInterval

    public init(
        expand: Animation = .spring(response: 0.42, dampingFraction: 0.80, blendDuration: 0),
        collapse: Animation = .smooth(duration: 0.30),
        peek: Animation = .spring(response: 0.30, dampingFraction: 0.50),
        hover: Animation = .spring(response: 0.38, dampingFraction: 0.80),
        contentMorph: Animation = .timingCurve(0.4, 0, 0.2, 1, duration: 0.45),
        highlight: Animation = .easeInOut(duration: 0.15),
        contentRevealDuration: TimeInterval = 0.22,
        contentRevealDelay: TimeInterval = 0.08,
        contentHideDuration: TimeInterval = 0.12,
        expandedUnmountDelay: TimeInterval = 0.36,
        hoverScale: CGFloat = 1.028,
        peekScale: CGFloat = 1.04,
        peekDuration: TimeInterval = 0.30
    ) {
        self.expand = expand
        self.collapse = collapse
        self.peek = peek
        self.hover = hover
        self.contentMorph = contentMorph
        self.highlight = highlight
        self.contentRevealDuration = contentRevealDuration
        self.contentRevealDelay = contentRevealDelay
        self.contentHideDuration = contentHideDuration
        self.expandedUnmountDelay = expandedUnmountDelay
        self.hoverScale = hoverScale
        self.peekScale = peekScale
        self.peekDuration = peekDuration
    }

    /// Picks the curve for a transition *into* `phase`.
    ///
    /// Funnel the shape morph through this. One `.animation(_, value:)` driven by
    /// one selector is what keeps the motion coherent — scatter `withAnimation`
    /// across the view and transitions start racing, which shows up as a stutter
    /// when two land in the same frame.
    public func animation(for phase: NotchPhase) -> Animation {
        switch phase {
        case .expanded: expand
        case .collapsed: collapse
        case .peeking: peek
        }
    }

    /// Fade curve for content entering or leaving during a morph.
    ///
    /// Scoped to opacity and applied at the content, not the root, so it
    /// choreographes *with* the morph instead of competing for the same property.
    public func contentFade(isIncoming: Bool) -> Animation {
        isIncoming
            ? .easeOut(duration: contentRevealDuration).delay(contentRevealDelay)
            : .easeIn(duration: contentHideDuration)
    }
}

// MARK: - Presets

public extension NotchMotion {
    /// The tuned defaults. Start here.
    static let standard = NotchMotion()

    /// Faster, flatter, no overshoot. For utility islands shown many times an
    /// hour, where personality becomes noise.
    static let crisp = NotchMotion(
        expand: .spring(response: 0.30, dampingFraction: 1.0, blendDuration: 0),
        collapse: .smooth(duration: 0.20),
        peek: .spring(response: 0.24, dampingFraction: 0.70),
        hover: .easeOut(duration: 0.14),
        contentMorph: .easeInOut(duration: 0.22),
        highlight: .easeInOut(duration: 0.10),
        contentRevealDuration: 0.16,
        contentRevealDelay: 0.05,
        contentHideDuration: 0.09,
        expandedUnmountDelay: 0.26,
        hoverScale: 1.02,
        peekScale: 1.03,
        peekDuration: 0.24
    )

    /// Looser and springier. For consumer-facing islands shown a few times a
    /// session, where the motion is part of the product's character.
    static let playful = NotchMotion(
        expand: .spring(response: 0.50, dampingFraction: 0.68, blendDuration: 0),
        collapse: .smooth(duration: 0.34),
        peek: .spring(response: 0.34, dampingFraction: 0.42),
        hover: .spring(response: 0.40, dampingFraction: 0.70),
        contentMorph: .spring(response: 0.42, dampingFraction: 0.82),
        highlight: .easeInOut(duration: 0.18),
        contentRevealDuration: 0.26,
        contentRevealDelay: 0.12,
        contentHideDuration: 0.14,
        expandedUnmountDelay: 0.42,
        hoverScale: 1.04,
        peekScale: 1.07,
        peekDuration: 0.36
    )

    /// Honours Reduce Motion: cross-fades only, no springs, no scaling.
    ///
    /// Not optional. An island lives at the edge of vision and animates
    /// unprompted, which is exactly the pattern that triggers discomfort for
    /// motion-sensitive users. Resolve through `NotchMotion.resolved(_:)`.
    ///
    /// Note this is the one configuration where the surface deliberately does
    /// *not* morph: with these curves the shape change is a plain ease, and the
    /// content simply fades. A size change that eases rather than springs reads
    /// as a reveal, not as motion across the visual field.
    static let reduced = NotchMotion(
        expand: .easeOut(duration: 0.20),
        collapse: .easeOut(duration: 0.20),
        peek: .easeOut(duration: 0.20),
        hover: .easeOut(duration: 0.12),
        contentMorph: .easeInOut(duration: 0.20),
        highlight: .easeInOut(duration: 0.10),
        contentRevealDuration: 0.18,
        contentRevealDelay: 0.04,
        contentHideDuration: 0.12,
        expandedUnmountDelay: 0.26,
        hoverScale: 1.0,
        peekScale: 1.0,
        peekDuration: 0.24
    )

    /// Swaps in `.reduced` when the system asks for less motion.
    static func resolved(_ base: NotchMotion = .standard) -> NotchMotion {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? .reduced : base
    }
}
