# Troubleshooting

Symptom → cause → fix. Island bugs rarely point at their cause, and several
reproduce only on specific hardware or specific system settings. Start here
before debugging from first principles.

## Motion

### The transition feels like a switch or a snap, not an expansion
Two views are cross-fading instead of one shape morphing. At no instant is there a
single object changing form, so the eye reads a cut. Curve tuning cannot fix a
structural problem.
**Fix:** one `NotchShape` whose width, height, and both radii animate together. See
[architecture.md](architecture.md#the-morph).

### Panel text looks squeezed or clipped for the first few frames
Content is fading in at the same rate the shape grows, so it is briefly rendered
into a pill-sized sliver.
**Fix:** delay the incoming fade (`motion.contentRevealDelay`) so the shape opens
the room first.

### Content appears to be crushed as the panel closes
Outgoing content is fading too slowly, so the shape closes over it while it is still
visible.
**Fix:** `contentHideDuration` shorter than `contentRevealDuration`, and never
delayed on the way out.

### Panel flashes empty while it is still closing
Expanded content unmounted mid-morph.
**Fix:** `expandedUnmountDelay` strictly greater than the collapse duration, with
the generation-guarded teardown.

### Morph stutters only when clicking rapidly
A stale unmount timer from an earlier close fired during a later open.
**Fix:** generation counter around the delayed teardown.

### Content swims / judders during expand
The window frame is being animated while SwiftUI animates the content. Two
animators, different curves, AppKit deferred one runloop turn — they cannot stay
in phase.
**Fix:** fixed-size window, all motion in SwiftUI. `architecture.md` → "Why the
window never resizes".

### Transitions stutter, but only sometimes
More than one animation driver. Scattered `withAnimation` calls race when two land
in the same frame.
**Fix:** one `.animation(motion.animation(for: phase), value: phase)` at the island
root; delete the rest.

### Panel pops out of existence instead of fading
The expanded surface unmounted mid-fade.
**Fix:** `expandedUnmountDelay > collapse duration`, with the deferred-unmount
pattern in `NotchContainer`.

### Fast open→close→open leaves the island blank or stuck
A stale unmount timer from the first close fired during the second open.
**Fix:** generation counter guarding the delayed teardown.

### Brief bow-tie / hourglass flicker mid-animation
Corner radii larger than the animating rect, so the curves self-intersect.
**Fix:** clamp — `min(radius, rect.width / 4, rect.height / 4)`.

### Shape jump-cuts instead of morphing
`Shape` has no `animatableData`, so SwiftUI cannot interpolate the path.
**Fix:** implement `animatableData` (`AnimatablePair` for two radii).

### Close feels like the UI is arguing
A spring on collapse bounces the panel back toward a user who already dismissed it.
**Fix:** `.smooth` for collapse. See the asymmetry principle.

## Hit testing and clicks

### Collapsed island blocks the menu bar / clicks on other apps
The window is expanded-sized and transparent, but still hit-testable.
**Fix:** `ignoresMouseEvents = true` while collapsed, **and** a `hitTest` returning
`nil` outside the drawn content.

### Hover works everywhere except the very top row of pixels
`CGRect.contains` excludes max edges — exactly where the island lives.
**Fix:** `NotchGeometry.contains` (edge-inclusive).

### Dismissing the island eats the click — user must click twice
The outside click closed the island and went nowhere.
**Fix:** `NotchPresenter.repostClick(at:)` after collapsing.

### Reposted click lands in the wrong place on a multi-display setup
The Y flip used `NSScreen.main` (keyboard focus) instead of the primary display.
**Fix:** flip against `NSScreen.screens.first`. Core Graphics global coordinates
are top-left, anchored to the primary.

### First click on a hover-opened panel does nothing
With `.nonactivatingPanel` the panel is not key, so SwiftUI's `Button` spends the
first click acquiring key status.
**Fix:** `window?.makeKey()` in `mouseDown(with:)` before `super`, plus
`acceptsFirstMouse = true`.

### Clicks land on nothing in the empty area of an open panel
The invisible-but-mounted expanded surface is still in the hit-test tree.
**Fix:** `.allowsHitTesting` must track `.opacity`.

## Hover

### Island opens whenever the pointer passes the top of the screen
No open delay. The pointer transits that strip constantly en route to the menu bar.
**Fix:** `hoverOpenDelay ≈ 0.15s`.

### Island never opens when hovering near the cutout edge
Pointer jitter at the boundary restarts the open timer forever.
**Fix:** `hoverCancelGrace ≈ 0.10s` — revoke a pending cancel on re-entry rather
than restarting the open timer. This is the one people miss.

### Island closes immediately after opening
It opened under a stationary pointer, and the first move event read as an exit.
**Fix:** require the pointer to have actually been inside before honouring an exit
(`pointerHasEnteredSurface`).

### Hover tracking dies when your own window is frontmost
Only a global monitor was installed. Global monitors do not see events destined
for your app.
**Fix:** install local monitors too, and **return the event** from them —
returning `nil` swallows all mouse input app-wide.

### Click toggles the island shut, then it reopens by itself
The pending hover timer fired after the click.
**Fix:** `hoverGate.cancelImmediately()` in the click path.

## Geometry

### Island reads as a grey patch bracketing the notch, not one continuous shape
The ink is lifted above pure black. The physical notch is opaque housing that emits
no light, so anything above `#000000` beside it is visibly lighter. Obvious on real
hardware, nearly invisible in a screenshot.
**Fix:** `NotchStyle.standard` (pure black). `.warmPaper` is a design choice, not a
hardware match. Translucent ink cannot merge with opaque housing at all.

### Panel content clips along the upper flanks
Content padded by less than `expandedTopCornerRadius`. A concave top corner makes the
panel widest at its very top edge and tapers inward until the wall settles at
`x = topRadius` — and panel content starts below the cutout row, so it lives entirely
in the narrowed region. 20pt of padding against a 22pt radius is outside the shape.
**Fix:** don't hand-pad. `NotchConfiguration.expandedContentInsets` derives it from
the radii and the container applies it.

### Collapsed pill content clips against the rounded corners
Edge inset smaller than the corner radius.
**Fix:** `NotchCutoutLayout` defaults to half the pill height, which equals the corner
radius and is provably safe for content of any height. If the gutter is then too
tight, widen `collapsedWidth` rather than shrinking the inset.

### Bright sliver of wallpaper visible inside the cutout
Collapsed height computed as `min(safeAreaTop, statusBarHeight)`. When the menu
bar auto-hides, `statusBarHeight` collapses but the cutout does not.
**Fix:** on notched screens use `safeAreaInsets.top` verbatim. Reproduce by
enabling "Automatically hide and show the menu bar".

### Hairline of desktop along the cutout edge
Cutout width measured exactly, then lost to rounding at fractional backing scale.
**Fix:** a few points of bleed (`NotchGeometry.cutoutBleed`). Invisible against
black ink.

### Content in the middle of the collapsed pill is invisible — only on MacBooks
It is behind the physical cutout. Looks perfect on an external monitor.
**Fix:** `NotchCutoutLayout` to reserve the cutout and use the two gutters.

### Concave top corners look like a rendering fault on an external display
There is no cutout there to fuse with.
**Fix:** the container already passes `topCornerRadius: 0` when
`!geometry.hasPhysicalNotch` — in *both* phases, so the resting pill drops its
`collapsedTopCornerRadius` curl too. If you replaced the container, do the same.

### Faint white outline traced around the pill or the notch
A stroked edge on the silhouette. A `.stroke` is centred on the path, so half its
width lands *outside* the fill: it outlines the shape against the desktop, and
while collapsed it traces the hardware cutout — the seam pure-black `ink` exists
to hide.
**Fix:** the container draws ink and shadow only, with no stroke in either phase,
so nothing in NotchKit produces this. If you see it, it is coming from your own
content — `NotchCutoutLayout`'s children draw over the ink, and a `.stroke`,
`.border`, or a `.background` on a material there will show. If you replaced the
container, drop the overlay rather than gating it.

### Setting `style.hairline` does not compile
It was removed along with `hairlineWidth`: the container no longer strokes an edge
in either phase, so the field had nothing to drive.
**Fix:** delete the assignment. For depth on the open panel use `shadowColor` /
`shadowRadius`; for an edge on one specific island, stroke it in your own content.

### The resting pill has a small notch bitten out of each top corner
That is `collapsedTopCornerRadius` (6pt by default), and on notched hardware it is
what fuses the pill with the cutout instead of leaving it parked underneath.
**Fix:** only if you want it gone — `config.collapsedTopCornerRadius = 0` restores a
dead-flat top. If it looks like a *gouge* rather than a flare, the value is too
large for the pill height; `NotchShape` caps it at a quarter of that height
(~9.5pt), and the useful range is well below the cap.

### Island renders off-screen or on the wrong monitor after replug
A persisted `CGDirectDisplayID` was recycled for a different physical display.
**Fix:** persist `NSScreen.notch_stableID` (a display UUID), and fall back to
automatic when the saved ID is absent.

### Island stays put after the display arrangement changes
No observer.
**Fix:** observe `NSApplication.didChangeScreenParametersNotification` and
`refreshPlacement()`.

## Window behaviour

### Island slides away when clicking the wallpaper (Sonoma+)
Missing `.stationary` in `collectionBehavior`; it moves with the user's real
windows. On a MacBook it vanishes under the menu bar and reads as a crash.
**Fix:** add `.stationary`.

### Island disappears when another app goes fullscreen
**Fix:** `.fullScreenAuxiliary`.

### Island only exists on one Space
**Fix:** `.canJoinAllSpaces`.

### Hard-edged rectangular shadow around the island
`hasShadow = true`: AppKit traces the window rectangle, not your concave path.
**Fix:** `hasShadow = false` and draw the shadow in SwiftUI.

### Shadow is clipped flat on one side
Not enough transparent margin in the window for it to fall into. The trap is that
a margin equal to `shadowRadius` looks sufficient and is not: the visible falloff
runs to about **twice** the radius, so the outer half is still measurably dark
where the window ends, and the soft edge becomes a line ruled across it.
**Fix:** nothing, if you use `NotchPresenter` — `shadowInsets(fitting:)` reserves
`max(configured floor, style.shadowReach*)`, so the window grows to fit whatever
shadow the style asks for and `shadowInsetHorizontal` / `shadowInsetBottom` are
only a lower bound. If you size the window yourself, reserve
`style.shadowReachHorizontal` and `style.shadowReachBelow`, and remember the
offset counts only downward.

### Shadow reads as a flat grey halo, or the panel looks like it is floating
One Gaussian cannot be both soft and grounded — wide enough to look diffuse and it
stops touching the surface it sits on.
**Fix:** already handled: the container draws `contactShadow` then `ambientShadow`,
chained so the wide pass blurs the tight one's edge rather than laying a second
gradient over it. Both derive from `shadowRadius` / `shadowOffsetY` / `shadowColor`,
so tune those three and the split follows.

### Opening the island deactivates the user's frontmost app
**Fix:** `.nonactivatingPanel`, `canBecomeMain = false`, and only
`makeKeyAndOrderFront` for `reason == .click`.

### Accessory app steals the menu bar when the island opens
**Fix:** `canBecomeMain = false`.

### App shows a Dock icon
**Fix:** `LSUIElement = true` in Info.plist, or
`app.setActivationPolicy(.accessory)`.

### Scrollbars appear over the island
`NSHostingView` wraps content in private `NSScrollView`s and recreates them when
the view tree changes shape.
**Fix:** disable scrollers in `layout()` on every pass — and only assign when the
value differs, or you spin an endless layout loop.

## Performance

### Steady CPU use while the island sits idle
A `TimelineView` or repeating `withAnimation` is re-evaluating the body every
frame, forever.
**Fix:** Core Animation for continuous motion. See `NotchBars`.

### Animated glyph freezes after a Space switch or window reorder
Core Animation strips animations from layers that leave the window.
**Fix:** re-arm in `viewDidMoveToWindow()`.

### Sluggish under pointer movement
Unthrottled `mouseMoved`, which fires far faster than hit testing needs.
**Fix:** throttle to ~20Hz (`pointerSampleInterval`).

## Build

### "Cannot find type 'TimeInterval' in scope"
`TimeInterval` is Foundation, not CoreGraphics.
**Fix:** `import Foundation`.

### Extension cannot see the type's own members
Swift `private` is **file**-scoped, not type-scoped.
**Fix:** declare shared members `internal` when splitting a type across files.

### `#expect(cgFloatValue == 228 + 88)` fails despite equal numbers
Inside the macro, an all-integer-literal expression is inferred as `Int` and the
mixed comparison fails.
**Fix:** write the expected value as a plain literal (`== 316`), or force
`CGFloat` in the expression.

### "Revision ... for version 1.0.0 does not match previously recorded value"
The tag moved. SwiftPM records version → commit on first resolve (trust on first
use) and refuses a different commit for a version it has already seen, so the
error names the new revision while the stale mapping is the actual cause. Clearing
`~/.swiftpm/cache` and `Package.resolved` does *not* help — the record lives in a
separate fingerprint store.
**Fix:** delete `~/Library/org.swift.swiftpm/security/fingerprints/<package>-*.json`,
then resolve again. Better, do not move a published tag: cut a new patch version
instead, because every consumer that already resolved the old one hits this.

### "Call to main actor-isolated initializer in a synchronous nonisolated context"
A `@MainActor` type initialised from a stored property of a non-isolated class.
**Fix:** mark the owning class (e.g. your `NSApplicationDelegate`) `@MainActor`.
