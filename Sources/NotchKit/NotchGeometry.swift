import AppKit

// MARK: - NotchPhase

/// The three visual states an island can be in.
///
/// Deliberately small. Every extra phase multiplies the animation matrix you
/// have to reason about, and users can only perceive a handful of distinct
/// states in a 40pt-tall strip.
public enum NotchPhase: Equatable, Sendable {
    /// Resting. A pill hugging the top edge.
    case collapsed
    /// Open. The full panel is showing.
    case expanded
    /// A brief scale bump to draw the eye, then back to `.collapsed`.
    /// Use for "something happened" without stealing focus.
    case peeking
}

/// Why the island opened. Drives policy, not looks: a hover-opened panel
/// should close when the pointer leaves, a click-opened one should not.
public enum NotchExpandReason: Equatable, Sendable {
    case click
    case hover
    case programmatic
    case launch
}

// MARK: - NotchGeometry

/// Where the island lives on one screen.
///
/// Every field is plain data and every derivation is a `static` pure function,
/// so the whole layout system is unit-testable without a MacBook attached.
/// This matters more than it sounds: notch geometry bugs only reproduce on
/// specific hardware + menu-bar settings, and you cannot afford to discover
/// them by hand-testing on four machines.
public struct NotchGeometry: Equatable, Sendable {
    /// Full screen bounds, AppKit coordinates (origin bottom-left).
    public var screenFrame: CGRect

    /// Height of the collapsed island. On notched hardware this *equals* the
    /// physical notch height so the pill sits flush with the cutout's bottom edge.
    public var collapsedHeight: CGFloat

    /// Width of the hardware cutout, or a simulated width on plain displays.
    public var notchWidth: CGFloat

    /// True when this screen has a real hardware notch.
    public var hasPhysicalNotch: Bool

    public init(
        screenFrame: CGRect,
        collapsedHeight: CGFloat,
        notchWidth: CGFloat,
        hasPhysicalNotch: Bool
    ) {
        self.screenFrame = screenFrame
        self.collapsedHeight = collapsedHeight
        self.notchWidth = notchWidth
        self.hasPhysicalNotch = hasPhysicalNotch
    }

    // MARK: Derived rects

    /// The hardware cutout's rect (or its simulated stand-in), top-centered.
    public var notchRect: CGRect {
        CGRect(
            x: screenFrame.midX - notchWidth / 2,
            y: screenFrame.maxY - collapsedHeight,
            width: notchWidth,
            height: collapsedHeight
        )
    }

    /// Hover/click target for the collapsed pill.
    ///
    /// Wider than the visible ink on purpose. Users aim at the notch, not at
    /// your pill, and a target you have to hit precisely reads as broken.
    public func collapsedHitRect(reserve: CGFloat = 44) -> CGRect {
        Self.centeredRect(
            on: notchRect,
            width: notchWidth + reserve * 2,
            height: collapsedHeight
        )
    }

    // MARK: - Pure derivations (test these, not the screen)

    /// Bleed added to the measured cutout width.
    ///
    /// `auxiliaryTop*Area` reports the *usable* menu-bar strips, so the gap
    /// between them is the cutout — but rounding at fractional backing scales
    /// can leave a hairline of desktop showing along the cutout's edge. A
    /// couple of points of bleed is invisible against black ink and removes
    /// the seam entirely.
    public static let cutoutBleed: CGFloat = 4

    /// Stand-in notch for displays without one. Sized near a real MacBook
    /// cutout (~200pt) so the pill doesn't look absurdly wide when it is
    /// fully visible instead of half-hidden behind hardware.
    public static let simulatedNotchWidth: CGFloat = 190
    public static let simulatedNotchHeight: CGFloat = 38

    /// Collapsed height, from the two numbers macOS gives you.
    ///
    /// On notched screens use `safeAreaTop` **directly**. The tempting
    /// `min(safeAreaTop, statusBarHeight)` is wrong: when the menu bar
    /// auto-hides, `statusBarHeight` collapses while the cutout obviously
    /// does not, and the pill ends up shorter than the notch — leaving a
    /// bright sliver of wallpaper inside the cutout.
    public static func collapsedHeight(
        safeAreaTop: CGFloat,
        statusBarHeight: CGFloat
    ) -> CGFloat {
        safeAreaTop > 0 ? safeAreaTop : statusBarHeight
    }

    /// Cutout width from the screen width minus the usable menu-bar strips.
    public static func notchWidth(
        screenWidth: CGFloat,
        auxiliaryLeftWidth: CGFloat,
        auxiliaryRightWidth: CGFloat
    ) -> CGFloat {
        max(0, screenWidth - auxiliaryLeftWidth - auxiliaryRightWidth + cutoutBleed)
    }

    /// A rect of `width` × `height` centered horizontally on `anchor`, sharing
    /// its top edge.
    public static func centeredRect(
        on anchor: CGRect,
        width: CGFloat,
        height: CGFloat
    ) -> CGRect {
        CGRect(
            x: anchor.midX - width / 2,
            y: anchor.maxY - height,
            width: width,
            height: height
        )
    }

    /// Edge-**inclusive** hit test.
    ///
    /// `CGRect.contains` excludes the max edges, which makes the topmost row of
    /// pixels — exactly where the island lives — dead to the pointer. That bug
    /// presents as "hover works everywhere except the very top", which is
    /// maddening to chase. Always use this for island hit testing.
    public static func contains(_ rect: CGRect, _ point: CGPoint) -> Bool {
        point.x >= rect.minX && point.x <= rect.maxX
            && point.y >= rect.minY && point.y <= rect.maxY
    }
}

// Live hardware reads live in `NSScreen+Notch.swift`, which is the only
// impure part of the layout system. Everything above is pure and testable.
