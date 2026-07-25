import CoreGraphics
import Foundation
import SwiftUI

/// Everything tunable about an island, in one value type.
public struct NotchConfiguration: Equatable, Sendable {

    // MARK: Size

    /// Size of the expanded panel's *content*, excluding shadow insets.
    ///
    /// This is also the window size, because the window never resizes
    /// (see `NotchPresenter`). Pick the largest panel you will ever show.
    public var expandedSize: CGSize

    /// How wide the collapsed pill is drawn.
    ///
    /// Separate from the hit target on purpose — see `collapsedHitPadding`.
    public var collapsedWidth: NotchCollapsedWidth

    /// Invisible hit-target margin added around the collapsed pill.
    ///
    /// Users aim at the notch, not at your pill; a target you have to hit
    /// precisely reads as broken. Keeping this separate from `collapsedWidth`
    /// means a compact pill can still have a forgiving target, instead of being
    /// forced wide just to be clickable.
    public var collapsedHitPadding: CGFloat

    // MARK: Shadow room

    /// Transparent margin reserved inside the window for the drop shadow.
    ///
    /// The panel draws its own shadow (`NSWindow.hasShadow = false`, because
    /// AppKit's shadow traces the *window* rectangle, not your concave shape,
    /// and would draw a hard-edged box around the island). A SwiftUI shadow
    /// needs room to fall into, and anything outside the window is clipped.
    public var shadowInsetHorizontal: CGFloat
    public var shadowInsetBottom: CGFloat

    // MARK: Corner radii

    public var expandedTopCornerRadius: CGFloat
    public var expandedBottomCornerRadius: CGFloat

    /// Explicit padding for the expanded panel's content. `nil` derives insets
    /// that are guaranteed to clear the silhouette — see `expandedContentInsets`.
    public var expandedContentInsetsOverride: EdgeInsets?

    // MARK: Interaction

    /// Open on hover, not just click.
    public var expandsOnHover: Bool

    /// Delay before a hover opens the island.
    ///
    /// Non-negotiable if `expandsOnHover` is on. The pointer crosses the top of
    /// the screen constantly on the way to the menu bar, and a zero-delay island
    /// that flaps open every time is the single fastest way to make people
    /// uninstall. ~0.15s is long enough to filter transits, short enough to feel
    /// intentional.
    public var hoverOpenDelay: TimeInterval

    /// Grace period before a *pending* hover-open is cancelled.
    ///
    /// The cutout edge is exactly where the pointer jitters, and without this
    /// the open timer restarts on every wobble — so a user holding still near
    /// the edge never triggers it. This is hysteresis, and it is what separates
    /// a hover target that feels solid from one that feels haunted.
    public var hoverCancelGrace: TimeInterval

    /// Collapse when the pointer leaves an island that was opened by hover.
    /// Click-opened islands ignore this — a deliberate open deserves a
    /// deliberate close.
    public var collapsesOnPointerExit: Bool

    /// Close when the user clicks outside, and forward that click to whatever
    /// was underneath. See `NotchPresenter.repostClick`.
    public var collapsesOnOutsideClick: Bool

    /// Light haptic tap when a hover opens the island. Only fires on hardware
    /// with a Force Touch trackpad; a no-op elsewhere.
    public var hapticOnHoverOpen: Bool

    /// How often pointer-move events are sampled, in seconds.
    ///
    /// `mouseMoved` fires far faster than any UI needs. 20Hz is imperceptible
    /// for hit testing and keeps a global event monitor from showing up in
    /// Activity Monitor — which matters, because this monitor runs for your
    /// app's entire lifetime.
    public var pointerSampleInterval: TimeInterval

    public init(
        expandedSize: CGSize = CGSize(width: 540, height: 260),
        collapsedWidth: NotchCollapsedWidth = .wrapCutout(reserve: 44),
        collapsedHitPadding: CGFloat = 6,
        shadowInsetHorizontal: CGFloat = 18,
        shadowInsetBottom: CGFloat = 22,
        expandedTopCornerRadius: CGFloat = 22,
        expandedBottomCornerRadius: CGFloat = 22,
        expandedContentInsetsOverride: EdgeInsets? = nil,
        expandsOnHover: Bool = true,
        hoverOpenDelay: TimeInterval = 0.15,
        hoverCancelGrace: TimeInterval = 0.10,
        collapsesOnPointerExit: Bool = true,
        collapsesOnOutsideClick: Bool = true,
        hapticOnHoverOpen: Bool = true,
        pointerSampleInterval: TimeInterval = 0.05
    ) {
        self.expandedSize = expandedSize
        self.collapsedWidth = collapsedWidth
        self.collapsedHitPadding = collapsedHitPadding
        self.shadowInsetHorizontal = shadowInsetHorizontal
        self.shadowInsetBottom = shadowInsetBottom
        self.expandedTopCornerRadius = expandedTopCornerRadius
        self.expandedBottomCornerRadius = expandedBottomCornerRadius
        self.expandedContentInsetsOverride = expandedContentInsetsOverride
        self.expandsOnHover = expandsOnHover
        self.hoverOpenDelay = hoverOpenDelay
        self.hoverCancelGrace = hoverCancelGrace
        self.collapsesOnPointerExit = collapsesOnPointerExit
        self.collapsesOnOutsideClick = collapsesOnOutsideClick
        self.hapticOnHoverOpen = hapticOnHoverOpen
        self.pointerSampleInterval = pointerSampleInterval
    }

    /// Total window size: content plus the shadow margin.
    public func windowSize(collapsedHeight: CGFloat) -> CGSize {
        CGSize(
            width: expandedSize.width + shadowInsetHorizontal * 2,
            height: collapsedHeight + expandedSize.height + shadowInsetBottom
        )
    }

    /// Padding for the expanded panel's content, derived so it always clears the
    /// silhouette.
    ///
    /// The non-obvious part is the horizontal inset. A concave top corner does not
    /// clip the corner off — it makes the panel **widest at its very top edge**,
    /// tapering inward until the side wall settles at `x = topRadius` by
    /// `y = topRadius`. Below that the panel body is `2 × topRadius` narrower than
    /// its bounding box.
    ///
    /// Since panel content always starts below the reserved cutout row (taller
    /// than the radius), it lives entirely in the narrowed region — so content
    /// padded by a plain 20pt against a 22pt radius is outside the shape and gets
    /// clipped. It clips only along the upper flanks, which is why it reads as a
    /// mysterious rendering glitch rather than a padding mistake.
    ///
    /// The bottom inset keeps content out of the bottom corner curves. Together
    /// with the horizontal inset it guarantees content stays inside the path at
    /// every point.
    ///
    /// The reference implementation lands in the same place from the other
    /// direction: 46pt of horizontal header padding when notch-aware, 18pt when
    /// not — roughly `2 × radius` versus a plain margin.
    public var expandedContentInsets: EdgeInsets {
        if let expandedContentInsetsOverride {
            return expandedContentInsetsOverride
        }
        let horizontal = max(20, expandedTopCornerRadius + 8)
        return EdgeInsets(
            top: 8,
            leading: horizontal,
            bottom: max(14, expandedBottomCornerRadius - 6),
            trailing: horizontal
        )
    }

    /// The opaque, clickable region inside a window-sized rect — i.e. the whole
    /// rect minus the transparent shadow margin.
    ///
    /// Works for both view bounds and a screen-space window frame, because
    /// AppKit uses bottom-left origin for both: the island hangs off the top,
    /// so the shadow margin is the strip along the bottom. One function, two
    /// coordinate spaces, no conversion — used for hit testing in each.
    public func contentRect(in bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.minX + shadowInsetHorizontal,
            y: bounds.minY + shadowInsetBottom,
            width: max(0, bounds.width - shadowInsetHorizontal * 2),
            height: max(0, bounds.height - shadowInsetBottom)
        )
    }
}

public extension NotchConfiguration {

    /// Sensible default: hover-to-open, medium panel.
    static let standard = NotchConfiguration()

    /// Click-only. For islands holding controls users must not open by accident.
    static let clickOnly = NotchConfiguration(
        expandsOnHover: false,
        collapsesOnPointerExit: false
    )

    /// A thin status strip with no real panel — peek and collapsed states only.
    static let statusOnly = NotchConfiguration(
        expandedSize: CGSize(width: 380, height: 96),
        expandsOnHover: false,
        collapsesOnPointerExit: false
    )

    /// For displays with no hardware cutout, where wrapping a *simulated* notch
    /// would just leave a wide pill with an empty middle. Sized to its content
    /// instead — measure yours and set the width.
    static func standalone(pillWidth: CGFloat = 220) -> NotchConfiguration {
        NotchConfiguration(collapsedWidth: .fixed(pillWidth))
    }
}
