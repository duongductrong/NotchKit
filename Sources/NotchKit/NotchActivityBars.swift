import AppKit
import SwiftUI

/// The canonical island activity glyph: three bars that rise and fall.
///
/// ## Why this is a CALayer and not SwiftUI
///
/// An island indicator animates *continuously*, for minutes or hours, in a strip
/// the user is not looking at. Drive that with `TimelineView` or a repeating
/// `withAnimation` and SwiftUI re-evaluates the view body every frame, forever —
/// which on a laptop is a measurable, permanent battery cost for decoration.
///
/// Core Animation runs the same motion entirely on the render server: the
/// animation is described once, then the GPU interpolates it with **zero**
/// per-frame work on the main thread. The layer keeps animating while your app's
/// main thread sits completely idle.
///
/// The rule this generalises to: *state changes* belong in SwiftUI, *continuous
/// motion* belongs in Core Animation. Reach for `TimelineView` only when each
/// frame needs data SwiftUI owns (a live countdown, a waveform from a buffer).
///
/// Only `transform.scale.y` is animated — a pure compositor transform, the
/// cheapest thing you can put on screen. Animating `path` or `bounds` instead
/// would force a re-rasterisation every frame and give up most of the win.
public struct NotchActivityBars: View {

    public enum Mode: Equatable, Sendable {
        /// Resting: three short static bars. No animation at all.
        case idle
        /// Working: staggered rise and fall.
        case active
        /// Waiting on someone: outer bars held, middle bar hidden.
        case paused
    }

    public var mode: Mode
    public var size: CGFloat
    public var tint: Color

    public init(mode: Mode, size: CGFloat = 24, tint: Color = .white) {
        self.mode = mode
        self.size = size
        self.tint = tint
    }

    public var body: some View {
        Representable(mode: mode, tint: tint)
            .frame(width: size, height: size)
            // Decorative; without this VoiceOver reads three anonymous shapes.
            .accessibilityHidden(true)
    }

    private struct Representable: NSViewRepresentable {
        let mode: Mode
        let tint: Color

        func makeNSView(context: Context) -> BarsView {
            let view = BarsView()
            view.apply(mode: mode, tint: NSColor(tint))
            return view
        }

        func updateNSView(_ view: BarsView, context: Context) {
            view.apply(mode: mode, tint: NSColor(tint))
        }
    }

    /// Design geometry, in a 24×24 box. Scaled to fit whatever `size` is asked for.
    private enum Metrics {
        static let box: CGFloat = 24
        static let barWidth: CGFloat = 2.5
        static let columns: [CGFloat] = [5.25, 10.75, 16.25]
        static let peakHeight: CGFloat = 14

        /// idle, low, high, paused — as fractions of `peakHeight`.
        static let idleHeights: [CGFloat] = [3, 5, 3]
        static let activeLow: [CGFloat] = [4, 6, 4]
        static let activeHigh: [CGFloat] = [12, 14, 10]
        static let pausedHeights: [CGFloat] = [10, 0, 10]
        static let stagger: [CFTimeInterval] = [0, 0.15, 0.30]
        static let beatDuration: CFTimeInterval = 0.45
    }

    fileprivate final class BarsView: NSView {

        private let bars = [CAShapeLayer(), CAShapeLayer(), CAShapeLayer()]
        private var mode: Mode = .idle
        private var tint: NSColor = .white

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer = CALayer()
            layer?.masksToBounds = false

            for bar in bars {
                // Centre anchor makes a scale animation grow symmetrically —
                // the equaliser look. A default (0,0) anchor grows upward only.
                bar.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                bar.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
                layer?.addSublayer(bar)
            }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        func apply(mode newMode: Mode, tint newTint: NSColor) {
            let changed = newMode != mode || newTint != tint
            mode = newMode
            tint = newTint
            guard changed else { return }
            rebuild()
        }

        override func layout() {
            super.layout()
            rebuild()
        }

        /// Core Animation strips animations from layers that leave the window,
        /// so re-arm whenever we are re-attached. Without this the bars freeze
        /// after the island's window is reordered or a Space is switched.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            rebuild()
        }

        private func rebuild() {
            let scale = min(bounds.width, bounds.height) / Metrics.box
            guard scale > 0 else { return }

            let peak = Metrics.peakHeight * scale
            let width = Metrics.barWidth * scale
            let radius = width / 2

            for (index, bar) in bars.enumerated() {
                bar.removeAllAnimations()
                bar.fillColor = tint.cgColor

                // Full-height bar, drawn once. Height is expressed purely as a
                // y-scale so nothing is ever re-rasterised.
                bar.bounds = CGRect(x: 0, y: 0, width: width, height: peak)
                bar.position = CGPoint(
                    x: Metrics.columns[index] * scale,
                    y: bounds.midY
                )
                bar.path = CGPath(
                    roundedRect: CGRect(x: 0, y: 0, width: width, height: peak),
                    cornerWidth: radius,
                    cornerHeight: radius,
                    transform: nil
                )

                switch mode {
                case .idle:
                    bar.isHidden = false
                    bar.transform = CATransform3DMakeScale(
                        1, Metrics.idleHeights[index] / Metrics.peakHeight, 1
                    )

                case .paused:
                    let height = Metrics.pausedHeights[index]
                    bar.isHidden = height == 0
                    bar.transform = CATransform3DMakeScale(
                        1, height / Metrics.peakHeight, 1
                    )

                case .active:
                    bar.isHidden = false
                    let low = Metrics.activeLow[index] / Metrics.peakHeight
                    let high = Metrics.activeHigh[index] / Metrics.peakHeight
                    bar.transform = CATransform3DMakeScale(1, low, 1)

                    let pulse = CABasicAnimation(keyPath: "transform.scale.y")
                    pulse.fromValue = low
                    pulse.toValue = high
                    pulse.duration = Metrics.beatDuration
                    pulse.autoreverses = true
                    pulse.repeatCount = .infinity
                    pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    // Stagger so the bars read as a wave rather than a single
                    // block pumping in unison.
                    pulse.beginTime = CACurrentMediaTime() + Metrics.stagger[index]
                    // Survive the layer being detached and re-attached.
                    pulse.isRemovedOnCompletion = false
                    pulse.fillMode = .backwards
                    bar.add(pulse, forKey: "pulse")
                }
            }
        }
    }
}

#if DEBUG
#Preview("Activity bars") {
    HStack(spacing: 24) {
        ForEach(
            [
                ("idle", NotchActivityBars.Mode.idle),
                ("active", .active),
                ("paused", .paused),
            ],
            id: \.0
        ) { name, mode in
            VStack {
                NotchActivityBars(mode: mode, size: 32)
                Text(name).font(.caption)
            }
        }
    }
    .padding(32)
    .background(Color.black)
}
#endif
