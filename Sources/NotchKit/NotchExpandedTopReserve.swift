import CoreGraphics

/// How much of the expanded panel's top is kept clear of the hardware cutout.
///
/// On a MacBook the top strip of an open panel sits *behind* the notch, so
/// anything drawn there is invisible — and invisible only on notched Macs, which
/// is how it survives development on an external monitor. Reserving a row solves
/// it, but reserving unconditionally throws away real estate on displays where
/// nothing is in the way.
///
/// So this is a policy, not a number, and which one is right depends on what the
/// panel holds. A list wants the space back (`.cutoutOnly`). A layout that must
/// look pixel-identical everywhere wants it reserved always (`.always`). Artwork
/// that reads fine partly occluded wants no reserve at all (`.none`).
public enum NotchExpandedTopReserve: Equatable, Sendable {
    /// Reserve a pill-height row, but only where a cutout actually blocks it.
    /// On a plain display the content gets the space back. The default, because
    /// it is the only option that is never *wrong* — just occasionally different
    /// between displays.
    case cutoutOnly

    /// Always reserve a pill-height row. Costs space on displays with no cutout,
    /// and buys a layout that is identical on every one of them.
    case always

    /// Reserve an exact height. For panels whose own header happens to clear the
    /// cutout already, or that want a deliberate gap larger than the pill.
    case fixed(CGFloat)

    /// Reserve nothing — content owns the whole panel, cutout included. Right for
    /// full-bleed artwork or a blurred backdrop, wrong for anything with text at
    /// the top.
    case none

    public func resolved(collapsedHeight: CGFloat, hasPhysicalNotch: Bool) -> CGFloat {
        switch self {
        case .cutoutOnly: hasPhysicalNotch ? max(0, collapsedHeight) : 0
        case .always: max(0, collapsedHeight)
        case let .fixed(height): max(0, height)
        case .none: 0
        }
    }
}
