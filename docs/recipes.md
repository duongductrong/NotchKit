# Recipes

Concrete variants built on NotchKit. Each is content plus configuration — none of
them modify the window or composition layers, which is the point.

## Notification island

Appears on an event, holds briefly, dismisses itself. Stays up if the pointer is
on it, because auto-dismissing something a user is actively reading is worse than
leaving it.

```swift
@MainActor
@Observable
final class NotificationIsland {
    private let presenter: NotchPresenter
    private var dismissTask: Task<Void, Never>?

    var current: Notice?

    init(presenter: NotchPresenter) { self.presenter = presenter }

    func present(_ notice: Notice, dismissAfter seconds: TimeInterval = 6) {
        current = notice
        presenter.expand(reason: .programmatic)
        scheduleDismiss(after: seconds)
    }

    private func scheduleDismiss(after seconds: TimeInterval) {
        dismissTask?.cancel()
        dismissTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            guard let self else { return }
            // Do not yank a panel out from under someone reading it. The pointer
            // being inside is the signal that they are engaged.
            guard !presenter.isPointerInside else {
                scheduleDismiss(after: 3)
                return
            }
            presenter.collapse()
            current = nil
        }
    }
}
```

`isPointerInside` is not built in — add it to the presenter:

```swift
extension NotchPresenter {
    var isPointerInside: Bool {
        guard let panel else { return false }
        return NotchGeometry.contains(interactiveRect(in: panel.frame), NSEvent.mouseLocation)
    }
}
```

Pair with `.clickOnly` configuration so a hover cannot fight the timer:

```swift
NotchPresenter(configuration: .clickOnly)
```

## Progress island

Collapsed pill shows a bar; expanded shows detail. The pill's *width* is fixed —
resizing it per-frame would reintroduce layout thrash in the one place it hurts
most.

```swift
struct ProgressCollapsed: View {
    let fraction: Double
    let presenter: NotchPresenter

    var body: some View {
        NotchCutoutLayout(
            cutoutWidth: presenter.geometry.hasPhysicalNotch ? presenter.geometry.notchWidth : 0,
            gutterWidth: presenter.collapsedGutterWidth,
            pillHeight: presenter.geometry.collapsedHeight
        ) {
            Image(systemName: "arrow.down.circle")
        } trailing: {
            // Fixed track, animated fill. Scale is free; width is not.
            Capsule()
                .fill(.white.opacity(0.18))
                .frame(width: 28, height: 3)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(.white)
                        .frame(width: 28 * max(0, min(1, fraction)), height: 3)
                }
                .animation(presenter.motion.contentMorph, value: fraction)
        }
    }
}
```

For indeterminate progress use a `CABasicAnimation` on a layer, not a repeating
SwiftUI animation — the same reasoning as `NotchActivityBars`.

## Media controller

Wider panel, click-to-open, artwork in the collapsed gutter.

```swift
var config = NotchConfiguration.clickOnly
config.expandedSize = CGSize(width: 560, height: 180)
config.collapsedWidth = .wrapCutout(reserve: 52)  // room for artwork beside the cutout

let presenter = NotchPresenter(
    configuration: config,
    motion: .resolved(.playful),   // consumer-facing: personality is welcome
    style: .contrast               // must stay legible over album art
)
```

Collapsed leading slot:

```swift
Image(nsImage: artwork)
    .resizable()
    .aspectRatio(contentMode: .fill)
    .frame(width: 20, height: 20)
    .clipShape(RoundedRectangle(cornerRadius: 4))
```

## Peek on background events

`peek()` for "something happened" without taking over the screen. It is a scale
bump that self-reverts, so it needs no dismissal logic and cannot strand the UI
open.

```swift
func buildFinished(success: Bool) {
    if success {
        presenter.peek()                       // glance-able
    } else {
        presenter.expand(reason: .programmatic) // needs a decision
    }
}
```

`peek()` no-ops unless the island is collapsed, so it is safe to call from
anywhere without guarding.

## Multi-display pinning

```swift
// Offer the user a choice.
let options = NSScreen.screens.map { ($0.notch_stableID, $0.localizedName) }

// Persist the stable ID, never a CGDirectDisplayID — those get recycled on
// hotplug and will eventually route the island to a different monitor.
presenter.preferredScreenID = UserDefaults.standard.string(forKey: "island.display")

// Setting it repositions immediately via didSet. If the saved display is gone,
// the built-in screen-change observer falls back to automatic on its own.
```

## Keyboard shortcut

```swift
// Global hotkey via NSEvent monitor. For a user-configurable shortcut, prefer
// a dedicated library — hotkey conflict handling is its own problem.
NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
    guard event.modifierFlags.contains([.command, .option]),
          event.charactersIgnoringModifiers == "i" else { return }
    Task { @MainActor in presenter.toggle() }
}
```

`toggle()` uses `reason: .click`, so the island takes key status and accepts
typing — which is what you want from a deliberate keyboard invocation.

## Content-driven panel height

Measure the content and size the *content*. The window stays fixed at the largest
case.

```swift
private struct HeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MeasuredPanel<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder var content: () -> Content
    @State private var measured: CGFloat = 0

    var body: some View {
        // Always a ScrollView, even when content fits: a tight parent otherwise
        // caps the measurement and long content reads as truncated rather than
        // scrollable.
        ScrollView(.vertical) {
            content()
                .background(GeometryReader { geo in
                    Color.clear.preference(key: HeightKey.self, value: geo.size.height)
                })
        }
        .scrollBounceBehavior(.basedOnSize)
        .onPreferenceChange(HeightKey.self) { if $0 > 0 { measured = $0 } }
        .frame(height: measured > 0 ? min(measured, maxHeight) : nil)
    }
}
```

Set `config.expandedSize.height` to your `maxHeight` plus chrome so the window is
always large enough.

## Custom silhouette

```swift
struct SquaredIslandShape: Shape {
    var cornerRadius: CGFloat = 12
    // Required, or SwiftUI jump-cuts between paths instead of morphing.
    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // Always clamp: mid-animation the rect can be much smaller than the
        // radius, and un-clamped curves self-intersect into a one-frame flicker.
        let r = min(cornerRadius, rect.width / 4, rect.height / 2)
        return Path(roundedRect: rect, cornerRadius: r)
    }
}
```

Swap it into `NotchContainer.expandedSurface`. Nothing else changes — the window,
hit testing, and motion layers do not know which shape is in use.

## Testing new geometry

Put the math in a `static` pure function and pin it. These bugs reproduce only on
particular hardware with particular menu-bar settings, so hand-testing does not
find them and regressions stay invisible until a user with the right laptop
complains.

Say you are adding width clamping. Write it as a pure static function:

```swift
extension NotchGeometry {
    static func clampedPillWidth(
        desired: CGFloat,
        screenWidth: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        max(0, min(desired, screenWidth - margin * 2))
    }
}
```

...and pin it, with no display attached:

```swift
@Test("Pill width never exceeds the screen")
func pillWidthClampsToScreen() {
    let width = NotchGeometry.clampedPillWidth(desired: 900, screenWidth: 800, margin: 32)
    #expect(width == 736)   // plain literals — see troubleshooting.md on #expect and CGFloat
}
```

That is the whole discipline: if a value depends on hardware, compute it in a
function that takes the hardware readings as arguments.
