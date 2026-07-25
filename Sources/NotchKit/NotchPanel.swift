import AppKit
import SwiftUI

// MARK: - NotchPanel

/// The window an island lives in.
///
/// ## The one rule: this window never resizes
///
/// It is created at expanded size and stays there for its whole life. The
/// collapsed look is achieved by SwiftUI drawing a small pill inside a large
/// transparent window — *not* by shrinking the window.
///
/// This is the difference between an island that feels native and one that
/// judders, and it is worth being blunt about why. If you animate the window
/// frame with `NSAnimationContext` while SwiftUI springs the content inside it,
/// you have two animators driving one visual: different curves, different
/// durations, and AppKit's starts a runloop turn later. They cannot stay in
/// phase, so the content visibly swims against its own container. There is no
/// tuning that fixes it — the only fix is to let exactly one system animate.
/// SwiftUI wins because it owns the shape morph.
///
/// The cost is a large mostly-transparent window sitting above everything, which
/// is why hit testing must be exact (see `NotchHostingView.hitTest`).
public final class NotchPanel: NSPanel {

    /// Key, so text fields and buttons inside the panel work.
    public override var canBecomeKey: Bool { true }

    /// Never main. Becoming main would make macOS treat the island as the
    /// app's primary window and hand it the menu bar, which for a
    /// `LSUIElement` accessory app means the user's real frontmost app
    /// visibly loses focus every time the island opens.
    public override var canBecomeMain: Bool { false }

    public convenience init(contentRect: CGRect) {
        self.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        applyIslandDefaults()
    }

    /// The full set of window flags an island needs. Each one is load-bearing.
    public func applyIslandDefaults() {
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = false

        // Above normal windows and the menu bar, below system alerts.
        level = .statusBar

        // No AppKit chrome: the shape is drawn by SwiftUI.
        backgroundColor = .clear
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        // AppKit's shadow traces the *window rectangle*, so with a concave
        // island shape it draws a hard-edged box in mid-air around it.
        // Draw the shadow in SwiftUI instead, where it can follow the path.
        hasShadow = false

        isMovable = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = false

        // Start inert. `NotchPresenter` flips this when the island opens, so a
        // collapsed island never intercepts clicks meant for other apps.
        ignoresMouseEvents = true

        collectionBehavior = [
            // Stay visible when another app goes fullscreen.
            .fullScreenAuxiliary,
            // Follow the user across Spaces instead of living on one.
            .canJoinAllSpaces,
            // Keep out of Cmd-Tab and window cycling.
            .ignoresCycle,
            // Hold position during the Sonoma "click the wallpaper to reveal
            // the desktop" gesture, and in Mission Control. Without this the
            // island slides away with the user's real windows — on a MacBook it
            // vanishes under the menu bar and looks like a crash.
            .stationary,
        ]
    }

    /// Hide the island from screen recordings and screen sharing.
    ///
    /// Worth considering rather than always setting: an island that shows
    /// notifications is exactly the thing people do not want captured in a
    /// demo, but if yours is the subject of the demo you want it visible.
    public func excludeFromScreenCapture(_ excluded: Bool) {
        sharingType = excluded ? .readOnly : .readWrite
    }
}

// MARK: - NotchHostingView

/// Hosts the SwiftUI island and makes the transparent parts of the window
/// genuinely transparent to the pointer.
public final class NotchHostingView<Content: View>: NSHostingView<Content> {

    /// The clickable region, in this view's coordinates. Everything outside it
    /// passes clicks through to whatever is behind the window.
    public var contentRectProvider: (() -> CGRect?)?

    public override var isOpaque: Bool { false }

    /// Let the first click into an unfocused island do real work instead of
    /// being spent on focusing the window.
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    public required init(rootView: Content) {
        super.init(rootView: rootView)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    /// Clicks land on the island only where the island is actually drawn.
    ///
    /// The window is expanded-sized at all times, so without this a collapsed
    /// island would swallow every click in a 540×280 rectangle across the top
    /// of the screen — including the menu bar. Returning `nil` outside the
    /// content rect makes the window behave as if it were only as big as the
    /// visible ink.
    ///
    /// Note the coordinate space: for a borderless panel's content view, the
    /// incoming point is effectively in this view's own bounds, and AppKit's
    /// bottom-left origin means the island occupies the *top* of `bounds`.
    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard let rect = contentRectProvider?(),
              NotchGeometry.contains(rect, point) else {
            return nil
        }
        return super.hitTest(point) ?? self
    }

    /// Make the panel key before SwiftUI sees the click.
    ///
    /// With `.nonactivatingPanel`, a hover-opened panel is not key. SwiftUI's
    /// `Button` will quietly spend the first click acquiring key status instead
    /// of firing its action, so the user's first press does nothing and they
    /// have to click twice. Claiming key here first makes the very first click
    /// count.
    public override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        super.mouseDown(with: event)
    }

    public override func layout() {
        super.layout()
        // NSHostingView wraps SwiftUI content in private NSScrollViews and
        // recreates them whenever the view tree changes shape, so this has to
        // run on every pass rather than once at setup. Scrollers drawn over a
        // dark island look like a rendering glitch.
        Self.hideScrollers(in: self)
    }

    private static func hideScrollers(in view: NSView) {
        if let scrollView = view as? NSScrollView {
            // Only assign when the value actually differs — setting these
            // marks the view dirty, and doing that inside `layout()` can spin
            // an endless layout loop.
            if scrollView.hasVerticalScroller { scrollView.hasVerticalScroller = false }
            if scrollView.hasHorizontalScroller { scrollView.hasHorizontalScroller = false }
            if scrollView.scrollerStyle != .overlay { scrollView.scrollerStyle = .overlay }
            return
        }
        view.subviews.forEach(hideScrollers)
    }
}
