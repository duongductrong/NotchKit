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
///     NotchActivityBars(mode: .active, size: 18)
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

    @ViewBuilder public var leading: () -> Leading
    @ViewBuilder public var trailing: () -> Trailing

    public init(
        cutoutWidth: CGFloat,
        gutterWidth: CGFloat,
        pillHeight: CGFloat,
        edgeInset: CGFloat? = nil,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.cutoutWidth = cutoutWidth
        self.gutterWidth = gutterWidth
        self.pillHeight = pillHeight
        self.edgeInset = edgeInset
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
    /// Usable gutter is therefore `gutterWidth - resolvedEdgeInset`. If that is
    /// too tight for your content, widen `NotchConfiguration.collapsedWidth`
    /// rather than shrinking the inset.
    public var resolvedEdgeInset: CGFloat {
        edgeInset ?? pillHeight / 2
    }

    public var body: some View {
        let inset = resolvedEdgeInset

        HStack(spacing: 0) {
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
