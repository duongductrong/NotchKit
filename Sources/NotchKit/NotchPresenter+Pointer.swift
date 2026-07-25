import AppKit

// Pointer policy: what the island does as the pointer moves and clicks.
// Split from `NotchPresenter` because this is *policy* — the rules you are most
// likely to want to change — while the main file is window lifecycle.

extension NotchPresenter {
    func startPointerMonitoring() {
        hoverGate.openDelay = configuration.hoverOpenDelay
        hoverGate.cancelGrace = configuration.hoverCancelGrace
        hoverGate.onOpen = { [weak self] in self?.performHoverExpand() }

        pointerMonitor.start(
            sampleInterval: configuration.pointerSampleInterval,
            onMove: { [weak self] point in self?.handlePointerMoved(point) },
            onClick: { [weak self] point in self?.handlePointerClicked(point) }
        )
    }

    private func performHoverExpand() {
        guard phase == .collapsed else { return }

        if configuration.hapticOnHoverOpen {
            // `.alignment` is the lightest pattern available — a tick, not a
            // thump. Anything heavier on an unrequested open feels like an alarm.
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }

        expand(reason: .hover)
    }

    private func handlePointerMoved(_ screenPoint: CGPoint) {
        guard let panel else { return }
        let inside = NotchGeometry.contains(interactiveRect(in: panel.frame), screenPoint)

        switch phase {
        case .collapsed:
            guard configuration.expandsOnHover else { return }
            inside ? hoverGate.pointerEntered() : hoverGate.pointerExited()

        case .peeking:
            // Let the bump finish. Reacting mid-peek makes the island stutter
            // between two animations that are both already in flight.
            break

        case .expanded:
            // Only hover-opened islands close on exit. A click was deliberate,
            // and yanking the panel away from someone who asked for it is worse
            // than leaving it up.
            guard configuration.collapsesOnPointerExit, expandReason == .hover else { return }

            if inside {
                pointerHasEnteredSurface = true
            } else if pointerHasEnteredSurface {
                collapse()
            }
        }
    }

    private func handlePointerClicked(_ screenPoint: CGPoint) {
        guard let panel else { return }
        let inside = NotchGeometry.contains(interactiveRect(in: panel.frame), screenPoint)

        switch phase {
        case .collapsed, .peeking:
            guard inside else { return }
            // Kill any pending hover-open, or it fires a moment later and
            // re-opens the island the user just toggled shut.
            hoverGate.cancelImmediately()
            expand(reason: .click)

        case .expanded:
            guard configuration.collapsesOnOutsideClick, !inside else { return }
            collapse()
            Self.repostClick(at: screenPoint)
        }
    }

    /// Replays an outside click so it reaches whatever the user was aiming at.
    ///
    /// Without this, dismissing the island *eats* the click: the user clicks a
    /// button in another app, the island closes, the button never fires, and they
    /// have to click again. Nearly every hand-rolled island ships with this bug,
    /// and it is the kind users feel without being able to name.
    static func repostClick(at screenPoint: CGPoint) {
        // Core Graphics global coordinates are top-left origin, anchored to the
        // *primary* display — `NSScreen.screens.first`. Do not reach for
        // `NSScreen.main`: that is whichever screen has keyboard focus, which on
        // a multi-display setup is often not the primary, so the flip lands the
        // synthetic click somewhere else entirely.
        guard let primary = NSScreen.screens.first else { return }
        let position = CGPoint(x: screenPoint.x, y: primary.frame.maxY - screenPoint.y)

        CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: position,
            mouseButton: .left
        )?.post(tap: .cghidEventTap)

        Task { @MainActor in
            // A frame or two of separation: a down/up pair in the same instant is
            // discarded as noise by some apps.
            try? await Task.sleep(for: .milliseconds(20))
            CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseUp,
                mouseCursorPosition: position,
                mouseButton: .left
            )?.post(tap: .cghidEventTap)
        }
    }
}
