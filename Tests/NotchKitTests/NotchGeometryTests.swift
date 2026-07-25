import Testing
import CoreGraphics
@testable import NotchKit

/// Notch geometry bugs reproduce only on specific hardware with specific
/// menu-bar settings, which makes them expensive to find by hand and easy to
/// re-introduce. Because every derivation in `NotchGeometry` is a pure function,
/// all of it can be pinned here with no display attached.
struct NotchGeometryTests {

    // MARK: Collapsed height

    @Test("Notched screens use the cutout height verbatim")
    func notchedUsesSafeArea() {
        #expect(NotchGeometry.collapsedHeight(safeAreaTop: 38, statusBarHeight: 24) == 38)
    }

    @Test("An auto-hidden menu bar must not shrink the island below the cutout")
    func autoHiddenMenuBarDoesNotShrinkIsland() {
        // The regression this guards: `min(safeAreaTop, statusBarHeight)` looks
        // reasonable and is wrong. When the menu bar auto-hides, the reported
        // status-bar height collapses while the physical cutout obviously does
        // not — and the island ends up shorter than the notch, leaving a bright
        // sliver of wallpaper visible inside the cutout.
        let height = NotchGeometry.collapsedHeight(safeAreaTop: 38, statusBarHeight: 0)
        #expect(height == 38)
    }

    @Test("Screens without a cutout fall back to the status bar height")
    func plainScreenUsesStatusBar() {
        #expect(NotchGeometry.collapsedHeight(safeAreaTop: 0, statusBarHeight: 24) == 24)
    }

    // MARK: Cutout width

    @Test("Cutout width is the gap between the menu bar strips, plus bleed")
    func cutoutWidthFromAuxiliaryAreas() {
        let width = NotchGeometry.notchWidth(
            screenWidth: 1512,
            auxiliaryLeftWidth: 644,
            auxiliaryRightWidth: 644
        )
        #expect(width == 224 + NotchGeometry.cutoutBleed)
    }

    @Test("Cutout width never goes negative on odd display reports")
    func cutoutWidthClampsAtZero() {
        let width = NotchGeometry.notchWidth(
            screenWidth: 100,
            auxiliaryLeftWidth: 200,
            auxiliaryRightWidth: 200
        )
        #expect(width == 0)
    }

    // MARK: Placement

    @Test("Centred rects share the anchor's top edge")
    func centeredRectHangsFromTop() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let rect = NotchGeometry.centeredRect(on: screen, width: 300, height: 38)

        #expect(rect.midX == screen.midX)
        #expect(rect.maxY == screen.maxY)
        #expect(rect.width == 300)
        #expect(rect.height == 38)
    }

    @Test("Notch rect is centred on the screen and flush to the top")
    func notchRectPlacement() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            collapsedHeight: 38,
            notchWidth: 228,
            hasPhysicalNotch: true
        )

        #expect(geometry.notchRect.midX == 756)
        #expect(geometry.notchRect.maxY == 982)
        #expect(geometry.notchRect.height == 38)
    }

    @Test("Collapsed hit target extends past the cutout on both sides")
    func collapsedHitRectAddsReserve() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            collapsedHeight: 38,
            notchWidth: 228,
            hasPhysicalNotch: true
        )

        let rect = geometry.collapsedHitRect(reserve: 44)
        // Write comparison values as plain CGFloat literals. Inside `#expect`,
        // an all-integer-literal expression such as `228 + 88` is inferred as
        // `Int` and the mixed comparison against a CGFloat fails even when the
        // numbers match — a confusing failure that looks like a real bug.
        #expect(rect.width == 316) // 228 cutout + 44 reserve on each side
        #expect(rect.midX == geometry.notchRect.midX)
    }

    @Test("Placement respects a non-zero screen origin (second display)")
    func placementOnOffsetScreen() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: -1920, y: 240, width: 1920, height: 1080),
            collapsedHeight: 24,
            notchWidth: 190,
            hasPhysicalNotch: false
        )

        #expect(geometry.notchRect.midX == -960)
        #expect(geometry.notchRect.maxY == 1320)
    }

    // MARK: Hit testing

    @Test("Hit testing includes the max edges, unlike CGRect.contains")
    func hitTestIsEdgeInclusive() {
        let rect = CGRect(x: 100, y: 200, width: 224, height: 38)
        let topEdge = CGPoint(x: 150, y: 238)   // exactly rect.maxY
        let rightEdge = CGPoint(x: 324, y: 220) // exactly rect.maxX

        #expect(NotchGeometry.contains(rect, topEdge))
        #expect(NotchGeometry.contains(rect, rightEdge))

        // The reason this helper exists at all. `CGRect.contains` excludes the
        // max edges, which kills the topmost row of pixels — precisely where the
        // island lives. It presents as "hover works everywhere except the very
        // top", which is maddening to track down.
        #expect(!rect.contains(topEdge))

        #expect(!NotchGeometry.contains(rect, CGPoint(x: 325, y: 220)))
        #expect(!NotchGeometry.contains(rect, CGPoint(x: 150, y: 239)))
    }

    // MARK: Window sizing

    @Test("Window size adds shadow room to the content box")
    func windowSizeIncludesShadowRoom() {
        let config = NotchConfiguration(
            expandedSize: CGSize(width: 540, height: 260),
            shadowInsetHorizontal: 18,
            shadowInsetBottom: 22
        )

        let size = config.windowSize(collapsedHeight: 38)
        #expect(size.width == 576)  // 540 content + 18 shadow margin per side
        #expect(size.height == 320) // 38 cutout + 260 content + 22 shadow
    }

    @Test("Content rect strips the shadow margin from any window-sized rect")
    func contentRectStripsShadowMargin() {
        let config = NotchConfiguration(shadowInsetHorizontal: 18, shadowInsetBottom: 22)
        let bounds = CGRect(x: 0, y: 0, width: 576, height: 320)
        let content = config.contentRect(in: bounds)

        #expect(content.minX == 18)
        #expect(content.width == 540)
        #expect(content.minY == 22)
        // The island hangs off the top, so the margin is taken from the bottom
        // only — the content still reaches the very top edge.
        #expect(content.maxY == 320)
    }

    @Test("Content rect maths is identical in view and screen space")
    func contentRectIsCoordinateSpaceAgnostic() {
        // Both hit-test paths reuse one function; this is what makes that safe.
        let config = NotchConfiguration(shadowInsetHorizontal: 18, shadowInsetBottom: 22)
        let viewBounds = CGRect(x: 0, y: 0, width: 576, height: 320)
        let screenFrame = CGRect(x: 468, y: 662, width: 576, height: 320)

        let fromView = config.contentRect(in: viewBounds)
        let fromScreen = config.contentRect(in: screenFrame)

        #expect(fromView.size == fromScreen.size)
        #expect(fromScreen.minX - screenFrame.minX == fromView.minX - viewBounds.minX)
        #expect(fromScreen.minY - screenFrame.minY == fromView.minY - viewBounds.minY)
    }
}
