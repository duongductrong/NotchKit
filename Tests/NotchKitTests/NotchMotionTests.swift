import CoreGraphics
@testable import NotchKit
import Testing

// MARK: - Motion

struct NotchMotionTests {
    @Test("Each phase gets its own curve")
    func phaseSelectsDistinctCurves() {
        let motion = NotchMotion.standard
        #expect(motion.animation(for: .expanded) == motion.expand)
        #expect(motion.animation(for: .collapsed) == motion.collapse)
        #expect(motion.animation(for: .peeking) == motion.peek)
    }

    @Test("Opening and closing are deliberately different")
    func openAndCloseAreAsymmetric() {
        // A spring on the way out makes the panel bounce back toward a user who
        // has already dismissed it. If these ever become equal, someone has
        // "simplified" away the asymmetry.
        #expect(NotchMotion.standard.expand != NotchMotion.standard.collapse)
    }

    @Test("Reduced motion removes scaling entirely")
    func reducedMotionHasNoScaling() {
        // Scaling is the part that causes discomfort; a cross-fade is not.
        #expect(NotchMotion.reduced.hoverScale == 1)
        #expect(NotchMotion.reduced.peekScale == 1)
    }

    @Test("Hover scale stays subtle enough not to clip the screen edge")
    func hoverScaleStaysSubtle() {
        for motion in [NotchMotion.standard, .crisp, .playful] {
            #expect(motion.hoverScale <= 1.05)
            #expect(motion.peekScale <= 1.08)
        }
    }
}
