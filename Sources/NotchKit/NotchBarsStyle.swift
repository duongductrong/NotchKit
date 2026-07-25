import AppKit
import SwiftUI

// MARK: - NotchBarsStyle

/// Every visual decision `NotchBars` makes, as a value you can build, store,
/// interpolate between, or ship as your own preset.
public struct NotchBarsStyle: Equatable, Sendable {

    /// Resting height of each bar as a fraction of `height`, `0...1`.
    ///
    /// **The bar count is `levels.count`.** There is no separate count property to
    /// keep in sync with the heights, which is the kind of pairing that silently
    /// goes wrong the first time someone adds a bar.
    public var levels: [CGFloat]

    /// Height each bar animates toward, same units as `levels`.
    ///
    /// `nil` — or a peak equal to its level — leaves that bar completely static.
    /// That is how a resting indicator costs *zero* animation rather than a
    /// paused one: there is no animation object on the layer at all.
    public var peaks: [CGFloat]?

    public var barWidth: CGFloat
    public var spacing: CGFloat

    /// `nil` gives fully rounded ends (a capsule).
    public var cornerRadius: CGFloat?

    /// Height of a bar at level `1`, and the view's own height.
    public var height: CGFloat

    /// One full level → peak → level cycle.
    public var period: TimeInterval

    /// Extra delay per bar. `0` makes every bar pump in unison, which reads as
    /// one object throbbing; a small value is what turns it into a wave.
    public var stagger: TimeInterval

    public var curve: Curve

    public var tint: Color

    /// VoiceOver label. `nil` marks the view purely decorative.
    ///
    /// Worth setting if the bars are the *only* thing conveying state — a
    /// silent animation is invisible to a screen reader.
    public var label: String?

    public init(
        levels: [CGFloat],
        peaks: [CGFloat]? = nil,
        barWidth: CGFloat = 2.5,
        spacing: CGFloat = 3,
        cornerRadius: CGFloat? = nil,
        height: CGFloat = 14,
        period: TimeInterval = 0.9,
        stagger: TimeInterval = 0.15,
        curve: Curve = .easeInOut,
        tint: Color = .white,
        label: String? = nil
    ) {
        self.levels = levels
        self.peaks = peaks
        self.barWidth = barWidth
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.height = height
        self.period = period
        self.stagger = stagger
        self.curve = curve
        self.tint = tint
        self.label = label
    }

    public var barCount: Int { levels.count }

    /// Width the bars need: every bar plus every gap between them.
    public var intrinsicWidth: CGFloat {
        guard barCount > 0 else { return 0 }
        return CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
    }

    /// True when at least one bar has somewhere to go.
    public var isAnimated: Bool {
        (0..<barCount).contains { peak(at: $0) != level(at: $0) }
    }

    /// Resting height for a bar, clamped to `0...1`.
    ///
    /// Index-safe on purpose: `peaks` is allowed to be shorter than `levels`, and
    /// a style assembled from live data should degrade to "that bar is static"
    /// rather than trap.
    public func level(at index: Int) -> CGFloat {
        guard levels.indices.contains(index) else { return 0 }
        return min(max(levels[index], 0), 1)
    }

    /// Target height for a bar. Falls back to its resting height, which makes the
    /// bar static.
    public func peak(at index: Int) -> CGFloat {
        guard let peaks, peaks.indices.contains(index) else { return level(at: index) }
        return min(max(peaks[index], 0), 1)
    }

    public enum Curve: Equatable, Sendable {
        case linear, easeIn, easeOut, easeInOut

        var timingFunction: CAMediaTimingFunction {
            switch self {
            case .linear: CAMediaTimingFunction(name: .linear)
            case .easeIn: CAMediaTimingFunction(name: .easeIn)
            case .easeOut: CAMediaTimingFunction(name: .easeOut)
            case .easeInOut: CAMediaTimingFunction(name: .easeInEaseOut)
            }
        }
    }
}

public extension NotchBarsStyle {

    /// Static bars at the given heights. No animation object is created at all.
    static func steady(
        _ levels: [CGFloat],
        barWidth: CGFloat = 2.5,
        spacing: CGFloat = 3,
        height: CGFloat = 14,
        tint: Color = .white
    ) -> NotchBarsStyle {
        NotchBarsStyle(
            levels: levels,
            barWidth: barWidth,
            spacing: spacing,
            height: height,
            tint: tint
        )
    }

    /// Evenly staggered bars sweeping between two heights.
    ///
    /// These names describe *shape*, not meaning — `wave` and `steady`, not
    /// `active` and `idle` — so that naming what a state means stays your job.
    static func wave(
        count: Int = 3,
        low: CGFloat = 0.35,
        high: CGFloat = 1,
        barWidth: CGFloat = 2.5,
        spacing: CGFloat = 3,
        height: CGFloat = 14,
        period: TimeInterval = 0.9,
        stagger: TimeInterval = 0.15,
        tint: Color = .white
    ) -> NotchBarsStyle {
        NotchBarsStyle(
            levels: Array(repeating: low, count: max(0, count)),
            peaks: Array(repeating: high, count: max(0, count)),
            barWidth: barWidth,
            spacing: spacing,
            height: height,
            period: period,
            stagger: stagger,
            tint: tint
        )
    }
}
