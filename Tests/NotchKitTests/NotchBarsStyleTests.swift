import Testing
import CoreGraphics
import SwiftUI
@testable import NotchKit

struct NotchBarsStyleTests {

    @Test("Bar count comes from the heights, so the two cannot disagree")
    func barCountFollowsLevels() {
        // The alternative — a separate `count` property — is the kind of pairing
        // that silently breaks the first time someone adds a bar and forgets.
        #expect(NotchBarsStyle.steady([0.3, 0.5, 0.3]).barCount == 3)
        #expect(NotchBarsStyle.wave(count: 5).barCount == 5)
        #expect(NotchBarsStyle.steady([]).barCount == 0)
    }

    @Test("Intrinsic width is every bar plus every gap between them")
    func intrinsicWidthCountsGapsNotBars() {
        // n bars have n-1 gaps. Getting this wrong by one gap is invisible at
        // three bars and obvious at ten.
        let style = NotchBarsStyle.wave(count: 4, barWidth: 3, spacing: 2)
        #expect(style.intrinsicWidth == 18) // 4*3 + 3*2

        #expect(NotchBarsStyle.steady([0.5], barWidth: 3, spacing: 2).intrinsicWidth == 3)
        #expect(NotchBarsStyle.steady([]).intrinsicWidth == 0)
    }

    @Test("No peaks means no animation at all, not a paused one")
    func steadyStylesAreNotAnimated() {
        // A resting indicator should cost nothing. `isAnimated` is what the view
        // uses to decide whether to attach a CABasicAnimation, so a false positive
        // here is a layer animating forever behind a static-looking glyph.
        #expect(!NotchBarsStyle.steady([0.4, 0.6]).isAnimated)
        #expect(NotchBarsStyle.wave(count: 3).isAnimated)

        // Peaks that match their levels have nowhere to go either.
        #expect(!NotchBarsStyle(levels: [0.5, 0.5], peaks: [0.5, 0.5]).isAnimated)
        // One bar with somewhere to go is enough.
        #expect(NotchBarsStyle(levels: [0.5, 0.5], peaks: [0.5, 1.0]).isAnimated)
    }

    @Test("Heights clamp to 0...1 and out-of-range indices stay silent")
    func accessorsAreSafeAndClamped() {
        // A style assembled from live data (audio levels, progress) should degrade
        // to a sensible bar rather than trap or draw outside its box.
        let style = NotchBarsStyle(levels: [-2, 0.5, 40], peaks: [99, -1])

        #expect(style.level(at: 0) == 0)
        #expect(style.level(at: 1) == 0.5)
        #expect(style.level(at: 2) == 1)
        #expect(style.level(at: 99) == 0)

        #expect(style.peak(at: 0) == 1)
        #expect(style.peak(at: 1) == 0)
        // `peaks` is shorter than `levels`: bar 2 falls back to its own level,
        // which makes it static rather than crashing.
        #expect(style.peak(at: 2) == style.level(at: 2))
    }

    @Test("A negative bar count cannot produce a negative-width view")
    func negativeCountIsClamped() {
        let style = NotchBarsStyle.wave(count: -3)
        #expect(style.barCount == 0)
        #expect(style.intrinsicWidth == 0)
    }
}

struct NotchExpandedTopReserveTests {

    @Test("Reserve policies differ only where a cutout actually blocks content")
    func reservePolicies() {
        let pill: CGFloat = 38

        // The default: give the space back where nothing is in the way.
        #expect(NotchExpandedTopReserve.cutoutOnly.resolved(collapsedHeight: pill, hasPhysicalNotch: true) == 38)
        #expect(NotchExpandedTopReserve.cutoutOnly.resolved(collapsedHeight: pill, hasPhysicalNotch: false) == 0)

        // Trades that space for a layout identical on every display.
        #expect(NotchExpandedTopReserve.always.resolved(collapsedHeight: pill, hasPhysicalNotch: false) == 38)

        #expect(NotchExpandedTopReserve.fixed(60).resolved(collapsedHeight: pill, hasPhysicalNotch: true) == 60)
        #expect(NotchExpandedTopReserve.none.resolved(collapsedHeight: pill, hasPhysicalNotch: true) == 0)
    }

    @Test("A negative height cannot push content off the top of the panel")
    func reserveNeverGoesNegative() {
        #expect(NotchExpandedTopReserve.fixed(-40).resolved(collapsedHeight: 38, hasPhysicalNotch: true) == 0)
        #expect(NotchExpandedTopReserve.always.resolved(collapsedHeight: -10, hasPhysicalNotch: true) == 0)
    }

    @Test("The canvas preset really does give content the whole panel")
    func canvasPresetIsFullBleed() {
        let config = NotchConfiguration.canvas
        #expect(config.expandedTopReserve == NotchExpandedTopReserve.none)
        #expect(config.expandedContentInsets == EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    @Test("Standard configuration reserves the cutout row and pads for the taper")
    func standardStillProtectsContent() {
        // The flexibility above must not have quietly loosened the safe default.
        let config = NotchConfiguration.standard
        #expect(config.expandedTopReserve == .cutoutOnly)
        #expect(config.expandedContentInsets.leading >= config.expandedTopCornerRadius)
    }
}
