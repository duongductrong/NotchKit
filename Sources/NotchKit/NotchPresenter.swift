import AppKit
import Observation
import SwiftUI

/// Owns the island: its window, its phase, and its pointer policy.
///
/// This is the only object you interact with. Create one, `install` your two
/// views, then drive it with `expand()` / `collapse()` / `peek()`.
///
/// Keep a strong reference for as long as the island should exist — usually on
/// your `NSApplicationDelegate` or an `@State` in your `App`.
@MainActor
@Observable
public final class NotchPresenter {

    // MARK: Observable state

    public private(set) var phase: NotchPhase = .collapsed
    public private(set) var expandReason: NotchExpandReason?

    /// Live geometry of the screen the island is on. Recomputed automatically
    /// on display hotplug, sleep/wake, and arrangement changes.
    public private(set) var geometry: NotchGeometry

    public var configuration: NotchConfiguration
    public var motion: NotchMotion
    public var style: NotchStyle

    /// Pin the island to a specific display, by `NSScreen.notch_stableID`.
    /// `nil` picks automatically: notched screen first, then main.
    public var preferredScreenID: String? {
        didSet {
            guard preferredScreenID != oldValue else { return }
            refreshPlacement()
        }
    }

    // MARK: Plumbing

    // Deliberately `internal`, not `private`: Swift scopes `private` to a single
    // file, and the pointer-policy extension lives in its own file.
    @ObservationIgnored var panel: NotchPanel?
    @ObservationIgnored let pointerMonitor = NotchPointerMonitor()
    @ObservationIgnored lazy var hoverGate = NotchHoverGate()
    @ObservationIgnored private var peekTask: Task<Void, Never>?
    @ObservationIgnored private var screenObserver: NSObjectProtocol?

    /// Set to true once the pointer has actually been inside an open island.
    /// Guards hover-collapse: an island that opens under a stationary pointer
    /// would otherwise close on the very first move event, before the user has
    /// registered that anything appeared.
    @ObservationIgnored var pointerHasEnteredSurface = false

    public init(
        configuration: NotchConfiguration = .standard,
        motion: NotchMotion? = nil,
        style: NotchStyle = .standard,
        preferredScreenID: String? = nil
    ) {
        self.configuration = configuration
        // Resolve Reduce Motion at init unless the caller was explicit.
        self.motion = motion ?? .resolved()
        self.style = style
        self.preferredScreenID = preferredScreenID
        self.geometry = NSScreen.notch_preferred(matching: preferredScreenID)
            .map(NotchGeometry.init(screen:))
            ?? NotchGeometry(
                screenFrame: .zero,
                collapsedHeight: NotchGeometry.simulatedNotchHeight,
                notchWidth: NotchGeometry.simulatedNotchWidth,
                hasPhysicalNotch: false
            )
    }

    // MARK: - Install

    /// Builds the window and shows the collapsed island.
    ///
    /// `collapsed` and `expanded` receive no arguments — read `presenter.phase`
    /// if your content needs to know. Both are wrapped in the correct silhouette,
    /// hairline, and shadow for you; supply content only.
    public func install<Collapsed: View, Expanded: View>(
        @ViewBuilder collapsed: @escaping () -> Collapsed,
        @ViewBuilder expanded: @escaping () -> Expanded
    ) {
        guard panel == nil, let screen = resolvedScreen else { return }

        geometry = NotchGeometry(screen: screen)

        let hosting = NotchHostingView(
            rootView: NotchContainer(
                presenter: self,
                collapsed: collapsed,
                expanded: expanded
            )
        )
        hosting.contentRectProvider = { [weak self] in
            guard let self, let panel else { return nil }
            // Hit testing happens in view coordinates, but the window is
            // screen-centered and the same size, so the rect maths is identical
            // in both spaces — just re-anchored to the view's own bounds.
            return interactiveRect(in: CGRect(origin: .zero, size: panel.frame.size))
        }

        let newPanel = NotchPanel(contentRect: windowFrame(on: screen))
        newPanel.contentView = hosting
        panel = newPanel

        newPanel.orderFrontRegardless()

        startPointerMonitoring()
        startObservingScreenChanges()
    }

    /// Tears down the window and all monitors.
    public func uninstall() {
        peekTask?.cancel()
        hoverGate.cancelImmediately()
        pointerMonitor.stop()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: - Phase control

    public func expand(reason: NotchExpandReason = .programmatic) {
        peekTask?.cancel()
        hoverGate.cancelImmediately()

        expandReason = reason
        phase = .expanded
        pointerHasEnteredSurface = false

        guard let panel else { return }
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true

        // Only a click earns key status. Taking focus on a *hover* would steal
        // the user's keystrokes mid-sentence just because their pointer drifted
        // near the top of the screen.
        if reason == .click {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    public func collapse() {
        peekTask?.cancel()
        expandReason = nil
        phase = .collapsed
        pointerHasEnteredSurface = false

        // The window stays on screen — the collapsed pill lives in it. Only
        // interactivity is withdrawn, so clicks pass through to other apps.
        panel?.ignoresMouseEvents = true
        panel?.acceptsMouseMovedEvents = false
    }

    public func toggle() {
        phase == .expanded ? collapse() : expand(reason: .click)
    }

    /// A brief scale bump, then back to collapsed. For "something happened"
    /// without taking over the screen.
    public func peek() {
        guard phase == .collapsed else { return }

        phase = .peeking
        peekTask?.cancel()
        peekTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .seconds(motion.peekDuration))
            } catch {
                return
            }
            guard phase == .peeking else { return }
            phase = .collapsed
        }
    }

    // MARK: - Geometry

    /// Width the collapsed pill is drawn at.
    ///
    /// With the default `.wrapCutout`, this extends past each side of the cutout.
    /// Both the pill and the cutout are black, so they read as one continuous
    /// shape — that merge is the effect worth copying.
    public var collapsedSurfaceWidth: CGFloat {
        configuration.collapsedWidth.resolved(notchWidth: geometry.notchWidth)
    }

    /// Usable width on each side of the cutout, for laying out collapsed content.
    ///
    /// Pass to `NotchCutoutLayout` rather than recomputing — it already accounts
    /// for whichever `NotchCollapsedWidth` strategy is in use.
    public var collapsedGutterWidth: CGFloat {
        configuration.collapsedWidth.gutterWidth(notchWidth: geometry.notchWidth)
    }

    /// The region that should accept clicks right now, expressed inside any
    /// window-sized rect (view bounds or screen frame — see
    /// `NotchConfiguration.contentRect(in:)` for why one function covers both).
    ///
    /// While collapsed this is deliberately *larger* than the drawn pill by
    /// `collapsedHitPadding`, so a compact pill is still easy to hit.
    public func interactiveRect(in bounds: CGRect) -> CGRect {
        switch phase {
        case .expanded:
            configuration.contentRect(in: bounds)
        case .collapsed, .peeking:
            NotchGeometry.centeredRect(
                on: bounds,
                width: collapsedSurfaceWidth + configuration.collapsedHitPadding * 2,
                height: geometry.collapsedHeight
            )
        }
    }

    private var resolvedScreen: NSScreen? {
        NSScreen.notch_preferred(matching: preferredScreenID)
    }

    private func windowFrame(on screen: NSScreen) -> CGRect {
        let size = configuration.windowSize(collapsedHeight: geometry.collapsedHeight)
        let width = min(size.width, screen.frame.width)
        return CGRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - size.height,
            width: width,
            height: size.height
        )
    }

    /// Re-resolve screen and reposition. Frame changes are applied instantly and
    /// never animated — see `NotchPanel` on why AppKit must not animate here.
    public func refreshPlacement() {
        guard let panel, let screen = resolvedScreen else { return }
        geometry = NotchGeometry(screen: screen)
        let frame = windowFrame(on: screen)
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
        }
    }

    private func startObservingScreenChanges() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // A pinned display that has gone away must fall back, or the
                // island silently renders off-screen forever.
                if let id = self.preferredScreenID,
                   !NSScreen.screens.contains(where: { $0.notch_stableID == id }) {
                    self.preferredScreenID = nil
                    return // the didSet already repositioned
                }
                self.refreshPlacement()
            }
        }
    }

    // Pointer policy — hover, outside-click, click reposting — lives in
    // `NotchPresenter+Pointer.swift`.
}
