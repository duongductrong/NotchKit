import AppKit

// MARK: - NotchPointerMonitor

/// Watches the pointer everywhere on screen, not just inside the window.
///
/// An island has to react before the pointer arrives — you cannot use SwiftUI's
/// `onHover`, because a collapsed island sets `ignoresMouseEvents = true` and
/// therefore receives no events at all. Global `NSEvent` monitors are the only
/// way to know the pointer is approaching something that is not yet listening.
///
/// Both global *and* local monitors are installed: global sees events destined
/// for other apps, local sees events destined for yours, and neither sees both.
/// Without the local monitor, hover tracking dies the moment your own island (or
/// settings window) is frontmost.
@MainActor
public final class NotchPointerMonitor {
    private var monitors: [Any] = []

    public var isRunning: Bool {
        !monitors.isEmpty
    }

    public init() {}

    /// - Parameters:
    ///   - sampleInterval: Minimum seconds between `onMove` callbacks.
    ///   - onMove: Pointer moved. Location is in screen coordinates.
    ///   - onClick: Left button went down anywhere. Screen coordinates.
    public func start(
        sampleInterval: TimeInterval = 0.05,
        onMove: @MainActor @escaping (CGPoint) -> Void,
        onClick: @MainActor @escaping (CGPoint) -> Void
    ) {
        guard !isRunning else { return }

        // Throttle state shared by both move monitors so they cannot double the
        // effective sample rate. Event monitors are delivered on the main
        // thread, so this is single-threaded in practice.
        nonisolated(unsafe) var lastSample: TimeInterval = 0

        func shouldSample() -> Bool {
            let now = ProcessInfo.processInfo.systemUptime
            guard now - lastSample >= sampleInterval else { return false }
            lastSample = now
            return true
        }

        let globalMove = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in
            guard shouldSample() else { return }
            let location = NSEvent.mouseLocation
            Task { @MainActor in onMove(location) }
        }

        // Local monitors must return the event, or they swallow it and the rest
        // of your app stops seeing mouse input entirely.
        let localMove = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
            guard shouldSample() else { return event }
            let location = NSEvent.mouseLocation
            Task { @MainActor in onMove(location) }
            return event
        }

        let globalClick = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { _ in
            let location = NSEvent.mouseLocation
            Task { @MainActor in onClick(location) }
        }

        let localClick = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            let location = NSEvent.mouseLocation
            Task { @MainActor in onClick(location) }
            return event
        }

        monitors = [globalMove, localMove, globalClick, localClick].compactMap { $0 }
    }

    public func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    deinit {
        monitors.forEach(NSEvent.removeMonitor)
    }
}

// MARK: - NotchHoverGate

/// Turns a noisy stream of "pointer is / is not over the island" into a single
/// deliberate open.
///
/// Two delays, doing two different jobs — both necessary, and easy to conflate:
///
/// - **`openDelay`** filters *transits*. The pointer crosses the top of the
///   screen constantly on its way to the menu bar. Opening instantly means the
///   island flaps at people who were never looking at it.
///
/// - **`cancelGrace`** filters *jitter*. The cutout edge is precisely where a
///   pointer wobbles between inside and outside. Cancelling the moment it steps
///   out means a user holding still at the boundary restarts the timer forever
///   and the island never opens — it feels haunted rather than slow.
///
/// Only the second one is counter-intuitive, which is why it is usually the one
/// that is missing.
@MainActor
public final class NotchHoverGate {
    public var openDelay: TimeInterval
    public var cancelGrace: TimeInterval

    /// Called when a hover has survived both filters.
    public var onOpen: (@MainActor () -> Void)?

    private var openTask: Task<Void, Never>?
    private var cancelTask: Task<Void, Never>?

    public var isPending: Bool {
        openTask != nil
    }

    public init(openDelay: TimeInterval = 0.15, cancelGrace: TimeInterval = 0.10) {
        self.openDelay = openDelay
        self.cancelGrace = cancelGrace
    }

    /// Pointer is over the island's hit area.
    public func pointerEntered() {
        // Re-entered during the grace window: revoke the pending cancel and
        // keep the original open timer running. Restarting it here is the bug
        // the grace period exists to prevent.
        cancelTask?.cancel()
        cancelTask = nil

        guard openTask == nil else { return }

        openTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .seconds(openDelay))
            } catch {
                return // cancelled — a replacement task owns the timer now
            }
            openTask = nil
            onOpen?()
        }
    }

    /// Pointer left the island's hit area.
    public func pointerExited() {
        guard openTask != nil, cancelTask == nil else { return }

        cancelTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .seconds(cancelGrace))
            } catch {
                return
            }
            openTask?.cancel()
            openTask = nil
            cancelTask = nil
        }
    }

    /// Drop everything now, no grace period.
    ///
    /// Use when a click already opened the island — otherwise the hover timer
    /// fires a moment later and re-opens what the user just toggled shut.
    public func cancelImmediately() {
        openTask?.cancel()
        cancelTask?.cancel()
        openTask = nil
        cancelTask = nil
    }
}
