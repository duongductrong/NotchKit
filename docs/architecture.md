# Island architecture

Read this before writing or reviewing island code. The layer split is what keeps
the motion smooth; most island bugs are a layer doing another layer's job.

## Four layers

```
┌─ Content ────────────────────────────────────────────────┐
│  Your SwiftUI views. Knows nothing about windows.        │
├─ Composition ── NotchContainer, NotchShapes ─────────────┤
│  Morphs ONE surface, draws silhouette, owns ALL motion    │
├─ Window ── NotchPanel, NotchHostingView, NotchPresenter ─┤
│  NSPanel flags, hit testing, pointer policy, placement   │
├─ Geometry ── NotchGeometry, NSScreen+Notch ──────────────┤
│  Pure math + the single hardware boundary                │
└──────────────────────────────────────────────────────────┘
```

Data flows **up**: geometry → window → composition → content. Events flow
**down**: pointer → presenter → phase change → SwiftUI re-render.

Only one type crosses more than one boundary: `NotchPresenter`. It is `@Observable`,
so writing `phase` on it re-renders the SwiftUI tree without the window layer
knowing SwiftUI exists.

### What each layer must not do

| Layer | Must not |
|---|---|
| Geometry | Touch `NSScreen` outside `NSScreen+Notch.swift`. Everything else stays pure so it can be tested with no display. |
| Window | Animate anything. Not the frame, not the alpha, not via `NSAnimationContext`. |
| Composition | Let content drive layout size during a transition, or add a second driver for the same property. |
| Content | Know about windows, screens, or phases beyond reading `presenter.phase`. |

## Why the window never resizes

The single most important decision, and the one that is least obvious.

An island's expand looks like a window growing. Implement it that way and you get
jank that no amount of tuning removes:

- **Two animators, one visual.** `NSAnimationContext` drives the frame; SwiftUI
  springs the content. Different curves, different durations, and AppKit's begins
  a runloop turn later. They cannot stay in phase, so the content visibly swims
  inside its own container.
- **Layout thrash.** Animating a frame re-runs SwiftUI layout for the whole
  subtree every frame. Animating opacity and scale is a compositor operation the
  GPU does for free.
- **Shape discontinuity.** A concave-cornered shape morphing while its container
  resizes has two competing sources of truth for its bounds.

What this rules out is animating the frame, not changing it. Assigning a new
`presenter.configuration` with a different `expandedSize` repositions the window
in one discrete, un-animated step — which is how an app swaps between
differently-sized panels without a reinstall. The invariant is that no transition
ever has the window frame as one of its moving parts.

So: create the window at expanded size, keep it there, and let SwiftUI draw a
small pill inside a large transparent window for the collapsed state. The cost is
a large mostly-transparent window above everything — which is why exact hit
testing (below) is not optional.

Placement changes (display hotplug, arrangement change) set the frame
**instantly**. Never animate a frame change, even then.

## The morph

There is **one** surface, not two. A single `NotchShape` whose width, height, and
both corner radii animate together, so the pill physically grows into the panel and
its top corners curl further inward as it goes.

```swift
let surfaceWidth  = isOpen ? expandedWidth  : collapsedWidth
let surfaceHeight = isOpen ? expandedHeight : collapsedHeight
// `cutoutTopRadius` returns 0 on a display with no hardware cutout, in either phase.
let topRadius     = cutoutTopRadius(isOpen ? config.expandedTopCornerRadius
                                           : config.collapsedTopCornerRadius)
let bottomRadius  = isOpen ? config.expandedBottomCornerRadius : collapsedHeight / 2

let shape = NotchShape(topCornerRadius: topRadius, bottomCornerRadius: bottomRadius)

ZStack(alignment: .top) { collapsedContent; expandedContent }
    .frame(width: surfaceWidth, height: surfaceHeight, alignment: .top)  // the morph
    .background(shape.fill(style.ink))
    .clipShape(shape)
    .animation(motion.animation(for: presenter.phase), value: presenter.phase)
```

This works because the collapsed pill **is** `NotchShape`, just at a small top
radius — and at `0` the concave arcs vanish entirely and leave a flat top, which is
what a display with no cutout gets. Every state in between is a valid shape, so the
entire transition is four interpolating numbers.

The collapsed radius is deliberately a fraction of the expanded one (6pt against
22pt by default). The physical cutout does not meet the bezel at a right angle, so a
dead-flat pill top reads as a black rectangle parked underneath it; a few points of
curl fuses the two. Matching the panel's radius does not work either — the same
number is a gentle flare across a 260pt panel and a gouge across a 38pt pill.
`NotchShape` clamps the top radius to a quarter of the height regardless, which puts
a hard ceiling of ~9.5pt on the collapsed curl on current hardware.

### Why not cross-fade two views

Mounting a pill view and a panel view and cross-fading them is simpler to write and
looks fine in a screenshot. It also reads as a **switch** rather than a transform,
because at no instant is there a single object changing form — there are two objects
trading places, and the eye reads that as a cut. No curve tuning fixes it; the
problem is structural.

### Why animating this frame is cheap

Animating a `frame` is normally expensive: it re-runs layout for the whole subtree
every frame. Here the content is **pinned to fixed sizes** and merely *clipped* by
the morphing container, so the animation moves one clip path and one fill while the
content itself never re-lays-out. That is the trick that buys a real morph at
cross-fade cost — and it is why the content must not be allowed to drive the
container's size.

Content overflows the frame while collapsed and is clipped to the shape, which is
what makes the panel appear to be *revealed* by the growing silhouette.

### Content choreography

Content opacity is animated separately from the morph — a different property, so
this is choreography rather than a race:

- incoming content is **delayed** (`contentRevealDelay`) so the shape opens the room
  first. Without it, panel text fades up while the shape is still pill-sized and is
  visibly squeezed into a sliver.
- outgoing content is **quicker and never delayed**, so it clears out before the
  shape closes over the space it occupied instead of appearing to be crushed.

The animation is attached at the content, not the root, so it does not compete with
the morph. `allowsHitTesting` must track opacity too: a fully transparent view is
still in the hit-test tree, so invisible expanded content will silently swallow
clicks meant for the pill underneath.

### Deferred unmount

The expanded content stays mounted for `motion.expandedUnmountDelay` after
collapsing. Unmount it immediately and it tears down mid-morph — the panel flashes
empty while it is still closing.

The delay must be **strictly longer** than `motion.collapse`. A generation
counter guards it:

```swift
mountGeneration &+= 1
let generation = mountGeneration
Task { @MainActor in
    try? await Task.sleep(for: .seconds(motion.expandedUnmountDelay))
    guard mountGeneration == generation, presenter.phase != .expanded else { return }
    expandedMounted = false
}
```

Without the generation check, a fast open → close → open lets the *first* close's
timer fire during the second open and tear down the surface currently on screen.
This pattern recurs for any delayed teardown; copy it rather than reinventing it.

## Coordinate spaces

The genuine source of confusion in island code. Three spaces are in play:

| Space | Origin | Used by |
|---|---|---|
| AppKit screen | bottom-left of primary display | `NSScreen.frame`, `NSEvent.mouseLocation`, `NSWindow.frame` |
| AppKit view | bottom-left of the view | `NSView.hitTest`, `NSView.bounds` |
| Core Graphics global | **top-left** of primary display | `CGEvent` positions, `CGDisplay*` |

Two consequences:

**One rect function serves two spaces.** The window is screen-centred and
fixed-size, and the island hangs off the top, so the shadow margin is always the
bottom strip. `NotchConfiguration.contentRect(in:style:)` therefore works unchanged on
both a view's `bounds` and the window's screen `frame` — the same offsets from the
same corner. That is why hit testing needs no coordinate conversion, and there is
a test pinning the equivalence.

**`CGEvent` needs a Y flip, against the primary display.** Reposting a click:

```swift
guard let primary = NSScreen.screens.first else { return }
let position = CGPoint(x: screenPoint.x, y: primary.frame.maxY - screenPoint.y)
```

Use `NSScreen.screens.first` (the primary), **not** `NSScreen.main` (the screen
with keyboard focus). On a multi-display setup those differ, and the flip lands
the synthetic click on the wrong part of the desktop.

## NSPanel flags

Every flag in `NotchPanel.applyIslandDefaults()` is load-bearing. The ones whose
absence produces a confusing bug:

| Flag | Without it |
|---|---|
| `.nonactivatingPanel` | Opening the island deactivates the user's frontmost app. |
| `canBecomeMain = false` | An accessory app grabs the menu bar when the island opens. |
| `.stationary` | The island slides away during the Sonoma reveal-desktop gesture and looks like a crash. |
| `.canJoinAllSpaces` | Island exists on one Space only. |
| `.fullScreenAuxiliary` | Island disappears when any app goes fullscreen. |
| `hasShadow = false` | AppKit draws a hard-edged box around your concave shape. |
| `ignoresMouseEvents = true` when collapsed | Collapsed island blocks clicks on everything beneath it. |

`hasShadow = false` is the subtle one: AppKit's shadow traces the *window
rectangle*, not your path, so the shadow must be drawn in SwiftUI where it can
follow the silhouette. That is what the `shadowInset*` room in the window is for —
anything outside the window is clipped.

Which is why the window is sized from the config **and** the style. The shadow's
extent is a property of the style, the room for it is a property of the window, and
if the two are set independently one of them is eventually wrong — silently, and
only in the outer few points of a gradient. `NotchConfiguration.shadowInsets(fitting:)`
resolves both into one number (`max(configured floor, style.shadowReach*)`), and
the window frame, the hit-test rect, and the container's panel-size maths all read
it from there. Changing `presenter.style` can therefore resize the window, exactly
as changing `configuration` can.

## Why global event monitors

A collapsed island has `ignoresMouseEvents = true`, so it receives no events —
SwiftUI's `onHover` can never fire. The island must react *before* the pointer
arrives at something that is not listening, and global `NSEvent` monitors are the
only mechanism for that.

Install **both** global and local monitors. Global sees events destined for other
apps; local sees events destined for yours; neither sees both. With only the
global monitor, hover tracking dies the moment your own island or settings window
is frontmost.

Local monitors must **return the event**. Returning `nil` swallows it and the rest
of your app stops receiving mouse input.

Throttle moves to ~20Hz. `mouseMoved` fires far faster than hit testing needs, and
this monitor runs for your app's entire lifetime.

## Concurrency

`NotchPresenter`, `NotchPointerMonitor`, and `NotchHoverGate` are `@MainActor`;
all AppKit and SwiftUI work is main-thread anyway, so this removes hop noise
rather than adding constraints. Event-monitor callbacks bounce onto the main actor
via `Task { @MainActor in ... }`.

Note `private` is **file-scoped** in Swift: `NotchPresenter+Pointer.swift` needs
its shared members declared `internal`, not `private`. Splitting a type across
files and then wondering why members are invisible is a common stumble.

## Extending without breaking the invariants

- **New phase?** Prefer not to. Add a property the content reads instead — the
  animation matrix grows with every phase, and users cannot perceive many
  distinct states in a 40pt strip.
- **Different silhouette?** New `Shape` with `animatableData`; swap it in
  `NotchContainer`. Nothing else changes.
- **Panel needs to be taller sometimes?** Set `expandedSize` to the largest case
  and let content lay out inside it. Do not resize the window.
- **Content-driven height?** Measure with a `PreferenceKey`, then size the
  *content*, not the window.
