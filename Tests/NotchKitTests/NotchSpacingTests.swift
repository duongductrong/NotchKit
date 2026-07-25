import Testing
import CoreGraphics
import SwiftUI
@testable import NotchKit

// MARK: - Spacing

struct NotchSpacingTests {

    @Test("Expanded content clears the inward-pulled side walls")
    func contentInsetsClearConcaveSideWalls() {
        // Concave top corners narrow the panel body by the top radius on each side.
        // Content padded by less than that is outside the shape along the upper
        // flanks — it clips silently and looks like a rendering fault.
        let config = NotchConfiguration(expandedTopCornerRadius: 22)
        #expect(config.expandedContentInsets.leading >= 22)
        #expect(config.expandedContentInsets.trailing >= 22)
    }

    @Test("An explicit inset override wins")
    func insetOverrideWins() {
        let custom = EdgeInsets(top: 1, leading: 2, bottom: 3, trailing: 4)
        let config = NotchConfiguration(expandedContentInsetsOverride: custom)
        #expect(config.expandedContentInsets == custom)
    }

    @Test("wrapCutout sizes the pill around the hardware; fixed ignores it")
    func collapsedWidthStrategies() {
        let cutout: CGFloat = 224

        #expect(NotchCollapsedWidth.wrapCutout(reserve: 44).resolved(notchWidth: cutout) == 312)
        #expect(NotchCollapsedWidth.wrapCutout(reserve: 44).gutterWidth(notchWidth: cutout) == 44)

        // A fixed pill ignores the cutout entirely — the right behaviour on a
        // display that has none, where wrapping a simulated notch would leave a
        // wide pill with an empty middle.
        #expect(NotchCollapsedWidth.fixed(220).resolved(notchWidth: 0) == 220)
        #expect(NotchCollapsedWidth.fixed(220).gutterWidth(notchWidth: 0) == 110)
    }

    @Test("Hit target is wider than the drawn pill")
    func hitTargetExceedsDrawnPill() {
        // Decoupling the two is the point: a compact pill should still be easy to
        // hit, without being forced wide just to be clickable.
        let config = NotchConfiguration(
            collapsedWidth: .fixed(120),
            collapsedHitPadding: 6
        )
        let drawn = config.collapsedWidth.resolved(notchWidth: 224)
        #expect(drawn == 120)
        #expect(drawn + config.collapsedHitPadding * 2 > drawn)
    }

    @Test("Pill edge inset defaults to half the height, safe at any content size")
    func pillEdgeInsetIsProvablySafe() {
        // At half-height the inset equals the corner radius, so content starts at the
        // corner circle's centre x — right of its widest point at every y, and
        // therefore inside the path regardless of how tall the content is.
        let layout = NotchCutoutLayout(
            cutoutWidth: 200,
            gutterWidth: 44,
            pillHeight: 38,
            leading: { EmptyView() },
            trailing: { EmptyView() }
        )
        #expect(layout.resolvedEdgeInset == 19)
    }
}
