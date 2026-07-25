import AppKit

// The hardware boundary. Everything that reads live display state lives here
// so `NotchGeometry`'s math stays pure and unit-testable.

public extension NotchGeometry {
    /// Reads live geometry off a screen.
    init(screen: NSScreen) {
        let hasNotch = screen.notch_hasPhysicalNotch

        self.init(
            screenFrame: screen.frame,
            collapsedHeight: hasNotch
                ? Self.collapsedHeight(
                    safeAreaTop: screen.safeAreaInsets.top,
                    statusBarHeight: screen.notch_statusBarHeight
                )
                : screen.notch_statusBarHeight,
            notchWidth: hasNotch
                ? Self.notchWidth(
                    screenWidth: screen.frame.width,
                    auxiliaryLeftWidth: screen.auxiliaryTopLeftArea?.width ?? 0,
                    auxiliaryRightWidth: screen.auxiliaryTopRightArea?.width ?? 0
                )
                : Self.simulatedNotchWidth,
            hasPhysicalNotch: hasNotch
        )
    }
}

public extension NSScreen {

    /// Three signals because no single one is reliable across every display.
    /// `safeAreaInsets.top` is the common case; the auxiliary areas catch
    /// configurations where the inset reads zero but the cutout is real.
    var notch_hasPhysicalNotch: Bool {
        safeAreaInsets.top > 0
            || auxiliaryTopLeftArea?.isEmpty == false
            || auxiliaryTopRightArea?.isEmpty == false
    }

    /// Height reserved at the top of the screen, however macOS is expressing it.
    var notch_statusBarHeight: CGFloat {
        let reserved = max(0, frame.maxY - visibleFrame.maxY)
        if reserved > 0 { return reserved }
        if safeAreaInsets.top > 0 { return safeAreaInsets.top }
        return 24 // menu bar is auto-hidden; 24pt is the standard height
    }

    /// Identity that survives a reconnect.
    ///
    /// `CGDirectDisplayID` gets recycled across hotplug, sleep, and display
    /// rearrangement. Persist one of those and you will eventually route the
    /// island onto a *different physical monitor* than the user picked —
    /// silently, and only for people with multiple displays. The UUID is stable.
    var notch_stableID: String {
        if let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
           let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue(),
           let string = CFUUIDCreateString(nil, uuid) {
            return string as String
        }
        // Some AirPlay / virtual displays refuse a UUID. Fall back to a
        // name+frame composite; it is not rearrangement-stable, but a stale
        // preference self-heals via NotchPresenter's validity check.
        let f = frame
        return "fallback-\(localizedName)-\(Int(f.width))x\(Int(f.height))@\(Int(f.origin.x)),\(Int(f.origin.y))"
    }

    /// The screen an island should prefer: notched first, then main, then any.
    static func notch_preferred(matching stableID: String? = nil) -> NSScreen? {
        let screens = NSScreen.screens
        if let stableID, let match = screens.first(where: { $0.notch_stableID == stableID }) {
            return match
        }
        return screens.first(where: \.notch_hasPhysicalNotch) ?? .main ?? screens.first
    }
}
