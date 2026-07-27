import SwiftUI

/// Lays content on either side of the physical cutout.
///
/// This is the non-obvious constraint of notch UI: on a MacBook, the centre of
/// your collapsed pill is *behind the hardware*. Anything you put there is
/// invisible — and invisible **only on notched Macs**, so it looks perfect on the
/// external monitor you developed against and broken on the machine you shipped
/// it for. Reserve the cutout explicitly and the problem disappears.
///
/// On displays without a cutout, pass `cutoutWidth: 0`; this collapses into an
/// ordinary leading/trailing bar with no special-casing at the call site.
///
/// ```swift
/// NotchCutoutLayout(
///     cutoutWidth: presenter.geometry.hasPhysicalNotch ? presenter.geometry.notchWidth : 0,
///     gutterWidth: presenter.collapsedGutterWidth,
///     pillHeight: presenter.geometry.collapsedHeight
/// ) {
///     NotchBars(.wave())
/// } trailing: {
///     Text("3")
/// }
/// ```
public struct NotchCutoutLayout<Leading: View, Trailing: View>: View {
    /// Width of the hardware cutout to reserve.
    public var cutoutWidth: CGFloat

    /// Usable width on each side of the cutout.
    public var gutterWidth: CGFloat

    /// Height of the pill. Used to derive a safe `edgeInset`.
    public var pillHeight: CGFloat

    /// Inset pulling content away from the rounded outer edges. `nil` derives the
    /// provably-safe value — see `resolvedEdgeInset`.
    public var edgeInset: CGFloat?

    /// Vertical placement of both sides within the pill.
    ///
    /// `.center` is right for glyphs and single lines. `.firstTextBaseline` is
    /// what you want when the two sides hold text at different sizes and the
    /// mismatch is showing.
    public var alignment: VerticalAlignment

    @ViewBuilder public var leading: () -> Leading
    @ViewBuilder public var trailing: () -> Trailing

    public init(
        cutoutWidth: CGFloat,
        gutterWidth: CGFloat,
        pillHeight: CGFloat,
        edgeInset: CGFloat? = nil,
        alignment: VerticalAlignment = .center,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.cutoutWidth = cutoutWidth
        self.gutterWidth = gutterWidth
        self.pillHeight = pillHeight
        self.edgeInset = edgeInset
        self.alignment = alignment
        self.leading = leading
        self.trailing = trailing
    }

    /// Half the pill height, i.e. the bottom corner radius.
    ///
    /// This is the smallest inset that is safe for content of *any* height, and
    /// the reasoning is worth keeping: the pill's bottom corner is a circle of
    /// radius `r = height / 2` centred at `(r, height - r)`. Inset content by `r`
    /// and it begins exactly at that centre's x — so it is to the right of the
    /// circle's widest point at every y, and can never cross the curve no matter
    /// how tall it is.
    ///
    /// A smaller inset can still be fine for short content (a 24pt glyph in a 38pt
    /// pill only needs ~4pt), but it has to be checked against the content height,
    /// and it fails silently at the corners when someone later makes the content
    /// taller. Half-height is the value that stops being a question.
    ///
    /// One caveat since the pill gained a top curl: a curl of `c` shifts the side
    /// walls — and with them the bottom fillet — inboard by `c`, so strictly the
    /// safe inset is `c + height / 2`. In practice the overlap is negligible,
    /// because the fillet only reaches its widest point at the very bottom edge:
    /// at the default 6pt curl in a 38pt pill, half-height clears the curve until
    /// the last ~0.6pt of height. Pass an explicit `edgeInset` if you are placing
    /// something that genuinely runs the full height of the pill into a corner.
    ///
    /// Usable gutter is therefore `gutterWidth - resolvedEdgeInset`. If that is
    /// too tight for your content, widen `NotchConfiguration.collapsedWidth`
    /// rather than shrinking the inset.
    public var resolvedEdgeInset: CGFloat {
        edgeInset ?? pillHeight / 2
    }

    public var body: some View {
        let inset = resolvedEdgeInset

        HStack(alignment: alignment, spacing: 0) {
            leading()
                .frame(width: max(0, gutterWidth - inset), alignment: .leading)
                .padding(.leading, inset)

            // The dead zone. `Color.clear` with a fixed width rather than a
            // `Spacer`, because a flexible spacer lets content creep under the
            // cutout whenever the gutters measure narrower than expected — and
            // that only shows up on real notched hardware.
            Color.clear
                .frame(width: cutoutWidth)
                .allowsHitTesting(false)

            trailing()
                .frame(width: max(0, gutterWidth - inset), alignment: .trailing)
                .padding(.trailing, inset)
        }
    }
}
