import SwiftUI

/// How the island looks, independent of how it moves or where it sits.
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

    /// Inner hairline along the silhouette.
    ///
    /// Without it, a black island on a dark wallpaper has no edge — the panel
    /// dissolves into the desktop and content appears to float in a void. A few
    /// percent of white is invisible on light backgrounds and rescues the
    /// silhouette on dark ones.
    ///
    /// Worth noting the tension with `ink`: the flush-to-bezel look needs pure
    /// black, but pure black is also the hardest to give an edge. The hairline is
    /// what lets you have both.
    public var hairline: Color
    public var hairlineWidth: CGFloat

    /// Drawn in SwiftUI, not by AppKit, so it follows the concave path instead of
    /// boxing the window. Needs `NotchConfiguration.shadowInset*` room to fall
    /// into, and is suppressed while collapsed — a shadow on a pill that is flush
    /// against the bezel makes it look like it is floating in front of the
    /// hardware.
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
        hairline: Color = Color.white.opacity(0.08),
        hairlineWidth: CGFloat = 1,
        shadowColor: Color = Color.black.opacity(0.45),
        shadowRadius: CGFloat = 14,
        shadowOffsetY: CGFloat = 8,
        foreground: Color = Color(white: 0.96),
        colorScheme: ColorScheme? = .dark
    ) {
        self.ink = ink
        self.hairline = hairline
        self.hairlineWidth = hairlineWidth
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.shadowOffsetY = shadowOffsetY
        self.foreground = foreground
        self.colorScheme = colorScheme
    }
}

public extension NotchStyle {
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
        hairline: Color.white.opacity(0.07),
        foreground: Color(red: 0xF1 / 255, green: 0xEA / 255, blue: 0xD9 / 255)
    )

    /// Stronger edge and shadow, for islands that must stay legible over bright
    /// or busy wallpapers.
    static let contrast = NotchStyle(
        hairline: Color.white.opacity(0.16),
        shadowColor: Color.black.opacity(0.60),
        shadowRadius: 20,
        shadowOffsetY: 10
    )

    /// Translucent. Looks great over static wallpaper and noticeably worse over
    /// video or fast-scrolling content behind it, so try it before committing.
    /// Apply the material yourself in your content; this only softens the ink.
    ///
    /// Note this necessarily breaks the flush-to-bezel merge, since translucent
    /// ink cannot match opaque housing. Fine on external displays, visibly odd
    /// beside a real cutout.
    static let translucent = NotchStyle(
        ink: Color.black.opacity(0.72),
        hairline: Color.white.opacity(0.12)
    )
}
