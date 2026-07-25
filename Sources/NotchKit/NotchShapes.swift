import SwiftUI

// MARK: - NotchShape

/// The island silhouette, in every state.
///
/// Top corners curl **inward** (concave), bottom corners bulge **outward**. The
/// inward top corners are the whole trick: a plain rounded rectangle hanging off
/// the top edge reads as a floating tooltip, while concave top corners read as the
/// screen bezel *flowing* into the panel — which is why the shape merges
/// seamlessly with a physical notch.
///
/// ```
///   ╭──────────────╮   ← plain rounded rect: looks pasted on
///
///   ╰──────────────╯   ← NotchShape: bezel curls in, panel bulges out
///    ‾‾‾‾‾‾‾‾‾‾‾‾‾‾
/// ```
///
/// ## Construction
///
/// Every corner is the same thing: an ordinary fillet of a corner that would
/// otherwise be sharp. Take the top-left. The top edge runs the full width along
/// `y = minY`; the left wall stands at `x = minX + r`. Extend both and they cross
/// at `(minX + r, minY)`. Round that crossing off with a quadratic whose control
/// point *is* the crossing, and the curve leaves the top edge horizontally and
/// meets the wall vertically — tangent to both runs, for free, with no
/// trigonometry. That is the standard corner-fillet recipe, and it is the only
/// construction in this file.
///
/// The interesting part is the sign. For the top corners the crossing point lies
/// on the **interior** side of the line joining the two tangent points, and a
/// quadratic always bends toward its control point — so the outline gets pulled
/// inward and the bezel appears to curl into the panel. For the bottom corners the
/// crossing lies **outside**, so the identical rule bulges the outline out
/// instead. One rule, one traversal, no special cases; concave versus convex is
/// decided entirely by which side of the shape the crossing happens to fall on.
///
/// Get that sign wrong and the shape fails in a way that is easy to miss in review
/// and unmistakable on screen: curve the top corners the *other* way and the panel
/// flares out wider than its own top edge, reading as a bite taken out of the
/// bezel rather than the bezel flowing in. `topCurlBendsInward` in the tests pins
/// the direction so that mistake cannot come back.
///
/// ## One shape for both states
///
/// At `topCornerRadius == 0` the top fillets collapse to zero length and this
/// becomes a **flat-topped pill** — exactly the collapsed resting shape. So the
/// whole collapsed → expanded transition is four interpolating numbers (two radii,
/// a width, a height) on a *single* shape, with no swap between shape types.
///
/// That is what makes the morph a morph. Cross-fading a pill view into a panel
/// view can only ever read as a switch, because at no point is there one object
/// changing form — there are two objects trading places. See
/// `docs/architecture.md` → "The morph".
public struct NotchShape: Shape {
    /// Concave inward curl at the top corners. `0` gives a flat top (pill).
    public var topCornerRadius: CGFloat
    /// Convex outward round at the bottom corners.
    public var bottomCornerRadius: CGFloat

    public init(topCornerRadius: CGFloat = 22, bottomCornerRadius: CGFloat = 22) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    /// Both radii interpolate, so a shape change is a real animation rather than a
    /// jump cut. Without this SwiftUI snaps between paths.
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    /// Radii that are guaranteed to produce a non-self-intersecting outline.
    ///
    /// Mid-morph the rect can be far smaller than the radii it was asked for, and
    /// an un-clamped outline crosses over itself — a brief bow-tie flicker that is
    /// very hard to attribute after the fact. Clamping the top radius to a quarter
    /// of the height has a happy side effect: at pill height the curl is small
    /// regardless of what you asked for, so the concave corners *arrive* as the
    /// panel grows tall enough to carry them.
    static func resolvedRadii(in rect: CGRect, top: CGFloat, bottom: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        let r = max(0, min(top, rect.width / 4, rect.height / 4))
        // Leave room for both bottom fillets between the side walls, and for the
        // wall segment between the top curl and the bottom fillet.
        let b = max(0, min(bottom, (rect.width - 2 * r) / 2, rect.height - r))
        return (r, b)
    }

    /// One filleted corner: where the outline leaves its straight run, the sharp
    /// crossing that run makes with the next one, and where it rejoins.
    private struct Turn {
        let exit: CGPoint
        let crossing: CGPoint
        let entry: CGPoint
    }

    public func path(in rect: CGRect) -> Path {
        let (r, b) = Self.resolvedRadii(in: rect, top: topCornerRadius, bottom: bottomCornerRadius)

        // Side walls sit inboard of the bounding box by the top radius. The top
        // edge still spans the full width; the curl is what connects the two.
        let leftWall = rect.minX + r
        let rightWall = rect.maxX - r

        let turns = [
            // Top-left: leaves the full-width top edge, curls in to the left wall.
            Turn(exit: CGPoint(x: rect.minX, y: rect.minY),
                 crossing: CGPoint(x: leftWall, y: rect.minY),
                 entry: CGPoint(x: leftWall, y: rect.minY + r)),
            // Bottom-left.
            Turn(exit: CGPoint(x: leftWall, y: rect.maxY - b),
                 crossing: CGPoint(x: leftWall, y: rect.maxY),
                 entry: CGPoint(x: leftWall + b, y: rect.maxY)),
            // Bottom-right.
            Turn(exit: CGPoint(x: rightWall - b, y: rect.maxY),
                 crossing: CGPoint(x: rightWall, y: rect.maxY),
                 entry: CGPoint(x: rightWall, y: rect.maxY - b)),
            // Top-right: mirror of the top-left curl, back out to the top edge.
            Turn(exit: CGPoint(x: rightWall, y: rect.minY + r),
                 crossing: CGPoint(x: rightWall, y: rect.minY),
                 entry: CGPoint(x: rect.maxX, y: rect.minY)),
        ]

        var path = Path()
        path.move(to: turns[0].exit)
        for turn in turns {
            // Straight run into the corner, then the fillet across it. At radius 0
            // both collapse to zero length, which is how the flat-topped pill falls
            // out of the same loop instead of needing its own branch.
            path.addLine(to: turn.exit)
            path.addQuadCurve(to: turn.entry, control: turn.crossing)
        }
        // Closing the subpath draws the top edge back to the start.
        path.closeSubpath()
        return path
    }
}

public extension NotchShape {

    /// The collapsed resting silhouette: flat top, semicircular bottom.
    ///
    /// A full semicircle (`height / 2`) is what makes the pill read as one
    /// continuous blob rather than a rounded box.
    static func pill(height: CGFloat) -> NotchShape {
        NotchShape(topCornerRadius: 0, bottomCornerRadius: height / 2)
    }

    /// The expanded silhouette.
    ///
    /// Pass `topCornerRadius: 0` on displays without a hardware cutout — there is
    /// nothing there to fuse with, and concave corners on a standalone panel look
    /// like a rendering fault.
    static func panel(topCornerRadius: CGFloat, bottomCornerRadius: CGFloat) -> NotchShape {
        NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius
        )
    }
}

// MARK: - NotchPillShape

/// A standalone flat-top, round-bottom pill.
///
/// `NotchShape.pill(height:)` is equivalent and is what the island itself uses,
/// since sharing one shape type is what allows the morph. Reach for this only
/// where a pill is genuinely static and unrelated to the island's geometry —
/// mocking the physical cutout in a settings preview, for instance.
///
/// It delegates to `NotchShape` rather than reaching for
/// `UnevenRoundedRectangle`, which would be shorter but draws corners a few
/// percent rounder than the island's own. Two pills that are almost the same
/// looks like a bug in whichever one you are not currently looking at.
public struct NotchPillShape: Shape {
    /// `nil` means a full semicircle (`height / 2`).
    public var cornerRadius: CGFloat?

    public init(cornerRadius: CGFloat? = nil) {
        self.cornerRadius = cornerRadius
    }

    public var animatableData: CGFloat {
        get { cornerRadius ?? 0 }
        set { cornerRadius = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        NotchShape(
            topCornerRadius: 0,
            bottomCornerRadius: cornerRadius ?? rect.height / 2
        )
        .path(in: rect)
    }
}
