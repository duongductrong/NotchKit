import CoreGraphics
@testable import NotchKit
import Testing

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
        let topEdge = CGPoint(x: 150, y: 238) // exactly rect.maxY
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

    /// A shadow small enough that the configured inset is always the larger of the
    /// two, so these cases pin the margin arithmetic rather than the max().
    private static let tightShadow = NotchStyle(shadowRadius: 4, shadowOffsetY: 2)

    @Test("Window size adds shadow room to the content box")
    func windowSizeIncludesShadowRoom() {
        let config = NotchConfiguration(
            expandedSize: CGSize(width: 540, height: 260),
            shadowInsetHorizontal: 18,
            shadowInsetBottom: 22
        )

        let size = config.windowSize(collapsedHeight: 38, style: Self.tightShadow)
        #expect(size.width == 576) // 540 content + 18 shadow margin per side
        #expect(size.height == 320) // 38 cutout + 260 content + 22 shadow
    }

    @Test("Content rect strips the shadow margin from any window-sized rect")
    func contentRectStripsShadowMargin() {
        let config = NotchConfiguration(shadowInsetHorizontal: 18, shadowInsetBottom: 22)
        let bounds = CGRect(x: 0, y: 0, width: 576, height: 320)
        let content = config.contentRect(in: bounds, style: Self.tightShadow)

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

        let fromView = config.contentRect(in: viewBounds, style: Self.tightShadow)
        let fromScreen = config.contentRect(in: screenFrame, style: Self.tightShadow)

        #expect(fromView.size == fromScreen.size)
        #expect(fromScreen.minX - screenFrame.minX == fromView.minX - viewBounds.minX)
        #expect(fromScreen.minY - screenFrame.minY == fromView.minY - viewBounds.minY)
    }

    // MARK: Shadow room

    @Test("A shadow wider than the configured inset grows the window instead of clipping")
    func shadowRoomGrowsToFitAWideShadow() {
        // The regression this guards is the one that is invisible in code review
        // and unmistakable on screen: the falloff runs to 1.5x the radius, so a
        // margin set to the radius truncates the outer third mid-slope and rules a
        // straight line across the soft edge.
        let config = NotchConfiguration(
            expandedSize: CGSize(width: 540, height: 260),
            shadowInsetHorizontal: 18,
            shadowInsetBottom: 22
        )
        let wide = NotchStyle(shadowRadius: 40, shadowOffsetY: 22)

        let insets = config.shadowInsets(fitting: wide)
        #expect(insets.horizontal == 80) // 40 * 2, not 40
        #expect(insets.bottom == 102) // 80 + 22 of offset

        let size = config.windowSize(collapsedHeight: 38, style: wide)
        let expectedWidth: CGFloat = 540 + 80 * 2
        let expectedHeight: CGFloat = 38 + 260 + 102
        #expect(size.width == expectedWidth)
        #expect(size.height == expectedHeight)
    }

    @Test("Reserved room never drops below the configured floor")
    func configuredInsetIsAFloor() {
        let config = NotchConfiguration(shadowInsetHorizontal: 90, shadowInsetBottom: 100)
        let insets = config.shadowInsets(fitting: Self.tightShadow)

        #expect(insets.horizontal == 90)
        #expect(insets.bottom == 100)
    }

    @Test("Every built-in style fits inside the room every built-in config reserves")
    func builtInPresetsNeverClipTheirShadow() {
        let configs: [NotchConfiguration] = [
            .standard, .clickOnly, .statusOnly, .canvas, .standalone(),
        ]
        let styles: [NotchStyle] = [.standard, .warmPaper, .contrast, .translucent]

        for config in configs {
            for style in styles {
                let insets = config.shadowInsets(fitting: style)
                #expect(insets.horizontal >= style.shadowReachHorizontal)
                #expect(insets.bottom >= style.shadowReachBelow)
            }
        }
    }

    @Test("Shadow reach runs past the radius, and further below than sideways")
    func shadowReachAccountsForBlurAndOffset() {
        let style = NotchStyle(shadowRadius: 30, shadowOffsetY: 16)

        #expect(style.shadowReachHorizontal == 60)
        // The offset only pushes the shadow down, so the extra room is needed at
        // the bottom and nowhere else.
        #expect(style.shadowReachBelow - style.shadowReachHorizontal == 16)
    }

    @Test("A zeroed shadow asks for no room at all")
    func noShadowNeedsNoRoom() {
        let style = NotchStyle(shadowRadius: 0, shadowOffsetY: 0)

        #expect(style.shadowReachHorizontal == 0)
        #expect(style.shadowReachBelow == 0)
    }

    @Test("The contact pass hugs the silhouette more tightly than the ambient one")
    func contactShadowIsTighterThanAmbient() {
        // Two passes exist so one radius does not have to be both soft and
        // grounded. If they ever converge, the contact pass has stopped earning
        // its cost and the panel will read as floating.
        let style = NotchStyle.standard

        #expect(style.contactShadow.radius < style.ambientShadow.radius)
        #expect(style.contactShadow.offsetY < style.ambientShadow.offsetY)
        // The ambient pass is what the reserved room is sized from, so it must be
        // the one that reaches furthest.
        #expect(style.ambientShadow.radius == style.shadowRadius)
    }
}
