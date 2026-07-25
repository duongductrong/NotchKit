import CoreGraphics

// MARK: - NotchCollapsedWidth

/// How wide to draw the collapsed pill.
///
/// The two cases exist because notched and un-notched displays want genuinely
/// different behaviour, and a single number cannot serve both. On a MacBook the
/// pill must wrap the cutout to merge with it. On an external display there is no
/// cutout, so wrapping a *simulated* one just produces an arbitrarily wide pill
/// with empty space in the middle.
public enum NotchCollapsedWidth: Equatable, Sendable {

    /// Wrap the hardware cutout, extending `reserve` points past each side.
    ///
    /// The reserve is where your content goes — the middle is behind the cutout.
    /// This is the right choice on notched hardware, where pill and cutout are
    /// both black and read as one continuous shape.
    case wrapCutout(reserve: CGFloat)

    /// A fixed width, ignoring the cutout entirely.
    ///
    /// Right for external displays, and for any island that should be sized to its
    /// content rather than to hardware. To size to content, measure it and feed the
    /// result in here.
    case fixed(CGFloat)

    /// Resolves against live geometry.
    public func resolved(notchWidth: CGFloat) -> CGFloat {
        switch self {
        case let .wrapCutout(reserve): notchWidth + reserve * 2
        case let .fixed(width): max(0, width)
        }
    }

    /// Usable width on each side of the cutout, given a resolved pill width.
    ///
    /// On a `.fixed` pill with no cutout the whole width is usable, so this returns
    /// half of it — one gutter per side.
    public func gutterWidth(notchWidth: CGFloat) -> CGFloat {
        let total = resolved(notchWidth: notchWidth)
        switch self {
        case let .wrapCutout(reserve): return reserve
        case .fixed: return max(0, (total - notchWidth) / 2)
        }
    }
}
