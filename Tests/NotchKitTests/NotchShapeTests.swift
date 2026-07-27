import CoreGraphics
@testable import NotchKit
import SwiftUI
import Testing

// MARK: - Shapes

struct NotchShapeTests {
    /// The invariant the whole morph rests on.
    ///
    /// At `topCornerRadius == 0` the top fillets collapse to zero length and
    /// `NotchShape` becomes a flat-topped pill. That is what lets one shape
    /// interpolate across the entire collapsed → expanded transition instead of
    /// swapping between two shape types — and a swap is what makes an island read
    /// as switching rather than transforming.
    @Test("A zero top radius degenerates NotchShape into a flat-topped pill")
    func zeroTopRadiusGivesFlatTop() {
        // Panel-sized, so `min(radius, height / 4)` does not quietly clamp the 22pt
        // radius and invalidate the comparison. Only the top radius differs.
        let rect = CGRect(x: 0, y: 0, width: 540, height: 260)

        // By y = 20 a 22pt curl has pulled the boundary almost all the way in to
        // the wall at x = 22, so x = 3 is well outside the concave shape while
        // sitting comfortably inside a flat-topped one.
        let probe = CGPoint(x: 3, y: 20)

        let flat = NotchShape(topCornerRadius: 0, bottomCornerRadius: 22).path(in: rect)
        let concave = NotchShape(topCornerRadius: 22, bottomCornerRadius: 22).path(in: rect)

        #expect(flat.contains(probe))
        #expect(!concave.contains(probe))
    }

    /// Guards the one sign error that ruins this shape.
    ///
    /// The top fillet runs between two tangent points — `(minX, minY)` on the top
    /// edge and `(minX + r, minY + r)` on the wall. Bending it toward the interior
    /// gives the inward curl that fuses with the bezel. Bending it the other way
    /// (an arc *centred* on the corner crossing rather than filleting it) flares
    /// the panel out wider than its own top edge, which reads as a bite chewed out
    /// of the bezel. Both versions are tangent to both runs and both look
    /// plausible in code; only one looks right on a MacBook.
    ///
    /// The chord midpoint separates them cleanly: an inward curl leaves it outside
    /// the shape, an outward flare swallows it.
    @Test("The top curl bends inward, toward the interior")
    func topCurlBendsInward() {
        let r: CGFloat = 22
        let rect = CGRect(x: 0, y: 0, width: 540, height: 260)
        let path = NotchShape(topCornerRadius: r, bottomCornerRadius: 22).path(in: rect)

        #expect(!path.contains(CGPoint(x: r / 2, y: r / 2)))

        // And where the curl lands, the boundary is the wall: just inside is in,
        // just outside is out.
        #expect(path.contains(CGPoint(x: r + 1, y: r)))
        #expect(!path.contains(CGPoint(x: r - 1, y: r)))
    }

    @Test("The top edge stays full width, tapering inward below it")
    func topEdgeSpansFullWidth() {
        // A concave corner does not clip the top-left off. The shape is widest at
        // y = 0 and narrows to `topRadius` by y = topRadius, which is what makes it
        // read as the bezel flowing in rather than as a panel with bitten corners.
        let rect = CGRect(x: 0, y: 0, width: 540, height: 260)
        let path = NotchShape(topCornerRadius: 22, bottomCornerRadius: 22).path(in: rect)

        // Full width where it meets the screen edge...
        #expect(path.boundingRect.minX == rect.minX)
        #expect(path.boundingRect.maxX == rect.maxX)
        // ...and pulled in by the radius on each side once past the curl.
        #expect(!path.contains(CGPoint(x: 10, y: 40)))
        #expect(!path.contains(CGPoint(x: 530, y: 40)))
    }

    @Test("Radii clamp so the outline cannot self-intersect")
    func radiiClampToRect() {
        // Mid-morph the rect can be far smaller than the radii it was asked for.
        // Un-clamped, the outline crosses over itself and flashes a bow-tie.
        let tiny = CGRect(x: 0, y: 0, width: 20, height: 10)
        let (top, bottom) = NotchShape.resolvedRadii(in: tiny, top: 200, bottom: 200)

        #expect(top == 2.5) // height / 4
        #expect(bottom == 7.5) // (width - 2 * top) / 2

        let path = NotchShape(topCornerRadius: 200, bottomCornerRadius: 200).path(in: tiny)
        #expect(!path.isEmpty)
        #expect(path.boundingRect.width <= tiny.width + 0.001)
        #expect(path.boundingRect.height <= tiny.height + 0.001)
    }

    @Test("Pill height clamps the top curl, so a collapsed pill stays near-flat")
    func pillHeightClampsTopRadius() {
        // `height / 4` dominates at pill height: ask for 22pt of curl in a 38pt-tall
        // shape and you get 9.5pt. A useful accident rather than a limitation — the
        // concave curl *arrives* as the panel grows tall enough to carry it, instead
        // of appearing fully formed on frame one.
        let pillRect = CGRect(x: 0, y: 0, width: 312, height: 38)
        let (top, bottom) = NotchShape.resolvedRadii(in: pillRect, top: 22, bottom: 19)

        #expect(top == 9.5)
        #expect(bottom == 19) // semicircular bottom survives the clamp
    }

    @Test("The pill factory is flat-topped unless asked for a curl")
    func pillFactoryValues() {
        #expect(NotchShape.pill(height: 40).topCornerRadius == 0)
        #expect(NotchShape.pill(height: 40).bottomCornerRadius == 20)
        #expect(NotchShape.pill(height: 40, topCornerRadius: 6).topCornerRadius == 6)
    }

    /// The resting pill is *not* flat-topped on notched hardware.
    ///
    /// A dead-flat top reads as a black rectangle parked under the cutout, because
    /// the hardware does not meet the bezel at a right angle either. A few points
    /// of the same curl the panel has is what fuses the two.
    @Test("The resting pill carries a slight top curl that survives the clamp")
    func collapsedPillCurlsAtTheTop() {
        // Pill-sized: a 224pt cutout plus the default 44pt reserve either side, at
        // notch height.
        let rect = CGRect(x: 0, y: 0, width: 312, height: 38)
        let curl = NotchConfiguration.standard.collapsedTopCornerRadius

        // `height / 4` — 9.5pt here — is the ceiling. The default has to sit under
        // it, or the knob is silently pinned and tuning it does nothing.
        let (top, _) = NotchShape.resolvedRadii(in: rect, top: curl, bottom: rect.height / 2)
        #expect(top == curl)

        let curled = NotchShape.pill(height: rect.height, topCornerRadius: curl).path(in: rect)
        let flat = NotchShape.pill(height: rect.height).path(in: rect)

        // Same flare as the panel, just smaller: the top edge still spans the full
        // width, so the curl reads as the bezel flowing in rather than as a corner
        // bitten off the pill.
        #expect(curled.boundingRect.minX == rect.minX)
        #expect(curled.boundingRect.maxX == rect.maxX)

        // Just below that edge the outline has pulled inward, where a flat pill is
        // still solid.
        #expect(!curled.contains(CGPoint(x: 2, y: 3)))
        #expect(flat.contains(CGPoint(x: 2, y: 3)))

        // And past the wall the pill is solid again.
        #expect(curled.contains(CGPoint(x: curl + 1, y: curl)))
    }

    @Test("Every intermediate state of the morph is a drawable shape")
    func morphIntermediatesAreValid() {
        // The morph passes through these continuously. If any produced an empty or
        // out-of-bounds path it would flicker for a frame somewhere mid-transition —
        // the kind of bug that is nearly impossible to catch by eye.
        for step in 0 ... 10 {
            let t = Double(step) / 10
            let rect = CGRect(x: 0, y: 0, width: 200 + 340 * t, height: 40 + 220 * t)
            let path = NotchShape(
                topCornerRadius: 22 * t,
                bottomCornerRadius: 20 + 2 * t
            ).path(in: rect)

            #expect(!path.isEmpty)
            #expect(path.boundingRect.width <= rect.width + 0.001)
            #expect(path.boundingRect.height <= rect.height + 0.001)
            // A valid closed outline always contains its own centre.
            #expect(path.contains(CGPoint(x: rect.midX, y: rect.midY)))
        }
    }

    @Test("Standalone pill rounds only its bottom corners")
    func standalonePillRoundsBottomOnly() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 40)
        let path = NotchPillShape().path(in: rect)

        #expect(!path.isEmpty)
        // Top corners square: a point in the very top-left is inside.
        #expect(path.contains(CGPoint(x: 1, y: 1)))
        // Bottom corners rounded away: the matching bottom-left point is not.
        #expect(!path.contains(CGPoint(x: 1, y: 39)))
    }

    @Test("The standalone pill traces the same outline as the island's own")
    func standalonePillMatchesIslandPill() {
        // Two silhouettes that are *almost* identical is the worst outcome: whichever
        // one you are not looking at reads as slightly wrong. So this delegates
        // rather than reaching for a stock rounded rectangle, and this test says so.
        let rect = CGRect(x: 0, y: 0, width: 312, height: 38)
        let standalone = NotchPillShape().path(in: rect)
        let island = NotchShape.pill(height: rect.height).path(in: rect)

        #expect(standalone.description == island.description)
    }
}
