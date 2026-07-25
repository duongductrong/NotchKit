# Getting started

## Install

Add the package in Xcode via **File → Add Package Dependencies…** with
`https://github.com/duongductrong/NotchKit.git`, or declare it in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/duongductrong/NotchKit.git", from: "1.1.0")
]
```

You can also just copy `Sources/NotchKit/*.swift` into an app target — there are no
dependencies. Delete the `import NotchKit` lines if you do.

## Make it an accessory app

An island is not a window; it is chrome that floats above other people's apps. It
should take no Dock icon, contribute no menu bar, and never steal focus.

Either set `LSUIElement` to `true` in `Info.plist`, or in code:

```swift
NSApplication.shared.setActivationPolicy(.accessory)
```

Skip this and the island still works, but your app appears in the Dock and in
Cmd-Tab, which is rarely what an island app wants.

## Your first island

```swift
import AppKit
import SwiftUI
import NotchKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var presenter: NotchPresenter?

    func applicationDidFinishLaunching(_ note: Notification) {
        let presenter = NotchPresenter()
        self.presenter = presenter

        presenter.install(
            collapsed: { CollapsedBar(presenter: presenter) },
            expanded:  { Panel() }
        )
    }
}

struct CollapsedBar: View {
    let presenter: NotchPresenter

    var body: some View {
        NotchCutoutLayout(
            cutoutWidth: presenter.geometry.hasPhysicalNotch
                ? presenter.geometry.notchWidth : 0,
            gutterWidth: presenter.collapsedGutterWidth,
            pillHeight: presenter.geometry.collapsedHeight
        ) {
            Image(systemName: "waveform")
        } trailing: {
            Text("3").monospacedDigit()
        }
    }
}

struct Panel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hello from the notch").font(.system(size: 13, weight: .semibold))
            Text("Anything can go here.").font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@main
enum MyApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        // `delegate` is unowned, so this must outlive `main`.
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        _ = delegate
    }
}
```

### Three things that trip people up

**Hold the presenter strongly.** It owns the window and nothing else retains it.
Drop the reference and the island silently disappears with no error.

**Don't pad the panel content.** The container applies
`configuration.expandedContentInsets`, derived from the corner radii. A concave top
corner narrows the panel body by the top radius on each side, so hand-padding by a
plausible-looking 20pt against a 22pt radius puts content *outside* the shape,
where it clips along the upper flanks and looks like a rendering fault.

**Keep the pill's centre empty.** On a MacBook the middle of the pill is behind the
physical cutout, so content there is invisible — and invisible *only* on notched
Macs, so it looks perfect on the external display you developed against.
`NotchCutoutLayout` reserves it and hands you the two gutters.

## Driving it

```swift
presenter.expand(reason: .programmatic)
presenter.collapse()
presenter.toggle()
presenter.peek()   // brief scale bump, reverts itself
```

`peek()` is for "something happened" without taking over the screen. It no-ops
unless the island is collapsed, so it is safe to call from anywhere.

Read `presenter.phase` (`.collapsed` / `.expanded` / `.peeking`) from your content
if it needs to react. `NotchPresenter` is `@Observable`, so SwiftUI re-renders on
its own.

## Verification checklist

Cheap to check, and each item is a bug the type system cannot catch. Several only
reproduce on real notched hardware with particular settings.

- [ ] `swift build && swift test` clean.
- [ ] Collapsed island does **not** block clicks on the menu bar or apps beneath.
- [ ] Clicking outside dismisses **and** the click reaches its target — no double-click.
- [ ] Sweeping the pointer quickly past the notch does not open it.
- [ ] Holding the pointer still at the cutout's edge opens it reliably.
- [ ] Open → close → open rapidly: no flicker, no torn morph, no blank panel.
- [ ] The transition reads as one shape growing, not two views swapping.
- [ ] Collapsed pill is flush with the cutout — no wallpaper sliver, no grey patch.
- [ ] Now hide the menu bar in System Settings and re-check that flush edge.
- [ ] External display: standalone pill, no concave corners.
- [ ] Unplug/replug the external display — island returns to a valid screen.
- [ ] Another app fullscreen: island still reachable.
- [ ] Click the wallpaper to reveal the desktop: island stays put.
- [ ] Reduce Motion on: fades only, no springs, no scaling.
- [ ] Idle a minute: near-zero CPU.

Anything failing here almost certainly appears in
[troubleshooting.md](troubleshooting.md).

## Next

- [Customization](customization.md) — every knob, custom shapes and indicators
- [Architecture](architecture.md) — why the window never resizes
- [Recipes](recipes.md) — notification islands, progress, media, hotkeys
