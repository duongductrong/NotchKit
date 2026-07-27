import SwiftUI

/// How the island looks, independent of how it moves or where it sits.
///
/// The silhouette is **ink and shadow only** — there is deliberately no stroked
/// edge, in either phase. A rim is what makes an island read as something pasted
/// on top of the display rather than part of it: a centred stroke puts half its
/// width outside the fill, so it outlines the shape against the desktop and,
/// while collapsed, traces the hardware cutout itself. Native is unbroken black.
///
/// If a particular island really does want an edge, stroke it in your own content
/// — that keeps the choice local instead of putting a rim on every island.
public struct NotchStyle: Equatable, Sendable {
    /// The island body.
    ///
    /// Defaults to **pure black**, and that is not laziness — it is the only value
    /// that merges with the hardware.
    ///
    /// The physical notch is opaque housing, not screen. It emits nothing, so it
    /// is as black as the panel can possibly be. Any lifted black beside it is a
    /// visibly *lighter* patch: on a MacBook you see the pill as a distinct grey
    /// rectangle bracketing the cutout instead of one continuous shape. The effect
    /// is subtle in a screenshot and obvious on real hardware, which is exactly
    /// why it is easy to ship by accident.
    ///
    /// The choice worth making consciously: an island can either *disappear into*
    /// the bezel or read as its own surface beside it. Both are good designs —
    /// pure black gets you the first, `.warmPaper` is there for the second. What
    /// does not work is aiming for the first and landing a few percent off.
    public var ink: Color

    /// Drawn in SwiftUI, not by AppKit, so it follows the concave path instead of
    /// boxing the window. Suppressed while collapsed — a shadow on a pill that is
    /// flush against the bezel makes it look like it is floating in front of the
    /// hardware.
    ///
    /// These three are the knobs; what actually gets drawn is two passes derived
    /// from them (`ambientShadow` and `contactShadow`), because a single Gaussian
    /// cannot be both soft and grounded. The room the shadow needs is likewise
    /// derived — `shadowReachHorizontal` / `shadowReachBelow` — so raising
    /// `shadowRadius` cannot silently push the falloff outside the window and get
    /// it clipped.
    public var shadowColor: Color
    public var shadowRadius: CGFloat
    public var shadowOffsetY: CGFloat

    /// Tint for content drawn on the ink.
    public var foreground: Color

    /// Colour scheme forced on your content.
    ///
    /// Defaults to `.dark`, because a dark island with Light Mode content in it is
    /// the most common way to make text vanish: `.secondary` and every stock
    /// control resolve to near-black against near-black ink, and it only shows up
    /// for users who happen to be in Light Mode.
    ///
    /// Set `nil` to inherit the system scheme — correct if you deliberately built
    /// a light island (light `ink`, dark `foreground`), and wrong otherwise.
    public var colorScheme: ColorScheme?

    public init(
        ink: Color = .black,
        shadowColor: Color = Color.black.opacity(0.42),
        shadowRadius: CGFloat = 30,
        shadowOffsetY: CGFloat = 16,
        foreground: Color = Color(white: 0.96),
        colorScheme: ColorScheme? = .dark
    ) {
        self.ink = ink
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.shadowOffsetY = shadowOffsetY
        self.foreground = foreground
        self.colorScheme = colorScheme
    }
}

// MARK: - Shadow

public extension NotchStyle {
    /// One drawn shadow pass.
    struct ShadowLayer: Equatable, Sendable {
        public let color: Color
        public let radius: CGFloat
        public let offsetY: CGFloat

        public init(color: Color, radius: CGFloat, offsetY: CGFloat) {
            self.color = color
            self.radius = radius
            self.offsetY = offsetY
        }
    }

    /// How far a SwiftUI shadow of a given radius spreads before it is invisible.
    ///
    /// Measured, not derived. `shadow(radius:)` blurs with roughly `radius / 2`
    /// standard deviation, so the textbook answer is 3σ — `1.5 × radius` — but the
    /// real tail is fatter than a clean Gaussian and at `1.5 ×` the shadow is still
    /// ~1/255 dark where it gets cut. `2 ×` puts the truncation below one 8-bit
    /// level, which is the only threshold that matters: below it, quantisation
    /// erases the edge and there is nothing left to see.
    ///
    /// Worth over-reserving, because the failure is asymmetric. Too much margin
    /// costs a few transparent points in a window that is already mostly
    /// transparent and excluded from hit testing. Too little truncates the falloff
    /// mid-slope and rules a straight line across the soft edge — which reads as a
    /// rendering bug, not as a number being slightly small.
    static let shadowSpreadFactor: CGFloat = 2.0

    /// The wide, soft pass. This is the one you see.
    var ambientShadow: ShadowLayer {
        ShadowLayer(
            color: shadowColor.opacity(0.72),
            radius: max(0, shadowRadius),
            offsetY: shadowOffsetY
        )
    }

    /// A tight pass hugging the silhouette, at a fraction of the offset.
    ///
    /// Without it a wide blur reads as a uniform grey halo and the panel looks
    /// like it is hovering an inch off the screen; the contact pass is what puts
    /// it *on* the display. Two cheap passes beat one radius trying to do both
    /// jobs, which is the whole reason the drawn shadow is derived rather than
    /// taken literally from `shadowRadius`.
    var contactShadow: ShadowLayer {
        ShadowLayer(
            color: shadowColor.opacity(0.55),
            radius: max(0, shadowRadius) * 0.30,
            offsetY: shadowOffsetY * 0.30
        )
    }

    /// How far the shadow reaches sideways past the silhouette.
    var shadowReachHorizontal: CGFloat {
        ambientShadow.radius * Self.shadowSpreadFactor
    }

    /// How far the shadow reaches below the silhouette. The offset pushes it down,
    /// so this is always the larger of the two.
    var shadowReachBelow: CGFloat {
        ambientShadow.radius * Self.shadowSpreadFactor + max(0, ambientShadow.offsetY)
    }

    /// The colour of the physical notch: pure black, because the housing emits no
    /// light. Match this to make an island read as part of the hardware, and use
    /// it when mocking a cutout in a preview.
    static let deviceCutout = Color.black

    /// Merges with the hardware. Pure black ink, near-white content.
    static let standard = NotchStyle()

    /// Ink lifted just off black, with warm off-white content.
    ///
    /// A deliberate design choice rather than a hardware match: it reads as its
    /// own surface beside the cutout, which is the point if your island is meant
    /// to look like an object rather than part of the bezel. Expect a visible
    /// seam where it meets a real notch — that is the trade, not a bug.
    static let warmPaper = NotchStyle(
        ink: Color(red: 0x0D / 255, green: 0x0D / 255, blue: 0x0F / 255),
        foreground: Color(red: 0xF1 / 255, green: 0xEA / 255, blue: 0xD9 / 255)
    )

    /// Deeper, wider shadow, for islands that must stay legible over bright or
    /// busy wallpapers.
    ///
    /// Reaches further than the default insets reserve, which is fine — the window
    /// grows to fit it. See `NotchConfiguration.shadowInsets(fitting:)`.
    static let contrast = NotchStyle(
        shadowColor: Color.black.opacity(0.55),
        shadowRadius: 40,
        shadowOffsetY: 22
    )

    /// Translucent. Looks great over static wallpaper and noticeably worse over
    /// video or fast-scrolling content behind it, so try it before committing.
    /// Apply the material yourself in your content; this only softens the ink.
    ///
    /// Note this necessarily breaks the flush-to-bezel merge, since translucent
    /// ink cannot match opaque housing. Fine on external displays, visibly odd
    /// beside a real cutout.
    static let translucent = NotchStyle(
        ink: Color.black.opacity(0.72)
    )
}
