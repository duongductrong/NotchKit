import AppKit
import SwiftUI

// MARK: - NotchBars

/// A row of bars whose heights animate continuously — an equaliser, a level
/// meter, a breathing pulse. Which of those it is depends entirely on the numbers
/// you hand it.
///
/// Everything about the look lives in `NotchBarsStyle`: how many bars, how wide,
/// how far apart, where they rest, what they animate toward, how fast, how
/// staggered, what colour, what VoiceOver says.
///
/// ## No app states in here
///
/// There is deliberately no `.recording`, `.building`, or `.paused` preset.
/// Those are *your* app's states, and a library that ships them forces every
/// consumer to either accept one app's vocabulary or fight it. Define them as
/// `NotchBarsStyle` values next to the code that knows what they mean:
///
/// ```swift
/// extension NotchBarsStyle {
///     static let building = wave(count: 4, low: 0.25, high: 1, period: 0.5)
///     static let queued   = steady([0.4, 0.6, 0.4])
/// }
/// ```
///
/// `Examples/NotchDemo` does exactly this, twice, with two different looks.
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
public struct NotchBars: View {

    public var style: NotchBarsStyle

    public init(_ style: NotchBarsStyle) {
        self.style = style
    }

    public var body: some View {
        Representable(style: style)
            .frame(width: style.intrinsicWidth, height: style.height)
            // Decorative unless the caller gives it meaning. Without this
            // VoiceOver reads a handful of anonymous shapes.
            .accessibilityHidden(style.label == nil)
            .accessibilityLabel(style.label ?? "")
    }

    private struct Representable: NSViewRepresentable {
        let style: NotchBarsStyle

        func makeNSView(context: Context) -> BarsView {
            let view = BarsView()
            view.apply(style)
            return view
        }

        func updateNSView(_ view: BarsView, context: Context) {
            view.apply(style)
        }
    }

    fileprivate final class BarsView: NSView {

        private var bars: [CAShapeLayer] = []
        private var style = NotchBarsStyle.steady([])

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer = CALayer()
            layer?.masksToBounds = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        func apply(_ newStyle: NotchBarsStyle) {
            guard newStyle != style else { return }
            let countChanged = newStyle.barCount != style.barCount
            style = newStyle
            if countChanged { rebuildLayers() }
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

        /// The island follows the pointer between displays, which can mean moving
        /// between Retina and non-Retina. Without this the bars stay rasterised
        /// for the old scale and go soft or over-sharp on arrival.
        override func viewDidChangeBackingProperties() {
            super.viewDidChangeBackingProperties()
            let scale = window?.backingScaleFactor ?? 2
            for bar in bars { bar.contentsScale = scale }
        }

        private func rebuildLayers() {
            bars.forEach { $0.removeFromSuperlayer() }
            bars = (0..<style.barCount).map { _ in
                let bar = CAShapeLayer()
                // Centre anchor makes a scale animation grow symmetrically. A
                // default (0,0) anchor grows upward only, which reads as a
                // loading bar rather than a level meter.
                bar.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                bar.contentsScale = window?.backingScaleFactor ?? 2
                layer?.addSublayer(bar)
                return bar
            }
        }

        private func rebuild() {
            guard !bars.isEmpty else { return }

            // Only ever scale *down*: if a parent constrains us below the style's
            // intrinsic size the bars should fit rather than overflow, but a
            // roomy parent must not stretch them past what was asked for.
            let fit = min(
                1,
                style.intrinsicWidth > 0 ? bounds.width / style.intrinsicWidth : 1,
                style.height > 0 ? bounds.height / style.height : 1
            )
            guard fit > 0, fit.isFinite else { return }

            let width = style.barWidth * fit
            let height = style.height * fit
            let spacing = style.spacing * fit
            let radius = (style.cornerRadius ?? style.barWidth / 2) * fit
            let originX = bounds.midX - (style.intrinsicWidth * fit) / 2
            let tint = NSColor(style.tint).cgColor

            let path = CGPath(
                roundedRect: CGRect(x: 0, y: 0, width: width, height: height),
                cornerWidth: min(radius, width / 2),
                cornerHeight: min(radius, height / 2),
                transform: nil
            )

            for (index, bar) in bars.enumerated() {
                bar.removeAllAnimations()
                bar.fillColor = tint

                // The bar is drawn once at full height; every height below that is
                // expressed purely as a y-scale, so nothing is re-rasterised.
                bar.bounds = CGRect(x: 0, y: 0, width: width, height: height)
                bar.position = CGPoint(
                    x: originX + width / 2 + CGFloat(index) * (width + spacing),
                    y: bounds.midY
                )
                bar.path = path

                let level = style.level(at: index)
                let peak = style.peak(at: index)

                bar.isHidden = level <= 0 && peak <= 0
                bar.transform = CATransform3DMakeScale(1, max(level, 0.0001), 1)

                guard peak != level else { continue }

                let pulse = CABasicAnimation(keyPath: "transform.scale.y")
                pulse.fromValue = level
                pulse.toValue = peak
                pulse.duration = style.period / 2
                pulse.autoreverses = true
                pulse.repeatCount = .infinity
                pulse.timingFunction = style.curve.timingFunction
                // Stagger so the bars read as a wave rather than a single block
                // pumping in unison.
                pulse.beginTime = CACurrentMediaTime() + style.stagger * Double(index)
                // Survive the layer being detached and re-attached.
                pulse.isRemovedOnCompletion = false
                pulse.fillMode = .backwards
                bar.add(pulse, forKey: "pulse")
            }
        }
    }
}

#if DEBUG

#Preview("Bars") {
    HStack(spacing: 28) {
        ForEach(
            [
                ("steady", NotchBarsStyle.steady([0.3, 0.5, 0.3])),
                ("wave", .wave()),
                ("wide wave", .wave(count: 5, low: 0.2, high: 1, barWidth: 3, spacing: 4, period: 0.6)),
                ("pulse", NotchBarsStyle(levels: [0.4], peaks: [1], barWidth: 8, cornerRadius: 4, height: 8)),
            ],
            id: \.0
        ) { name, style in
            VStack(spacing: 8) {
                NotchBars(style).frame(height: 20)
                Text(name).font(.caption)
            }
        }
    }
    .padding(32)
    .background(Color.black)
}
#endif
